import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';

class DevocionalPergunta extends StatelessWidget {
  const DevocionalPergunta(this.item, {super.key});

  final (String, String) item;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(item.$1, style: tema.titleMedium),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: DevocionalEspacamento.sp12),
          child: Text(item.$2, style: tema.bodyLarge?.copyWith(height: 1.7)),
        ),
      ],
    );
  }
}
