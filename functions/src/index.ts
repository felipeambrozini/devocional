// Lembretes diários do devocional — o servidor que decide quem avisar.
//
// Roda a cada minuto (Cloud Scheduler, infra do Google — sem os atrasos de
// 10-30 min do cron do GitHub Actions que matou a versão anterior). É o
// único caminho de lembrete na web — `flutter_local_notifications_web` não
// implementa `zonedSchedule` (lança `UnsupportedError`), então lá não existe
// reserva local — por isso a cadência apertada: cada minuto de atraso aqui é
// um minuto de atraso na única notificação que a web recebe.
// Lê só os documentos vencidos da coleção `lembretes` no Firestore
// (`proximoEnvio` <= agora; {fid, minutosManha, minutosNoite, fuso}, gravada
// pelo app, ver lib/dados/lembretes.dart) e envia via FCM uma mensagem
// **data-only** para quem venceu o horário. Documentos antigos ainda trazem
// {token} em vez de {fid}; os dois formatos são aceitos na transição:
//
//   - data-only acorda o handler Dart com o app morto no Android, que exibe
//     via notificação local (o lembrete local recorrente de reserva do
//     Android continua rodando por conta própria, sem cancelamento cruzado —
//     ver `LembretesReais._armarReservas` em lib/dados/lembretes.dart);
//   - na web, o service worker (firebase-messaging-sw.js) lê os mesmos dados
//     e exibe por conta própria;
//   - `minutos` vai junto para o app saber suprimir um push muito tardio (ver
//     `pushAindaVale`).
//
// Confiabilidade: tolerância de 60 min depois do horário cadastrado + um
// envio único por dia marcado no próprio documento
// (`ultimoEnvioManha`/`ultimoEnvioNoite`, escritos só aqui) — uma falha
// transitória (rede, cota) tem 60 tentativas antes de desistir do dia, não
// 12. O cron do GitHub pulava lembrete quase todo dia porque exigia minuto
// exato; isto aqui não.
//
// Consulta barata: cada avaliação grava `proximoEnvio` (quando o documento
// volta a ser lido, no máximo 60 min à frente), então o documento só é lido
// perto de um horário seu. Documento sem o campo (cadastro novo, APK antigo
// que regrava com .set) é marcado pelo gatilho `prepararLembrete`.
//
// Conteúdo: assets/conteudo-lembretes.json — gerado dos JSONs do app
// (manha_e_noite/promessas_de_deus) só com referência e título, que é tudo
// que a notificação usa ("Venha ler a reflexão para sua manhã em
// Gênesis 1:2"). Regenerar se algum dia o conteúdo anual mudar.
import {initializeApp} from "firebase-admin/app";
import {
  DocumentReference,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {getMessaging, Message, SendResponse} from "firebase-admin/messaging";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import conteudoJson from "./assets/conteudo-lembretes.json";
import {
  calcularProximoEnvio,
  deveEnviar,
  ehBissexto,
  referenciaDoSlot,
} from "./regras";

initializeApp();

const COLECAO = "lembretes";

// Mesma região do Firestore: o gatilho precisa estar nela.
const REGIAO_DO_BANCO = "southamerica-east1";

// Limite do sendEach e do WriteBatch.
const TAMANHO_MAXIMO_LOTE = 500;

interface PromessaDia {
  t: string;
  r: string;
}

type DiaConteudo = {m?: string; n?: string; p?: PromessaDia; l?: string; lb?: string};

const conteudoPorDia = conteudoJson as Record<string, DiaConteudo>;

interface DadosDoLembrete {
  /** Firebase Installation ID: destinatário atual do push. */
  fid?: string;
  /** Token FCM de documentos gravados antes da migração para FID. */
  token?: string;
  minutosManha: number;
  /** Ausente em documentos antigos: herda da manhã. */
  minutosPromessas?: number;
  /** Ausente em documentos antigos: herda da manhã. */
  minutosLeitura?: number;
  minutosNoite: number;
  fuso: string;
  ultimoEnvioManha?: string;
  ultimoEnvioPromessas?: string;
  ultimoEnvioLeitura?: string;
  ultimoEnvioNoite?: string;
}

type Alvo = {fid: string} | {token: string};

type CampoUltimoEnvio =
  | "ultimoEnvioManha"
  | "ultimoEnvioPromessas"
  | "ultimoEnvioLeitura"
  | "ultimoEnvioNoite";

type Interruptores = (interruptor: string) => boolean;

interface DefinicaoDoSlot {
  chave: string;
  campoUltimoEnvio: CampoUltimoEnvio;
  /** Interruptor em config/recursos. */
  interruptor: string;
  titulo: string;
  minutos: (d: DadosDoLembrete) => number;
  /** Texto do push, ou vazio quando o dia não tem conteúdo do slot. */
  corpo: (conteudo: DiaConteudo, ano: number) => string | undefined;
}

const SLOTS: DefinicaoDoSlot[] = [
  {
    chave: "manha",
    campoUltimoEnvio: "ultimoEnvioManha",
    interruptor: "manhaAtivo",
    titulo: "Devocional da Manhã",
    minutos: (d) => d.minutosManha,
    corpo: (c) => c.m ? `Venha ler a reflexão para sua manhã em ${c.m}` : undefined,
  },
  {
    chave: "promessas",
    campoUltimoEnvio: "ultimoEnvioPromessas",
    interruptor: "promessasAtivo",
    titulo: "Promessas de Deus",
    minutos: (d) => d.minutosPromessas ?? d.minutosManha,
    corpo: (c) => c.p?.r ?
      `Venha ler a Promessa de Deus para o seu dia em ${c.p.r}` : undefined,
  },
  {
    chave: "leitura",
    campoUltimoEnvio: "ultimoEnvioLeitura",
    interruptor: "cronogramaAtivo",
    titulo: "Leitura do Dia",
    minutos: (d) => d.minutosLeitura ?? d.minutosManha,
    corpo: (c, ano) => ehBissexto(ano) ? (c.lb ?? c.l) : c.l,
  },
  {
    chave: "noite",
    campoUltimoEnvio: "ultimoEnvioNoite",
    interruptor: "noiteAtivo",
    titulo: "Devocional da Noite",
    minutos: (d) => d.minutosNoite,
    corpo: (c) => c.n ? `Venha ler a reflexão para sua noite em ${c.n}` : undefined,
  },
];

function alvoDe(d: DadosDoLembrete): Alvo | null {
  if (typeof d.fid === "string" && d.fid.length > 0) return {fid: d.fid};
  if (typeof d.token === "string" && d.token.length > 0) {
    return {token: d.token};
  }
  return null;
}

function agoraNoFuso(fuso: string, agora: Date): {
  diaISO: string;
  minutoDoDia: number;
} {
  const partes = new Intl.DateTimeFormat("en-CA", {
    timeZone: fuso,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(agora);
  const p = (tipo: string) => partes.find((x) => x.type === tipo)?.value ?? "";
  const hora = Number(p("hour"));
  const minuto = Number(p("minute"));
  return {
    diaISO: `${p("year")}-${p("month")}-${p("day")}`,
    minutoDoDia: hora * 60 + minuto,
  };
}

function mensagem(
    alvo: Alvo,
    chave: string,
    titulo: string,
    corpo: string,
    minutosDoSlot: number,
): Message {
  return {
    ...alvo,
    // Sem `notification`: data-only é o que acorda o handler no Android e
    // entrega ao service worker na web — cada lado exibe por conta própria.
    android: {priority: "high" as const},
    data: {
      chave,
      titulo,
      corpo,
      minutos: String(minutosDoSlot),
    },
  };
}

interface Envio {
  slot: DefinicaoDoSlot;
  /** Dia a que o slot pertence (ontem na virada da meia-noite). */
  diaISO: string;
  message: Message;
}

interface Avaliacao {
  ref: DocumentReference;
  minutoDoDia: number;
  alvosMinuto: number[];
  envios: Envio[];
  confirmados: Envio[];
  alvoMorto: boolean;
}

function planejarEnvios(
    alvo: Alvo,
    d: DadosDoLembrete,
    local: {diaISO: string; minutoDoDia: number},
    ligado: Interruptores,
): Envio[] {
  return SLOTS.flatMap((slot) => {
    const alvoMinuto = slot.minutos(d);
    const referencia = referenciaDoSlot(
        local.diaISO, local.minutoDoDia, alvoMinuto);
    if (
      !ligado(slot.interruptor) ||
      !deveEnviar(local.minutoDoDia, alvoMinuto, d[slot.campoUltimoEnvio],
          referencia.diaISO)
    ) {
      return [];
    }
    const conteudo = conteudoPorDia[referencia.diaChave];
    const ano = Number(referencia.diaISO.slice(0, 4));
    const corpo = conteudo && slot.corpo(conteudo, ano);
    if (!corpo) return [];
    return [{
      slot,
      diaISO: referencia.diaISO,
      message: mensagem(alvo, slot.chave, slot.titulo, corpo, alvoMinuto),
    }];
  });
}

function avaliar(
    ref: DocumentReference,
    d: DadosDoLembrete,
    agora: Date,
    ligado: Interruptores,
): Avaliacao {
  // Documento inválido sai sem alvos: só volta à consulta em 60 min.
  const avaliacao: Avaliacao = {
    ref,
    minutoDoDia: 0,
    alvosMinuto: [],
    envios: [],
    confirmados: [],
    alvoMorto: false,
  };
  const alvo = alvoDe(d);
  if (
    alvo === null ||
    typeof d.minutosManha !== "number" ||
    typeof d.minutosNoite !== "number" ||
    typeof d.fuso !== "string"
  ) {
    console.warn(`Documento fora do contrato: ${ref.id}`);
    return avaliacao;
  }
  let local: ReturnType<typeof agoraNoFuso>;
  try {
    local = agoraNoFuso(d.fuso, agora);
  } catch {
    console.warn(`Fuso inválido em ${ref.id}: ${d.fuso}`);
    return avaliacao;
  }
  return {
    ...avaliacao,
    minutoDoDia: local.minutoDoDia,
    alvosMinuto: SLOTS.map((slot) => slot.minutos(d)),
    envios: planejarEnvios(alvo, d, local, ligado),
  };
}

async function lerInterruptores(): Promise<Interruptores> {
  // Interruptores do painel (ver lib/dados/config_admin.dart): sem o
  // documento vale ligado, igual no app — um documento velho nunca desliga
  // um recurso novo por acidente. Uma leitura só por execução.
  let rec: Record<string, unknown> | null = null;
  try {
    const r = await getFirestore().doc("config/recursos").get();
    rec = r.exists ? (r.data() as Record<string, unknown>) : null;
  } catch {}
  return (interruptor) => (rec?.[interruptor] as boolean | undefined) ?? true;
}

async function enviarEmFatias(mensagens: Message[]): Promise<SendResponse[]> {
  const respostas: SendResponse[] = [];
  for (let i = 0; i < mensagens.length; i += TAMANHO_MAXIMO_LOTE) {
    const fatia = await getMessaging().sendEach(
        mensagens.slice(i, i + TAMANHO_MAXIMO_LOTE));
    respostas.push(...fatia.responses);
  }
  return respostas;
}

function registrarRespostas(
    avaliacoes: Avaliacao[],
    respostas: SendResponse[],
): number {
  const envios = avaliacoes.flatMap(
      (a) => a.envios.map((envio) => ({a, envio})));
  let enviados = 0;
  envios.forEach(({a, envio}, i) => {
    const r = respostas[i];
    if (r.success) {
      enviados++;
      a.confirmados.push(envio);
      return;
    }
    const codigo = r.error?.code ?? 0;
    console.error(`Falha ao enviar ${envio.slot.chave} para ${a.ref.id}:`,
        r.error?.message);
    // UNREGISTERED/INVALID_ARGUMENT = FID/token apagado/expirado ou
    // inválido: nada a fazer além de remover o cadastro. Outros códigos
    // (rede, cota) são passageiros; a próxima rodada tenta de novo.
    if (codigo === "messaging/registration-token-not-registered" ||
        codigo === "messaging/installation-id-not-registered" ||
        codigo === "messaging/invalid-argument") {
      a.alvoMorto = true;
    }
  });
  return enviados;
}

type Gravacao = {
  ref: DocumentReference;
  atualizacao: Record<string, string | Timestamp> | "apagar";
};

// Um documento que sumiu entre a leitura e a escrita (a pessoa desligou o
// lembrete) derruba o commit do lote inteiro; nesse caso grava um a um, para
// os outros até 499 não ficarem vencidos e receberem o mesmo push de novo.
async function gravarEmLotes(gravacoes: Gravacao[]): Promise<void> {
  for (let i = 0; i < gravacoes.length; i += TAMANHO_MAXIMO_LOTE) {
    const fatia = gravacoes.slice(i, i + TAMANHO_MAXIMO_LOTE);
    const lote = getFirestore().batch();
    for (const {ref, atualizacao} of fatia) {
      if (atualizacao === "apagar") lote.delete(ref);
      else lote.update(ref, atualizacao);
    }
    try {
      await lote.commit();
    } catch (erro) {
      console.error("Lote de lembretes falhou, gravando um a um:", erro);
      await Promise.all(fatia.map(async ({ref, atualizacao}) => {
        try {
          if (atualizacao === "apagar") await ref.delete();
          else await ref.update(atualizacao);
        } catch (erroDoDocumento) {
          console.error(`Falha ao gravar ${ref.path}:`, erroDoDocumento);
        }
      }));
    }
  }
}

async function gravarResultados(
    avaliacoes: Avaliacao[],
    agora: Date,
): Promise<void> {
  await gravarEmLotes(avaliacoes.map((a): Gravacao => {
    if (a.alvoMorto) return {ref: a.ref, atualizacao: "apagar"};
    const reenviar = a.confirmados.length < a.envios.length;
    const atualizacao: Record<string, string | Timestamp> = {
      proximoEnvio: Timestamp.fromDate(calcularProximoEnvio(
          agora, a.minutoDoDia, a.alvosMinuto, reenviar)),
    };
    for (const envio of a.confirmados) {
      atualizacao[envio.slot.campoUltimoEnvio] = envio.diaISO;
    }
    return {ref: a.ref, atualizacao};
  }));
}

export const enviarLembretes = onSchedule(
  // O runtime (nodejs22) vem do "engines.node" do package.json — na v7 das
  // functions não se define runtime por aqui. Cron unix, não "every X
  // minutes": esse atalho não tem forma de dizer "1" (singular quebra o
  // parser do Scheduler).
  {schedule: "* * * * *", timeZone: "Etc/UTC", timeoutSeconds: 120},
  async () => {
    const agora = new Date();
    const ligado = await lerInterruptores();

    const vencidos = await getFirestore().collection(COLECAO)
      .where("proximoEnvio", "<=", Timestamp.fromDate(agora)).get();
    console.log(`${vencidos.size} lembrete(s) vencido(s).`);

    const avaliacoes = vencidos.docs.map((doc) =>
      avaliar(doc.ref, doc.data() as DadosDoLembrete, agora, ligado));
    const mensagens = avaliacoes.flatMap(
        (a) => a.envios.map((envio) => envio.message));
    const respostas = await enviarEmFatias(mensagens);
    const enviados = registrarRespostas(avaliacoes, respostas);
    await gravarResultados(avaliacoes, agora);

    const removidos = avaliacoes.filter((a) => a.alvoMorto).length;
    console.log(`${enviados} push(es) enviado(s), ${removidos} removido(s).`);
  },
);

// Documento sem `proximoEnvio` (cadastro novo, APK antigo que regrava com
// .set e apaga o campo) nunca entra na consulta acima: marca como vencido
// agora, para a execução do próximo minuto pegá-lo. Não entra em loop porque
// depois da escrita o documento passa a ter o campo.
export const prepararLembrete = onDocumentWritten(
  {document: `${COLECAO}/{id}`, region: REGIAO_DO_BANCO},
  async (evento) => {
    const depois = evento.data?.after;
    if (!depois?.exists || depois.get("proximoEnvio") !== undefined) return;
    await depois.ref.update({proximoEnvio: Timestamp.now()});
  },
);
