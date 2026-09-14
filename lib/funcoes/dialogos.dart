import 'package:flutter/material.dart';

import '../widgets/botao.dart';
import 'aviso.dart';

/// Editor de nota de um versículo. Devolve o texto salvo, ou nulo se cancelado.
Future<String?> editarNota(
  BuildContext context, {
  required String referencia,
  required String notaAtual,
}) {
  final controle = TextEditingController(text: notaAtual);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(referencia, style: Theme.of(context).textTheme.headlineSmall),
      content: TextField(
        controller: controle,
        autofocus: true,
        maxLines: 6,
        minLines: 3,
        decoration: const InputDecoration(hintText: 'Sua anotação'),
      ),
      actions: [
        DevocionalBotaoTerciario(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        DevocionalBotaoPrimario(
          onPressed: () => Navigator.pop(context, controle.text),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// Confirmação antes de remover uma marcação. Devolve true só se o usuário confirmar.
Future<bool> confirmarRemocao(
  BuildContext context, {
  required String referencia,
  required bool comNota,
}) => confirmar(
  context,
  titulo: 'Remover dos favoritos?',
  conteudo: comNota
      ? '$referencia e a anotação serão removidos. Essa ação não pode ser desfeita.'
      : '$referencia será removido dos favoritos. Essa ação não pode ser desfeita.',
  rotuloDaAcao: 'Remover',
);

/// Largura de conteúdo de diálogo que cabe no celular: a cheia em tela
/// larga, a tela menos as margens do AlertDialog em tela estreita (a fixa
/// de 460px estourava a janela de 360px).
double larguraDeDialogo(BuildContext context, double cheia) {
  final estreita = MediaQuery.sizeOf(context).width - 128;
  return estreita < cheia ? estreita : cheia;
}
