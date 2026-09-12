import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';

/// Uma linha da lista de participantes: nome, marca de "Você" e o progresso.
class DevocionalLinhaDeParticipante extends StatelessWidget {
  const DevocionalLinhaDeParticipante({
    super.key,
    required this.nome,
    required this.lidos,
    required this.ehVoce,
    required this.ehCriador,
    required this.totalDeDias,
  });

  final String nome;
  final Set<int> lidos;
  final bool ehVoce;
  final bool ehCriador;
  final int totalDeDias;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nome,
                style: tema.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (ehCriador)
              Padding(
                padding: const EdgeInsets.only(left: DevocionalEspacamento.sp8),
                child: Text(
                  'criador',
                  style: tema.labelSmall?.copyWith(color: cor.onSurfaceVariant),
                ),
              ),
            if (ehVoce)
              Padding(
                padding: const EdgeInsets.only(left: DevocionalEspacamento.sp8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DevocionalEspacamento.sp8,
                    vertical: DevocionalEspacamento.sp2,
                  ),
                  decoration: BoxDecoration(
                    color: cor.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Você',
                    style: tema.labelSmall?.copyWith(color: cor.primary),
                  ),
                ),
              ),
            const SizedBox(width: DevocionalEspacamento.sp8),
            Text('${lidos.length}/$totalDeDias', style: tema.labelMedium),
          ],
        ),
        const SizedBox(height: DevocionalEspacamento.sp4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: totalDeDias == 0 ? 0 : lidos.length / totalDeDias,
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
