import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';
import 'cartao.dart';
import 'filete.dart';

class DevocionalCartaoLeituraProgressoErro extends StatelessWidget {
  const DevocionalCartaoLeituraProgressoErro({super.key, required this.mensagem});
  final String mensagem;

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
          Text(mensagem, style: tema.bodyMedium),
        ],
      ),
    );
  }
}
