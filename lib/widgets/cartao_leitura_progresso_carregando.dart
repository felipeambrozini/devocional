import 'package:flutter/material.dart';

import '../estilo/spacing.dart';
import 'cartao.dart';
import 'filete.dart';

class DevocionalCartaoLeituraProgressoCarregando extends StatelessWidget {
  const DevocionalCartaoLeituraProgressoCarregando({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return DevocionalCartao(
      padding: const EdgeInsets.all(DevocionalEspacamento.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DevocionalFilete(),
          const SizedBox(height: DevocionalEspacamento.sp12),
          Text('Leitura de hoje', style: tema.titleLarge),
          const SizedBox(height: DevocionalEspacamento.sp8),
          Text('Carregando...', style: tema.bodyMedium),
        ],
      ),
    );
  }
}
