import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/nuvem.dart';
import '../estilo/spacing.dart';
import '../funcoes/conta_acoes.dart';
import 'layout_leitura.dart';

/// O caminho para entrar na conta quando o plano foi aberto por link e só
/// participantes o veem.
class DevocionalCartaoDeEntrar extends StatelessWidget {
  const DevocionalCartaoDeEntrar({super.key, required this.onEntrar});

  final VoidCallback onEntrar;

  @override
  Widget build(BuildContext context) {
    return DevocionalLarguraDeLeitura(
      child: Padding(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(DevocionalEspacamento.sp20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Este plano é compartilhado por link',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: DevocionalEspacamento.sp8),
                Text(
                  'Entre com sua conta para participar, marcar os dias lidos '
                  'e ver o progresso de todos.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: DevocionalEspacamento.sp16),
                ListenableBuilder(
                  listenable: Nuvem.instancia,
                  builder: (context, _) => FilledButton.icon(
                    onPressed: Nuvem.instancia.entrando
                        ? null
                        : () async {
                            await entrarNaConta(context, Nuvem.instancia);
                            onEntrar();
                          },
                    icon: Nuvem.instancia.entrando
                        ? const SizedBox(
                            width: DevocionalEspacamento.sp18,
                            height: DevocionalEspacamento.sp18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const FaIcon(FontAwesomeIcons.google, size: 18),
                    label: const Text('Entrar com Google'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
