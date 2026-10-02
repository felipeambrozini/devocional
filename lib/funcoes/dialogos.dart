import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';
import '../widgets/botao.dart';
import '../widgets/filete.dart';
import 'aviso.dart';

/// Diálogo de uma caixa de texto só: título, um texto de apoio opcional e o
/// campo. Devolve o texto digitado, ou nulo se cancelado.
///
/// O campo mora num `State` porque o `TextEditingController` dele precisa de
/// um `dispose` depois que a rota saiu de vez. Criado na função que abre o
/// diálogo e descartado no `finally` do `Future`, ele morre com a transição de
/// saída ainda rodando, e o `EditableText` da rota morta ainda o usa.
class DialogoDeTexto extends StatefulWidget {
  const DialogoDeTexto({
    super.key,
    required this.titulo,
    required this.rotuloDoCampo,
    required this.rotuloDaAcao,
    this.textoInicial = '',
    this.descricao,
    this.linhasMin = 3,
    this.linhasMax = 6,
    this.autofocus = true,
  });

  final String titulo;
  final String rotuloDoCampo;
  final String rotuloDaAcao;
  final String textoInicial;

  /// Texto de apoio acima do campo; sem ele o diálogo é só título e campo.
  final String? descricao;
  final int linhasMin;
  final int linhasMax;
  final bool autofocus;

  @override
  State<DialogoDeTexto> createState() => _DialogoDeTextoState();
}

class _DialogoDeTextoState extends State<DialogoDeTexto> {
  final _controle = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controle.text = widget.textoInicial;
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final descricao = widget.descricao;
    return AlertDialog(
      title: Text(widget.titulo, style: tema.textTheme.headlineSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DevocionalFilete(largura: 64),
          const SizedBox(height: DevocionalEspacamento.sp12),
          if (descricao != null) ...[
            Text(descricao, style: tema.textTheme.bodySmall),
            const SizedBox(height: DevocionalEspacamento.sp12),
          ],
          TextField(
            controller: _controle,
            autofocus: widget.autofocus,
            maxLines: widget.linhasMax,
            minLines: widget.linhasMin,
            decoration: InputDecoration(
              labelText: widget.rotuloDoCampo,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        DevocionalBotaoTerciario(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        DevocionalBotaoPrimario(
          onPressed: () => Navigator.pop(context, _controle.text),
          child: Text(widget.rotuloDaAcao),
        ),
      ],
    );
  }
}

/// Editor de nota de um versículo. Devolve o texto salvo, ou nulo se cancelado.
Future<String?> editarNota(
  BuildContext context, {
  required String referencia,
  required String notaAtual,
}) => showDialog<String>(
  context: context,
  builder: (_) => DialogoDeTexto(
    titulo: referencia,
    rotuloDoCampo: 'Sua anotação',
    rotuloDaAcao: 'Salvar',
    textoInicial: notaAtual,
  ),
);

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
