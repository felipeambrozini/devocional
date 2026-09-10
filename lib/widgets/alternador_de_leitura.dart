import 'package:flutter/material.dart';

import '../estilo/spacing.dart';
import '../telas/devocional.dart';

/// Alternador das três leituras, centralizado.
///
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
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: DevocionalEspacamento.sp8,
      runSpacing: DevocionalEspacamento.sp8,
      children: [
        for (final l in Leitura.values)
          ChoiceChip(
            label: Text(l.rotulo, maxLines: 1),
            selected: l == atual,
            onSelected: (_) => ao(l),
            showCheckmark: false,
          ),
      ],
    );
  }
}
