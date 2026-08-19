import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/personas.dart';
import '../spacing.dart';
import 'comuns.dart';

/// A aba Conversas: a porta de entrada do chat no celular e no computador.
///
/// Uma carta por persona, com o retrato no anel do metal e o que cada
/// conversa é. Tocar abre o histórico da persona por cima da aba — o mesmo
/// caminho que os balões das telas largas empurram (ver `_ComBaloes` em
/// `main.dart`), então a URL própria de cada chat vale das duas entradas.
class TelaConversas extends StatelessWidget {
  const TelaConversas({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Conversas')),
      body: LarguraDeLeitura(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.sp16),
          children: [
            Text(
              'Pergunte sobre a Palavra, peça uma aplicação, desabafe.',
              style: tema.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sp16),
            _CartaDeConversa(
              persona: personaSpurgeon,
              sobre: 'Sobre a Palavra e a vida',
            ),
            const SizedBox(height: Spacing.sp16),
            _CartaDeConversa(
              persona: personaFelipe,
              sobre: 'Sobre a fé e a jornada',
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma carta da aba Conversas: o retrato no anel, o nome em Cinzel e o que
/// aquela conversa é, tudo como um alvo só que abre o histórico da persona.
class _CartaDeConversa extends StatelessWidget {
  const _CartaDeConversa({required this.persona, required this.sobre});

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
          padding: const EdgeInsets.all(Spacing.sp16),
          child: Row(
            children: [
              RetratoDePersona(persona: persona, tamanho: 56),
              const SizedBox(width: Spacing.sp16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(persona.nome, style: tema.titleLarge),
                    const SizedBox(height: Spacing.sp4),
                    Text(
                      sobre,
                      style: tema.bodyMedium?.copyWith(
                        color: cor.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cor.primary),
            ],
          ),
        ),
      ),
    );
  }
}