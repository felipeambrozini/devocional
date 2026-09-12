import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/nuvem.dart';
import '../estilo/espacamento.dart';
import '../funcoes/conta_acoes.dart';
import 'botao.dart';
import 'layout_leitura.dart';

/// O caminho para entrar na conta — usado quando o plano foi aberto por link
/// e só participantes o veem, ou quando a aba Meus Planos depende de conta
/// para guardar planos próprios na nuvem (ver `titulo`/`descricao`).
class DevocionalCartaoDeEntrar extends StatelessWidget {
  const DevocionalCartaoDeEntrar({
    super.key,
    required this.onEntrar,
    this.titulo = 'Este plano é compartilhado por link',
    this.descricao =
        'Entre com sua conta para participar, marcar os dias lidos '
        'e ver o progresso de todos.',
  });

  final VoidCallback onEntrar;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    return DevocionalLarguraDeLeitura(
      // Center + SingleChildScrollView: sem isto, um título/descrição mais
      // longos (ver o uso em aba_dos_meus_planos.dart) podem estourar a
      // altura disponível numa janela baixa, em vez de só rolar.
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(DevocionalEspacamento.sp20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp8),
                    Text(
                      descricao,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp16),
                    ListenableBuilder(
                      listenable: Nuvem.instancia,
                      builder: (context, _) => DevocionalBotaoPrimario.icon(
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
        ),
      ),
    );
  }
}
