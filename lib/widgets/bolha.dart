import 'package:flutter/material.dart';

import '../estilo/spacing.dart';

/// Bolha pequena usada pelo indicador de "pensando": avatar e recipiente
/// idênticos aos das mensagens, para o rodapé não parecer elemento diferente.
class DevocionalBolha extends StatelessWidget {
  const DevocionalBolha({super.key, required this.avatar, required this.child});

  final String avatar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipOval(
          child: Image.asset(
            avatar,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            // Mesmo recorte das mensagens: o cabelo encosta na borda de cima
            // da foto, e qualquer corte desloca o rosto para fora do centro.
            alignment: Alignment.topCenter,
          ),
        ),
        const SizedBox(width: DevocionalEspacamento.sp8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DevocionalEspacamento.sp14,
            vertical: DevocionalEspacamento.sp12,
          ),
          decoration: BoxDecoration(
            color: cor.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: cor.primary, width: 3)),
          ),
          child: child,
        ),
      ],
    );
  }
}
