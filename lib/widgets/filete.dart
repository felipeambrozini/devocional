import 'package:flutter/material.dart';

/// DevocionalFilete do metal do tema, usado para separar seções sem o peso de um Divider
/// comum. Dourado no escuro, bronze no claro.
class DevocionalFilete extends StatelessWidget {
  const DevocionalFilete({super.key, this.largura = 48});

  final double largura;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Container(
      width: largura,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cor.primary, cor.outline]),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
