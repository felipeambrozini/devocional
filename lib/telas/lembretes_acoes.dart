import 'package:flutter/material.dart';

import '../data/estado.dart';
import '../data/lembretes.dart';

/// Minutos do dia (0..1439) como [TimeOfDay], para mostrar e escolher o
/// horário na folha de ajustes.
TimeOfDay horaDeMinutos(int minutos) =>
    TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60);

/// Agenda os quatro horários de lembrete com os minutos gravados no [Estado].
/// Um lugar só para saber quais horas são: quem liga, quem troca o horário e
/// quem rearma na abertura do app passam por aqui.
Future<void> _agendarLembretes(Estado estado) => Lembretes.instancia.agendar(
  manha: horaDeMinutos(estado.minutosLembreteManha),
  promessas: horaDeMinutos(estado.minutosLembretePromessas),
  leitura: horaDeMinutos(estado.minutosLembreteLeitura),
  noite: horaDeMinutos(estado.minutosLembreteNoite),
);

/// Liga ou desliga os três lembretes diários. Pede permissão antes de ligar;
/// devolve false sem mudar nada se ela for negada.
///
/// Pública, e não escondida na folha de ajustes: é a mesma regra que
/// `test/lembretes_test.dart` verifica com uma `Lembretes` falsa, sem precisar
/// desmontar a UI para chegar nela.
Future<bool> alternarLembretes(Estado estado, bool ligar) async {
  if (!ligar) {
    await estado.definirLembretesAtivos(false);
    await Lembretes.instancia.cancelar();
    return true;
  }
  final concedida = await Lembretes.instancia.pedirPermissao();
  if (!concedida) return false;
  await estado.definirLembretesAtivos(true);
  await _agendarLembretes(estado);
  return true;
}

/// Grava o novo horário e reagenda de verdade — só se os lembretes estiverem
/// ligados. O guard fica aqui, e não em quem chama: a folha de ajustes só
/// mostra os campos de hora com o interruptor já ligado, mas essa função não
/// deveria depender de a UI garantir isso por fora.
Future<void> aplicarHorarioDeLembrete(
  Estado estado, {
  int? minutosManha,
  int? minutosPromessas,
  int? minutosLeitura,
  int? minutosNoite,
}) async {
  await estado.definirHorariosDeLembrete(
    minutosManha: minutosManha ?? estado.minutosLembreteManha,
    minutosPromessas: minutosPromessas ?? estado.minutosLembretePromessas,
    minutosLeitura: minutosLeitura ?? estado.minutosLembreteLeitura,
    minutosNoite: minutosNoite ?? estado.minutosLembreteNoite,
  );
  if (!estado.lembretesAtivos) return;
  await _agendarLembretes(estado);
}

/// Rearma os lembretes no início do app, sempre que estiverem ligados.
///
/// O lembrete local de reserva é recorrente e sobrevive sozinho sem o app
/// abrir (ver `LembretesReais._armarReservas`), mas regravar o documento do
/// Firestore ainda atualiza o fuso, que ficava preso ao da primeira gravação
/// em quem viajasse — por isso não pula quando já existe registro. A escrita
/// é idempotente e barata.
Future<void> reagendarLembretesSeNecessario(Estado estado) async {
  if (!estado.lembretesAtivos) return;
  await _agendarLembretes(estado);
}
