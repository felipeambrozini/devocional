import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../estilo/spacing.dart';

/// O convite a compartilhar, ou o atalho para copiar o link de novo.
class DevocionalCartaoDeCompartilhar extends StatelessWidget {
  const DevocionalCartaoDeCompartilhar({
    super.key,
    required this.compartilhado,
    required this.aoCompartilhar,
  });

  final bool compartilhado;
  final VoidCallback aoCompartilhar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compartilhado ? 'Plano compartilhado' : 'Compartilhe o plano',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: DevocionalEspacamento.sp4),
            Text(
              compartilhado
                  ? 'Quem abrir o link entra no plano e o progresso de cada '
                        'um aparece para todos.'
                  : 'Quem abrir o link entra no plano, marca os próprios '
                        'dias e o progresso de cada um aparece para todos.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cor.onSurfaceVariant),
            ),
            const SizedBox(height: DevocionalEspacamento.sp10),
            OutlinedButton.icon(
              onPressed: aoCompartilhar,
              icon: FaIcon(
                compartilhado ? FontAwesomeIcons.link : FontAwesomeIcons.shareNodes,
              ),
              label: Text(compartilhado ? 'Copiar link' : 'Compartilhar'),
            ),
          ],
        ),
      ),
    );
  }
}
