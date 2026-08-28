// Lembretes diários do devocional — o servidor que decide quem avisar.
//
// Roda a cada minuto (Cloud Scheduler, infra do Google — sem os atrasos de
// 10-30 min do cron do GitHub Actions que matou a versão anterior). É o
// único caminho de lembrete na web — `flutter_local_notifications_web` não
// implementa `zonedSchedule` (lança `UnsupportedError`), então lá não existe
// reserva local — por isso a cadência apertada: cada minuto de atraso aqui é
// um minuto de atraso na única notificação que a web recebe.
// Lê a coleção `lembretes` no Firestore ({token, minutosManha, minutosNoite,
// fuso}, gravada pelo app; ver lib/data/lembretes.dart) e envia via FCM uma
// mensagem **data-only** para quem venceu o horário:
//
//   - data-only acorda o handler Dart com o app morto no Android, que exibe
//     via notificação local (o lembrete local recorrente de reserva do
//     Android continua rodando por conta própria, sem cancelamento cruzado —
//     ver `LembretesReais._armarReservas` em lib/data/lembretes.dart);
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
// Conteúdo: assets/conteudo-lembretes.json — gerado dos JSONs do app
// (manha_e_noite/promessas_de_deus) só com referência e título, que é tudo
// que a notificação usa ("Devocional da Manhã | Gênesis 1:2"). Regenerar se
// algum dia o conteúdo anual mudar.
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging, Message} from "firebase-admin/messaging";
import {onSchedule} from "firebase-functions/v2/scheduler";
import conteudoJson from "./assets/conteudo-lembretes.json";

initializeApp();

const COLECAO = "lembretes";

// Minutos depois do horário cadastrado em que o push ainda é enviado. O app,
// do outro lado, suprime push mais de 5 min atrasado (o alarme local já
// avisou) — ver `pushAindaVale` em lib/data/lembretes.dart.
const TOLERANCIA_MINUTOS = 60;

interface PromessaDia {
  t: string;
  r: string;
}

type DiaConteudo = {m?: string; n?: string; p?: PromessaDia; l?: string; lb?: string};

function ehBissexto(ano: number): boolean {
  return (ano % 4 === 0 && ano % 100 !== 0) || ano % 400 === 0;
}

const conteudoPorDia = conteudoJson as Record<string, DiaConteudo>;

interface DadosDoLembrete {
  token: string;
  minutosManha: number;
  minutosPromessas: number;
  minutosLeitura: number;
  minutosNoite: number;
  fuso: string;
  ultimoEnvioManha?: string;
  ultimoEnvioPromessas?: string;
  ultimoEnvioLeitura?: string;
  ultimoEnvioNoite?: string;
}

function agoraNoFuso(fuso: string): {
  diaISO: string;
  diaChave: string;
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
  }).formatToParts(new Date());
  const p = (tipo: string) => partes.find((x) => x.type === tipo)?.value ?? "";
  const hora = Number(p("hour"));
  const minuto = Number(p("minute"));
  return {
    diaISO: `${p("year")}-${p("month")}-${p("day")}`,
    diaChave: `${p("day")}-${p("month")}`,
    minutoDoDia: hora * 60 + minuto,
  };
}

/// Minutos de atraso de [agora] sobre [alvo], considerando a virada da
/// meia-noite (alvo 23:55, agora 00:03 → 8). Antes do alvo no mesmo dia
/// volta pelo fim do dia anterior (número alto = ainda não deu a hora).
function atrasoMinutos(agora: number, alvo: number): number {
  const diferenca = (agora - alvo) % 1440;
  return diferenca < 0 ? diferenca + 1440 : diferenca;
}

function deveEnviar(
    agoraMinuto: number,
    alvoMinuto: number,
    ultimoEnvio: string | undefined,
    diaISO: string,
): boolean {
  return (
    ultimoEnvio !== diaISO &&
    atrasoMinutos(agoraMinuto, alvoMinuto) <= TOLERANCIA_MINUTOS
  );
}

