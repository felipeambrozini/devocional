import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Um [SelectionArea] com "Compartilhar" a mais no menu de seleção. O texto
/// vira selecionável e copiável de fábrica (o próprio SelectionArea resolve
/// isso), e o mesmo clique forte que hoje abre a seleção nativa passa a
/// mostrar, junto com Copiar, um botão que compartilha o trecho escolhido —
/// sem um gesto novo. Sem formatação de referência: o trecho selecionado
/// pode ser parte de um versículo, um parágrafo do devocional ou da
/// introdução, sem uma referência única por trás. Usada igual nas três
/// telas de leitura (Bíblia, Devocional, Introdução).
class AreaDeSelecaoComCompartilhar extends StatefulWidget {
  const AreaDeSelecaoComCompartilhar({super.key, required this.child});

  final Widget child;

  @override
  State<AreaDeSelecaoComCompartilhar> createState() =>
      _AreaDeSelecaoComCompartilharState();
}

class _AreaDeSelecaoComCompartilharState
    extends State<AreaDeSelecaoComCompartilhar> {
  // SelectableRegionState não expõe o texto selecionado publicamente; captura
  // aqui pelo onSelectionChanged, e o menu lê o valor mais recente ao montar.
  String? _selecionado;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (conteudo) => _selecionado = conteudo?.plainText,
      contextMenuBuilder: (context, estado) {
        final botoes = List.of(estado.contextMenuButtonItems);
        final selecionado = _selecionado;
        if (selecionado != null && selecionado.isNotEmpty) {
          botoes.add(
            ContextMenuButtonItem(
              label: 'Compartilhar',
              onPressed: () {
                estado.hideToolbar();
                SharePlus.instance.share(ShareParams(text: selecionado));
              },
            ),
          );
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: estado.contextMenuAnchors,
          buttonItems: botoes,
        );
      },
      child: widget.child,
    );
  }
}
