import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../widgets/widgets.dart';

/// Sem conversa nenhuma ainda: o convite para começar, no lugar da lista vazia.
class DevocionalSemConversas extends StatelessWidget {
  const DevocionalSemConversas({
    super.key,
    required this.persona,
    required this.aoComecar,
  });

  final Persona persona;
  final VoidCallback aoComecar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DevocionalFilete(largura: 64),
            const SizedBox(height: DevocionalEspacamento.sp18),
            Text(
              persona.nome,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: DevocionalEspacamento.sp10),
            Text(
              'Nenhuma conversa com ${persona.nome} ainda. '
              'Comece pela primeira pergunta.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: DevocionalEspacamento.sp12),
            // O histórico é a porta de entrada do chat: o aviso de que as
            // respostas são geradas por IA aparece aqui, antes da conversa,
            // além do rodapé do chat e da carta de boas-vindas.
            Text(
              avisoDeIa,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DevocionalEspacamento.sp18),
            DevocionalBotaoPrimario.icon(
              onPressed: aoComecar,
              icon: const FaIcon(FontAwesomeIcons.commentDots),
              label: const Text('Começar conversa'),
            ),
          ],
        ),
      ),
    );
  }
}
