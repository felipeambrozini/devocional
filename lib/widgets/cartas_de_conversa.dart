import 'package:flutter/material.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import 'carta_de_conversa.dart';

class DevocionalCartasDeConversa extends StatelessWidget {
  const DevocionalCartasDeConversa({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
      children: [
        Text(
          'Pergunte sobre a Palavra, peça uma aplicação, desabafe.',
          style: tema.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
        ),
        const SizedBox(height: DevocionalEspacamento.sp16),
        DevocionalCartaDeConversa(
          persona: personaSpurgeon,
          sobre: 'Sobre a Palavra e a vida',
        ),
        const SizedBox(height: DevocionalEspacamento.sp16),
        DevocionalCartaDeConversa(
          persona: personaFelipe,
          sobre: 'Sobre a fé e a jornada',
        ),
      ],
    );
  }
}
