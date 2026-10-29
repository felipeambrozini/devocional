import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dados/nuvem.dart';
import '../estilo/espacamento.dart';
import '../funcoes/conta_acoes.dart';
import 'botao.dart';

/// Número que recebe o pedido de acesso pelo WhatsApp, para quem ainda não
/// está numa allowlist de recurso (ver `lib/dados/recursos.dart`).
/// Mesmo padrão de `--dart-define` do `_emailDeContato` em `sobre.dart`: sem
/// número versionado no repositório, e vazio esconde o botão.
const _numeroWhatsapp = String.fromEnvironment('WHATSAPP_NUMERO');

/// Convite para pedir acesso ao chat, que ainda depende de allowlist, quando
/// quem abre a tela não está nela. Explicar o que falta e como pedir é a
/// filosofia de gating do app: esconder a aba em silêncio quebra o próprio
/// convite de crescimento por WhatsApp que o produto já usa em Conversas.
class DevocionalCartaoDePedirAcesso extends StatelessWidget {
  const DevocionalCartaoDePedirAcesso({
    super.key,
    required this.icone,
    required this.descricao,
    required this.mensagemDoWhatsapp,
  });

  final FaIconData icone;
  final String descricao;
  final String mensagemDoWhatsapp;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icone, size: 56, color: cor.primary),
            const SizedBox(height: DevocionalEspacamento.sp16),
            Text(
              'Acesso sob pedido',
              style: tema.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DevocionalEspacamento.sp8),
            Text(
              descricao,
              style: tema.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            // As allowlists são por e-mail (ver `lib/dados/recursos.dart`):
            // deslogado, pedir pelo WhatsApp não adianta enquanto a pessoa não
            // entrar na conta, então o convite começa por aí. Ouve a Nuvem
            // aqui porque quem usa este cartão o constrói como const, e o pai
            // não o redesenha.
            ListenableBuilder(
              listenable: Nuvem.instancia,
              builder: (context, _) => _acao(context, Nuvem.instancia),
            ),
          ],
        ),
      ),
    );
  }

  Widget _acao(BuildContext context, Nuvem nuvem) {
    if (nuvem.carregandoConta) return const SizedBox.shrink();
    if (!nuvem.logado) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: DevocionalEspacamento.sp12),
          Text(
            'O acesso é liberado pelo e-mail da conta Google, então entre '
            'primeiro.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DevocionalEspacamento.sp24),
          DevocionalBotaoPrimario.icon(
            onPressed: nuvem.entrando
                ? null
                : () => entrarNaConta(context, nuvem),
            icon: const FaIcon(FontAwesomeIcons.google, size: 16),
            label: const Text('Entrar com Google'),
          ),
        ],
      );
    }
    if (_numeroWhatsapp.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: DevocionalEspacamento.sp24),
      child: DevocionalBotaoPrimario.icon(
        onPressed: () => _abrirWhatsapp(mensagemDoWhatsapp),
        icon: const FaIcon(FontAwesomeIcons.whatsapp),
        label: const Text('Falar no WhatsApp'),
      ),
    );
  }
}

/// Abre o WhatsApp já com a mensagem de pedido de acesso preenchida, para
/// quem tocou o botão não precisar digitá-la.
Future<void> _abrirWhatsapp(String mensagem) async {
  final uri = Uri.https('wa.me', '/$_numeroWhatsapp', {'text': mensagem});
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
