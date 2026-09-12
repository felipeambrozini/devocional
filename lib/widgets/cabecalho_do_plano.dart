import 'package:flutter/material.dart';

import '../dados/planos.dart';
import '../estilo/espacamento.dart';
import 'progresso_fino.dart';

class DevocionalCabecalhoDoPlano extends StatelessWidget {
  const DevocionalCabecalhoDoPlano({
    super.key,
    required this.plano,
    required this.lidos,
    required this.totalDeDias,
  });

  final PlanoDoUsuario plano;
  final int lidos;
  final int totalDeDias;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(listaDosLivros(plano.livros), style: tema.titleMedium),
            const SizedBox(height: DevocionalEspacamento.sp4),
            Text(
              '${plano.dias} dias · ${plano.totalDeCapitulos} capítulos',
              style: tema.bodySmall?.copyWith(color: cor.onSurfaceVariant),
            ),
            const SizedBox(height: DevocionalEspacamento.sp12),
            Text('$lidos de $totalDeDias dias lidos', style: tema.labelMedium),
            const SizedBox(height: DevocionalEspacamento.sp6),
            DevocionalProgressoFino(valor: totalDeDias == 0 ? 0 : lidos / totalDeDias),
          ],
        ),
      ),
    );
  }
}
