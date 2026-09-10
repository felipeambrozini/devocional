import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/personas.dart';
import '../estilo/spacing.dart';
import 'retrato_de_persona.dart';

/// Uma carta da aba Conversas: o retrato no anel, o nome em Cinzel e o que
/// aquela conversa é, tudo como um alvo só que abre o histórico da persona.
class DevocionalCartaDeConversa extends StatelessWidget {
  const DevocionalCartaDeConversa({super.key, required this.persona, required this.sobre});

  final Persona persona;
  final String sobre;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/${persona.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
          child: Row(
            children: [
              DevocionalRetratoDePersona(persona: persona, tamanho: 56),
              const SizedBox(width: DevocionalEspacamento.sp16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(persona.nome, style: tema.titleLarge),
                    const SizedBox(height: DevocionalEspacamento.sp4),
                    Text(
                      sobre,
                      style: tema.bodyMedium?.copyWith(
                        color: cor.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FaIcon(FontAwesomeIcons.chevronRight, color: cor.primary),
            ],
          ),
        ),
      ),
    );
  }
}
