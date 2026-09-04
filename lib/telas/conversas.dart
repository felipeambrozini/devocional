import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/nuvem.dart';
import '../data/personas.dart';
import '../data/recursos.dart';
import '../estilo/spacing.dart';
import '../widgets/widgets.dart';

/// Número que recebe o pedido de acesso pelo WhatsApp, para quem ainda não
/// está na allowlist (ver [Recursos.conversas]). Mesmo padrão de
/// `--dart-define` do `_emailDeContato` em `sobre.dart`: sem número
/// versionado no repositório, e vazio esconde o botão.
const _numeroWhatsapp = String.fromEnvironment('WHATSAPP_NUMERO');

/// A aba Conversas: a porta de entrada do chat no celular e no computador.
///
/// A aba fica visível para todo mundo — só o conteúdo muda com
/// [Recursos.conversas]: quem está na allowlist vê a carta de cada persona
/// (o mesmo caminho que os balões das telas largas empurram, ver `_ComBaloes`
/// em `main.dart`); quem não está vê o convite para pedir acesso pelo
/// WhatsApp, porque cada conversa chama a API paga do Gemini.
class TelaConversas extends StatelessWidget {
  const TelaConversas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversas')),
      body: LarguraDeLeitura(
        // Recursos.conversas depende do e-mail logado (ver Nuvem): sem
        // ouvir a nuvem, entrar ou sair da conta com a aba aberta deixava o
        // conteúdo errado até trocar de aba e voltar.
        child: ListenableBuilder(
          listenable: Nuvem.instancia,
          builder: (context, _) => Recursos.conversas
              ? const _CartasDeConversa()
              : const _PedirAcesso(),
        ),
      ),
    );
  }
}

class _CartasDeConversa extends StatelessWidget {
  const _CartasDeConversa();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return ListView(
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
    );
  }
}

/// Convite para pedir acesso, para quem abre a aba sem estar na allowlist.
/// O botão do WhatsApp some se [_numeroWhatsapp] não estiver configurado —
/// mesma regra do `_emailDeContato` em `sobre.dart`.
class _PedirAcesso extends StatelessWidget {
  const _PedirAcesso();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.sp24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: cor.primary),
            const SizedBox(height: Spacing.sp16),
            Text(
              'Conversas ainda em teste',
              style: tema.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sp8),
            Text(
              'O chat com Spurgeon e com Felipe está sendo liberado aos '
              'poucos, porque cada conversa usa uma API paga. Fale comigo '
              'pelo WhatsApp para habilitar o acesso na sua conta.',
              style: tema.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (_numeroWhatsapp.isNotEmpty) ...[
              const SizedBox(height: Spacing.sp24),
              FilledButton.icon(
                onPressed: _abrirWhatsapp,
                icon: const FaIcon(FontAwesomeIcons.whatsapp),
                label: const Text('Falar no WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Abre o WhatsApp já com a mensagem de pedido de acesso preenchida, para
/// quem tocou o botão em [_PedirAcesso] não precisar digitá-la.
Future<void> _abrirWhatsapp() async {
  final uri = Uri.https('wa.me', '/$_numeroWhatsapp', {
    'text': 'Oi Felipe, quero habilitar as conversas',
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
