import 'package:flutter/material.dart';

import '../estilo/spacing.dart';

/// Cartão com título em Cinzel na cor do tema. Repete em quase toda tela.
class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    this.titulo,
    this.acessorio,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.sp16),
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
              const SizedBox(height: Spacing.sp12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
