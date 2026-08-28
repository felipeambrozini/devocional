import 'package:flutter/material.dart';

/// A faixa de progresso do app: fio do metal sobre o trilho do tema, cantos
/// quase retos e altura fina. Um só desenho para o ano (Hoje), para os planos
/// e para o que mais medir ritmo de leitura. A pílula de voz fica de fora de
/// propósito: o trilho dela precisa contrastar com o fundo do próprio
/// comprimido, não com a página.
class ProgressoFino extends StatelessWidget {
  const ProgressoFino({super.key, required this.valor});

  /// Fração concluída, de 0,0 a 1,0. Valor fora da faixa é cortado.
  final double valor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: valor.clamp(0.0, 1.0),
        minHeight: 6,
      ),
    );
  }
}
