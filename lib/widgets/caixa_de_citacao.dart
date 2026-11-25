import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';

/// A gramática da citação: fio do metal de 3 à esquerda sobre o tom de cartão
/// dentro de cartão. Marca a palavra de alguém (a fala da persona, a frase de
/// abertura de um livro, a nota que a pessoa escreveu); a nota de sistema usa
/// outra caixa, de fio fechado (ver `TabernaculoAvisoDeCorte`).
///
/// Sem [comFundo] fica só o fio, reto, para o comentário que acompanha o
/// versículo sem pesar sobre ele.
class TabernaculoCaixaDeCitacao extends StatelessWidget {
  const TabernaculoCaixaDeCitacao({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TabernaculoEspacamento.sp12),
    this.comFundo = true,
    this.expandir = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool comFundo;

  /// Ocupa a largura toda, em vez de só a do conteúdo.
  final bool expandir;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Container(
      width: expandir ? double.infinity : null,
      padding: padding,
      decoration: BoxDecoration(
        color: comFundo ? cor.surfaceContainerHighest : null,
        borderRadius: comFundo ? BorderRadius.circular(10) : null,
        border: Border(left: BorderSide(color: cor.primary, width: 3)),
      ),
      child: child,
    );
  }
}
