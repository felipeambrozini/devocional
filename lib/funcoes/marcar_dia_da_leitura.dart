import 'package:material_ui/material_ui.dart';

import '../dados/dia_da_leitura.dart';
import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../dados/planos_nuvem.dart';
import 'aviso.dart';
import 'conclusao_do_plano.dart';

/// A pessoa chegou ao fim do capítulo [numero] de [livro], aberto pela
/// leitura de [dia]: guarda o capítulo como lido no dia e, se era o último que
/// faltava, marca o dia. As leituras de um dia podem ser feitas em momentos
/// diferentes (Gênesis de manhã, Salmos à noite), por isso o andamento fica
/// guardado em `Estado.progressoDosDias`.
Future<void> registrarCapituloLidoDoDia(
  BuildContext context,
  Estado estado,
  DiaDaLeitura dia,
  String livro,
  int numero,
) async {
  if (!dia.temCapitulo(livro, numero)) return;
  final progresso = estado.progressoDosDias;
  final chave = dia.chaveDoProgresso;
  await progresso.registrar(chave, DiaDaLeitura.capitulo(livro, numero));
  final lidos = progresso.lidosDoDia(chave);
  if (!dia.capitulos.every(lidos.contains)) return;
  if (!context.mounted) return;
  await marcarDiaDaLeituraAoTerminar(context, estado, dia);
  // Marcado (ou já estava): o andamento não serve mais. Quem desfizer a marca
  // marca de novo à mão, ou relê o dia.
  await progresso.esquecer(chave);
}

/// Marca [dia] como lido porque a pessoa chegou ao fim de todos os capítulos
/// dele, e avisa com "Desfazer": ela não tocou em nada, então a marcação
/// precisa aparecer e ter saída de um toque.
///
/// Só marca, nunca desmarca: os métodos do [Estado] alternam, e chamar num
/// dia já lido o desmarcaria. Um plano que não existe mais (apagado, link
/// velho) é ignorado em silêncio.
Future<void> marcarDiaDaLeituraAoTerminar(
  BuildContext context,
  Estado estado,
  DiaDaLeitura dia,
) async {
  switch (dia) {
    case DiaDoCronograma(:final chave):
      if (estado.foiLido(chave)) return;
      await estado.alternarLido(chave);
      if (!context.mounted) return;
      mostrarAviso(
        context,
        'Leitura do dia marcada como lida',
        rotuloDeAcao: 'Desfazer',
        duracao: duracaoDeAvisoAutomatico,
        aoAgir: () {
          if (estado.foiLido(chave)) estado.alternarLido(chave);
        },
      );
    case DiaDePlano(:final planoId, :final numero):
      final plano = estado.planoDoUsuario(planoId);
      if (plano == null || estado.foiLidoNoPlano(planoId, numero)) return;
      final marcou = await _gravarDiaDoPlano(
        context,
        estado,
        planoId,
        numero,
        compartilhado: plano.compartilhado,
        lido: true,
      );
      if (!marcou || !context.mounted) return;
      // O último dia que faltava fecha o plano: o aviso diz isso, e não só o
      // número do dia (ver conclusao_do_plano.dart).
      mostrarAviso(
        context,
        planoConcluido(estado, plano)
            ? avisoDePlanoConcluido(plano)
            : 'Dia $numero de ${plano.titulo} marcado como lido',
        rotuloDeAcao: 'Desfazer',
        duracao: duracaoDeAvisoAutomatico,
        aoAgir: () => _gravarDiaDoPlano(
          context,
          estado,
          planoId,
          numero,
          compartilhado: plano.compartilhado,
          lido: false,
        ),
      );
  }
}

/// Põe o dia [numero] do plano em [lido]. Num plano compartilhado o
/// documento da nuvem é a verdade, como em `PlanoControlador.alternarDia`:
/// sem conta não marca, e se a gravação falhar o espelho local volta ao que
/// era. Devolve se gravou.
Future<bool> _gravarDiaDoPlano(
  BuildContext context,
  Estado estado,
  String planoId,
  int numero, {
  required bool compartilhado,
  required bool lido,
}) async {
  if (estado.foiLidoNoPlano(planoId, numero) == lido) return false;
  if (!compartilhado) {
    await estado.alternarLidoNoPlano(planoId, numero);
    return true;
  }
  // Sem conta não dá para gravar no documento: não marca, e não incomoda com
  // aviso por algo que a pessoa não pediu.
  if (!Nuvem.instancia.logado) return false;
  final plano = estado.planoDoUsuario(planoId);
  if (plano == null) return false;
  final atual = {
    for (final d in plano.diasDoPlano)
      if (estado.foiLidoNoPlano(planoId, d.numero)) d.numero,
  };
  final novo = {...atual};
  if (lido) {
    novo.add(numero);
  } else {
    novo.remove(numero);
  }
  await estado.substituirLidosDoPlano(planoId, novo);
  try {
    await PlanosNaNuvem.instancia.gravarDias(planoId, numero, lido);
    return true;
  } on PlanosNaNuvemExcecao catch (erro) {
    await estado.substituirLidosDoPlano(planoId, atual);
    if (context.mounted) mostrarErro(context, erro.mensagem);
    return false;
  }
}
