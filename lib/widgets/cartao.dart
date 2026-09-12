import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';

/// Cartão com título em Cinzel na cor do tema. Repete em quase toda tela.
class DevocionalCartao extends StatelessWidget {
  const DevocionalCartao({
    super.key,
    this.titulo,
    this.acessorio,
    required this.child,
    this.padding = const EdgeInsets.all(DevocionalEspacamento.sp16),
  });

  final String? titulo;
  final Widget? acessorio;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ?acessorio,
                ],
              ),
              const SizedBox(height: DevocionalEspacamento.sp12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