function mensagem(
    token: string,
    chave: string,
    titulo: string,
    corpo: string,
    minutosDoSlot: number,
): Message {
  return {
    token,
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

export const enviarLembretes = onSchedule(
  // O runtime (nodejs22) vem do "engines.node" do package.json — na v7 das
  // functions não se define runtime por aqui. Cron unix, não "every X
  // minutes": esse atalho não tem forma de dizer "1" (singular quebra o
  // parser do Scheduler).
  {schedule: "* * * * *", timeZone: "Etc/UTC"},
  async () => {
    const db = getFirestore();
    const snap = await db.collection(COLECAO).get();
    console.log(`${snap.size} lembrete(s) cadastrado(s).`);

    let enviados = 0;
    let removidos = 0;

    for (const doc of snap.docs) {
      const d = doc.data() as DadosDoLembrete;
      // Compatibilidade: documentos antigos só tinham manha/noite; promessas
      // e leitura herdam da manhã até o app reescrever com os 4 campos.
      const minutosPromessas = typeof (d as any).minutosPromessas === "number"
        ? (d as any).minutosPromessas as number : d.minutosManha;
      const minutosLeitura = typeof (d as any).minutosLeitura === "number"
        ? (d as any).minutosLeitura as number : d.minutosManha;
      if (
        typeof d.token !== "string" ||
        typeof d.minutosManha !== "number" ||
        typeof d.minutosNoite !== "number" ||
        typeof d.fuso !== "string"
      ) {
        console.warn(`Documento fora do contrato: ${doc.id}`);
        continue;
      }

      let local: ReturnType<typeof agoraNoFuso>;
      try {
        local = agoraNoFuso(d.fuso);
      } catch {
        console.warn(`Fuso inválido em ${doc.id}: ${d.fuso}`);
        continue;
      }
      const conteudoDia = conteudoPorDia[local.diaChave];
      if (!conteudoDia) continue;

      type Slot = "manha" | "promessas" | "leitura" | "noite";
      const pendentes: {slot: Slot; message: Message}[] = [];

      if (deveEnviar(local.minutoDoDia, d.minutosManha, d.ultimoEnvioManha, local.diaISO)) {
        if (conteudoDia.m) {
          pendentes.push({
            slot: "manha",
            message: mensagem(d.token, "manha", "Devocional da Manhã",
              conteudoDia.m, d.minutosManha),
          });
        }
      }

      if (deveEnviar(local.minutoDoDia, minutosPromessas, (d as any).ultimoEnvioPromessas, local.diaISO)) {
        if (conteudoDia.p?.r) {
          pendentes.push({
            slot: "promessas",
            message: mensagem(d.token, "promessas", "Promessas de Deus",
              `Venha ler a Promessa de Deus para o seu dia em ${conteudoDia.p.r}`, minutosPromessas),
          });
        }
      }

      if (deveEnviar(local.minutoDoDia, minutosLeitura, (d as any).ultimoEnvioLeitura, local.diaISO)) {
        const ano = Number(local.diaISO.slice(0, 4));
        const leituraLabel = ehBissexto(ano)
          ? (conteudoDia.lb ?? conteudoDia.l)
          : conteudoDia.l;
        if (leituraLabel) {
          pendentes.push({
            slot: "leitura",
            message: mensagem(d.token, "leitura", "Leitura do Dia",
              leituraLabel, minutosLeitura),
          });
        }
      }

      if (deveEnviar(local.minutoDoDia, d.minutosNoite, d.ultimoEnvioNoite, local.diaISO)) {
        if (conteudoDia.n) {
          pendentes.push({
            slot: "noite",
            message: mensagem(d.token, "noite", "Devocional da Noite",
              conteudoDia.n, d.minutosNoite),
          });
        }
      }

      if (pendentes.length === 0) continue;

      const resposta = await getMessaging().sendEach(
        pendentes.map((x) => x.message),
      );

      const slotsOk = new Set<Slot>();
      let tokenMorto = false;
      resposta.responses.forEach((r, i) => {
        if (r.success) {
          enviados++;
          slotsOk.add(pendentes[i].slot);
          return;
        }
        const codigo = r.error?.code ?? 0;
        console.error(`Falha ao enviar ${pendentes[i].slot} para ${doc.id}:`,
          r.error?.message);
        // UNREGISTERED/INVALID_ARGUMENT = token apagado/expirado ou inválido:
        // nada a fazer além de remover o cadastro. Outros códigos (rede, cota)
        // são passageiros; a próxima rodada tenta de novo dentro da janela.
        if (codigo === "messaging/registration-token-not-registered" ||
            codigo === "messaging/invalid-argument") {
          tokenMorto = true;
        }
      });

      if (tokenMorto) {
        await doc.ref.delete();
        removidos++;
        continue;
      }

      const atualizacao: Record<string, string> = {};
      if (slotsOk.has("manha") && d.ultimoEnvioManha !== local.diaISO) {
        atualizacao.ultimoEnvioManha = local.diaISO;
      }
      if (slotsOk.has("promessas") && (d as any).ultimoEnvioPromessas !== local.diaISO) {
        atualizacao.ultimoEnvioPromessas = local.diaISO;
      }
      if (slotsOk.has("leitura") && (d as any).ultimoEnvioLeitura !== local.diaISO) {
        atualizacao.ultimoEnvioLeitura = local.diaISO;
      }
      if (slotsOk.has("noite") && d.ultimoEnvioNoite !== local.diaISO) {
        atualizacao.ultimoEnvioNoite = local.diaISO;
      }
      if (Object.keys(atualizacao).length > 0) {
        await doc.ref.update(atualizacao);
      }
    }

    console.log(`${enviados} push(es) enviado(s), ${removidos} removido(s).`);
  },
);
