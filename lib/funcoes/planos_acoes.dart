import 'package:flutter/material.dart';

import '../data/estado.dart';
import '../data/planos_nuvem.dart';
import 'aviso.dart';

/// Ações de plano que tocam a nuvem antes do espelho local, com a confirmação
/// destrutiva na frente. Moram fora de `widgets/widgets.dart` para a biblioteca de
/// widgets não acumular regra de negócio.

/// Confirma e exclui um plano — o compartilhado some da nuvem para todos
/// antes do espelho local sumir, o local só sai do espelho. Devolve se
/// excluiu de fato, para quem chama (a tela do plano) saber se ainda pode
/// sair dela.
///
/// Público porque a lixeira do cartão de "Meus Planos" (`plano.dart`) e o
/// menu de opções dentro do plano (`meu_plano.dart`) levam à mesma exclusão.
Future<bool> excluirPlano(
  BuildContext context,
  Estado estado,
  String planoId, {
  required bool compartilhado,
}) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Excluir plano?',
    conteudo: compartilhado
        ? 'O plano será apagado para todos os participantes, junto com o '
              'progresso de cada um. Essa ação não pode ser desfeita.'
        : 'O plano e o progresso dele serão apagados. Essa ação não pode '
              'ser desfeita.',
    rotuloDaAcao: 'Excluir',
  );
  if (!confirmou) return false;
  if (compartilhado) {
    try {
      await PlanosNaNuvem.instancia.excluir(planoId);
    } on PlanosNaNuvemException catch (erro) {
      if (context.mounted) mostrarErro(context, erro.mensagem);
      return false;
    }
  }
  await estado.removerPlano(planoId);
  return true;
}

/// Confirma e sai de um plano compartilhado: apaga só a própria participação
/// na nuvem, e o plano some do espelho local — mas continua existindo para
/// quem ficou. É o que a lixeira faz por quem não é o criador, que não tem o
/// poder de [excluirPlano] para todos.
Future<bool> sairDoPlano(
  BuildContext context,
  Estado estado,
  String planoId,
) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Sair do plano?',
    conteudo:
        'Seu progresso deixa de aparecer para os outros; o plano continua '
        'para quem permaneceu.',
    rotuloDaAcao: 'Sair',
  );
  if (!confirmou) return false;
  try {
    await PlanosNaNuvem.instancia.sair(planoId);
  } on PlanosNaNuvemException catch (erro) {
    if (context.mounted) mostrarErro(context, erro.mensagem);
    return false;
  }
  await estado.removerPlano(planoId);
  return true;
}
