import 'package:flutter/material.dart';

import '../dados/config_admin.dart';
import '../estilo/espacamento.dart';
import '../telas/devocional.dart';

/// Chips e não SegmentedButton: o SegmentedButton iguala a largura de todos os
/// segmentos à do maior, então três vezes "Promessas de Deus" nunca cabe num
/// celular e o rótulo aparecia cortado. Cada chip se dimensiona pelo próprio
/// texto, e o Wrap passa para uma segunda linha em telas muito estreitas em
/// vez de cortar.
class DevocionalAlternadorDeLeitura extends StatelessWidget {
  const DevocionalAlternadorDeLeitura({super.key, required this.atual, required this.ao});

  final Leitura atual;
  final ValueChanged<Leitura> ao;

  @override
  Widget build(BuildContext context) {
    // Só as leituras ligadas no painel admin viram chip: sem ouvir a
    // configuração, desligar uma leitura deixava o chip à vista. Com uma só
    // (ou nenhuma) ligada, o alternador não tem o que alternar e some.
    return ListenableBuilder(
      listenable: ConfigAdmin.instancia,
      builder: (context, _) {
        final ativas = [
          for (final l in Leitura.values)
            if (leituraAtiva(l)) l,
        ];
        if (ativas.length <= 1) return const SizedBox.shrink();
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: DevocionalEspacamento.sp8,
          runSpacing: DevocionalEspacamento.sp8,
          children: [
            for (final l in ativas)
              ChoiceChip(
                label: Text(l.rotulo, maxLines: 1),
                selected: l == atual,
                onSelected: (_) => ao(l),
                showCheckmark: false,
              ),
          ],
        );
      },
    );
  }
}
