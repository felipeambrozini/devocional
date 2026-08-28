import 'package:flutter/material.dart';

import '../data/modelos.dart';
import '../estilo/spacing.dart';
import 'faixa.dart';

/// Um dia de leitura: número, o que se lê e o botão de marcar como lido.
///
/// Serve o cronograma anual (com data e borda dourada no dia de hoje) e os
/// dias dos planos do usuário (uma sequência de 1 a N), porque são a mesma
/// peça de UI.
class CartaoDeDia extends StatelessWidget {
  const CartaoDeDia({
    super.key,
    required this.numero,
    required this.rotulo,
    required this.faixas,
    required this.lido,
    required this.aoAlternar,
    this.destacar = false,
  });

  final int numero;
  final String rotulo;
  final List<Faixa> faixas;
  final bool lido;

  /// Borda dourada plena, para o dia de hoje se achar de relance dentro de
  /// uma lista de trinta e um cartões parecidos.
  final bool destacar;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: destacar ? cor.primary : cor.outline.withValues(alpha: 0.35),
          width: destacar ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sp14,
          Spacing.sp12,
          Spacing.sp8,
          Spacing.sp12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$numero',
                style: tema.headlineSmall?.copyWith(
                  color: lido ? cor.secondary : cor.primary,
                ),
              ),
            ),
            const SizedBox(width: Spacing.sp8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: tema.bodyMedium?.copyWith(
                      decoration: lido ? TextDecoration.lineThrough : null,
                      color: lido ? cor.onSurfaceVariant : cor.onSurface,
                    ),
                  ),
                  const SizedBox(height: Spacing.sp10),
                  Wrap(
                    spacing: Spacing.sp8,
                    runSpacing: Spacing.sp8,
                    children: [for (final f in faixas) BotaoDeFaixa(faixa: f)],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: lido ? 'Desmarcar' : 'Marcar como lido',
              icon: Icon(
                lido ? Icons.check_circle : Icons.radio_button_unchecked,
                color: lido ? cor.secondary : cor.onSurfaceVariant,
              ),
              onPressed: aoAlternar,
            ),
          ],
        ),
      ),
    );
  }
}
