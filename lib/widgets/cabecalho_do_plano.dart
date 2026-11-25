import 'package:material_ui/material_ui.dart';

import '../dados/planos.dart';
import '../estilo/espacamento.dart';
import 'progresso_fino.dart';

class TabernaculoCabecalhoDoPlano extends StatelessWidget {
  const TabernaculoCabecalhoDoPlano({
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
        padding: const EdgeInsets.all(TabernaculoEspacamento.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(listaDosLivros(plano.livros), style: tema.titleMedium),
            const SizedBox(height: TabernaculoEspacamento.sp4),
            Text(
              '${plano.dias} dias · ${plano.totalDeCapitulos} capítulos',
              style: tema.bodySmall?.copyWith(color: cor.onSurfaceVariant),
            ),
            const SizedBox(height: TabernaculoEspacamento.sp12),
            Text('$lidos de $totalDeDias dias lidos', style: tema.labelMedium),
            const SizedBox(height: TabernaculoEspacamento.sp6),
            TabernaculoProgressoFino(
              valor: totalDeDias == 0 ? 0 : lidos / totalDeDias,
            ),
          ],
        ),
      ),
    );
  }
}
