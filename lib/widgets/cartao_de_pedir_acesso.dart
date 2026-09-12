import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../estilo/espacamento.dart';
import 'botao.dart';

/// Número que recebe o pedido de acesso pelo WhatsApp, para quem ainda não
/// está numa allowlist de recurso premium (ver `lib/dados/recursos.dart`).
/// Mesmo padrão de `--dart-define` do `_emailDeContato` em `sobre.dart`: sem
/// número versionado no repositório, e vazio esconde o botão.
const _numeroWhatsapp = String.fromEnvironment('WHATSAPP_NUMERO');

/// Convite para pedir acesso a um recurso premium por allowlist, quando quem
/// abre a tela ainda não está nela — mesmo cartão serve Conversas e Meus
/// Planos, só o ícone, a descrição e a mensagem do WhatsApp mudam. Explicar o
/// que falta e como pedir é a filosofia de gating do app: esconder a aba em
/// silêncio (como Meus Planos fazia antes) quebra o próprio convite de
/// crescimento por WhatsApp que o produto já usa em Conversas.
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
              'Recurso premium',
              style: tema.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DevocionalEspacamento.sp8),
            Text(
              descricao,
              style: tema.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (_numeroWhatsapp.isNotEmpty) ...[
              const SizedBox(height: DevocionalEspacamento.sp24),
              DevocionalBotaoPrimario.icon(
                onPressed: () => _abrirWhatsapp(mensagemDoWhatsapp),
                icon: const FaIcon(FontAwesomeIcons.whatsapp),
                label: const Text('Falar no WhatsApp'),
              ),
            ],
          ],
        ),
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
