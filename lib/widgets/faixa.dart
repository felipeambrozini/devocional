import 'package:flutter/material.dart';

import '../data/modelos.dart';
import '../telas/biblia.dart';

/// Botão que abre a Bíblia numa faixa do cronograma.
///
/// Quando a faixa é por versículo, como "Salmos 119:1 a 56", abre o capítulo e
/// destaca só o recorte pedido; o resto do capítulo continua visível, apenas
/// esmaecido, para não perder o contexto.
class BotaoDeFaixa extends StatelessWidget {
  const BotaoDeFaixa({super.key, required this.faixa});

  final Faixa faixa;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.menu_book_outlined, size: 17),
      label: Text(faixa.rotulo),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaBiblia(
            livroInicial: faixa.livro,
            capituloInicial: faixa.deCapitulo,
            destacar: faixa.porVersiculo
                ? (faixa.deVersiculo!, faixa.ateVersiculo!)
                : null,
          ),
        ),
      ),
    );
  }
}
