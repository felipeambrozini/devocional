// Regras puras do lembrete (sem Firestore, FCM ou relógio) para poderem ser
// testadas com node --test sobre o JS compilado.

// Minutos depois do horário cadastrado em que o push ainda é enviado. O app,
// do outro lado, suprime push mais de 5 min atrasado (o alarme local já
// avisou) — ver `pushAindaVale` em lib/dados/lembretes.dart.
export const TOLERANCIA_MINUTOS = 60;

const MINUTOS_POR_DIA = 1440;

export interface ReferenciaDoSlot {
  diaISO: string;
  diaChave: string;
}

export function ehBissexto(ano: number): boolean {
  return (ano % 4 === 0 && ano % 100 !== 0) || ano % 400 === 0;
}

/// Minutos de atraso de [agora] sobre [alvo], considerando a virada da
/// meia-noite (alvo 23:55, agora 00:03 → 8). Antes do alvo no mesmo dia
/// volta pelo fim do dia anterior (número alto = ainda não deu a hora).
export function atrasoMinutos(agora: number, alvo: number): number {
  const diferenca = (agora - alvo) % MINUTOS_POR_DIA;
  return diferenca < 0 ? diferenca + MINUTOS_POR_DIA : diferenca;
}

export function deveEnviar(
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

function referenciaDoDia(dataUtc: Date): ReferenciaDoSlot {
  const [ano, mes, dia] = dataUtc.toISOString().slice(0, 10).split("-");
  return {diaISO: `${ano}-${mes}-${dia}`, diaChave: `${dia}-${mes}`};
}

/// Dia a que o slot pertence. Se agora (minutos locais) é menor que o alvo,
/// o atraso veio da volta da meia-noite (alvo 23:30, agora 00:05): o slot é
/// o de ontem, tanto para o "já enviado" quanto para o conteúdo.
export function referenciaDoSlot(
    diaISOAgora: string,
    agoraMinuto: number,
    alvoMinuto: number,
): ReferenciaDoSlot {
  const hoje = new Date(`${diaISOAgora}T00:00:00Z`);
  if (agoraMinuto >= alvoMinuto) return referenciaDoDia(hoje);
  hoje.setUTCDate(hoje.getUTCDate() - 1);
  return referenciaDoDia(hoje);
}

/// Instante em que o documento deve voltar a ser lido. Sempre no futuro e a
/// no máximo uma hora; [reenviar] marca envio que falhou e pede nova tentativa
/// no minuto seguinte.
export function calcularProximoEnvio(
    agora: Date,
    agoraMinuto: number,
    alvosMinuto: number[],
    reenviar: boolean,
): Date {
  const minutosAteSlot = alvosMinuto.map(
      (alvo) => (alvo - agoraMinuto + MINUTOS_POR_DIA) % MINUTOS_POR_DIA ||
        MINUTOS_POR_DIA,
  );
  // ponytail: teto de 60 min evita converter fuso local para UTC; ceiling:
  // uma leitura por documento por hora no pior caso; upgrade: calcular o
  // instante exato do próximo slot no fuso do documento.
  const espera = reenviar ? 1 : Math.min(60, ...minutosAteSlot);
  const inicioDoMinuto = Math.floor(agora.getTime() / 60000) * 60000;
  return new Date(inicioDoMinuto + espera * 60000);
}
