import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import 'botao.dart';
import 'faixa.dart';

/// Um dia de leitura: número, o que se lê e o botão de marcar como lido.
///
/// Serve o cronograma anual (com data e borda dourada no dia de hoje) e os
/// dias dos planos do usuário (uma sequência de 1 a N), porque são a mesma
/// peça de UI.
class DevocionalCartaoDeDia extends StatelessWidget {
  const DevocionalCartaoDeDia({
    super.key,
    required this.numero,
    required this.rotulo,
    required this.itens,
    required this.lido,
    required this.aoAlternar,
    this.destacar = false,
  });

  final int numero;
  final String rotulo;
  final List<ItemDoDia> itens;
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
          DevocionalEspacamento.sp14,
          DevocionalEspacamento.sp12,
          DevocionalEspacamento.sp8,
          DevocionalEspacamento.sp12,
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
            const SizedBox(width: DevocionalEspacamento.sp8),
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
                  const SizedBox(height: DevocionalEspacamento.sp10),
                  Wrap(
                    spacing: DevocionalEspacamento.sp8,
                    runSpacing: DevocionalEspacamento.sp8,
                    children: [
                      for (final item in itens)
                        switch (item) {
                          ItemDeCapitulo(:final faixa) =>
                            DevocionalBotaoDeFaixa(faixa: faixa),
                          ItemDeDevocional(:final tipo, :final chaveDoDia) =>
                            DevocionalBotaoDeDevocional(
                              tipo: tipo,
                              chaveDoDia: chaveDoDia,
                            ),
                        },
                    ],
                  ),
                ],
              ),
            ),
            DevocionalBotaoDeLido(lido: lido, aoAlternar: aoAlternar),
          ],
        ),
      ),
    );
  }
}
