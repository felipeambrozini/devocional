import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/instalacao.dart';
import '../dados/registro.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import 'botao.dart';
import 'filete.dart';

/// "Instalar como app" em Sobre: só na web, e só fora do app instalado.
///
/// Com o convite do navegador (Chrome, Edge), o toque abre a janela de
/// instalação dele. Sem convite (Safari no iPhone e no Mac, Firefox, ou o
/// Chrome ainda não mandou), abre um diálogo com o caminho pelo menu para o
/// sistema em que a pessoa está.
class DevocionalItemDeInstalar extends StatelessWidget {
  const DevocionalItemDeInstalar({super.key, this.instalacao});

  /// Nulo usa [InstalacaoDoApp.instancia]; os testes passam uma falsa.
  final InstalacaoDoApp? instalacao;

  @override
  Widget build(BuildContext context) {
    final instalacao = this.instalacao ?? InstalacaoDoApp.instancia;
    final cor = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: instalacao,
      builder: (context, _) {
        if (!instalacao.disponivel) return const SizedBox.shrink();
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: FaIcon(FontAwesomeIcons.mobileScreen, color: cor.primary),
          title: const Text('Instalar como app'),
          subtitle: const Text(
            'Abre em janela própria, com ícone como os outros apps, sem '
            'passar por loja.',
          ),
          onTap: () => instalarComoApp(context, instalacao),
        );
      },
    );
  }
}

/// O toque em "Instalar": a janela do navegador, se ele mandou convite;
/// senão (ou se ela falhar), os passos pelo menu. Usado pelo item de Sobre
/// e pelo cartão da Hoje.
Future<void> instalarComoApp(
  BuildContext context,
  InstalacaoDoApp instalacao,
) async {
  if (!instalacao.temConviteDoNavegador) {
    return _mostrarPassos(context);
  }
  final mensageiro = ScaffoldMessenger.of(context);
  try {
    final aceitou = await instalacao.pedir();
    if (aceitou) mostrarAvisoNo(mensageiro, 'Devocional instalado.');
  } catch (erro, pilha) {
    // A janela do navegador não abriu: o toque não pode ficar sem resposta,
    // então cai no caminho pelo menu, que funciona igual.
    Registro.erro('Instalacao.pedir', erro, pilha);
    if (context.mounted) await _mostrarPassos(context);
  }
}

/// O caminho pelo menu do navegador em cada sistema. Na web,
/// [defaultTargetPlatform] é o sistema do aparelho (o Flutter tira do
/// navegador), não "web".
List<String> passosParaInstalar(TargetPlatform plataforma) =>
    switch (plataforma) {
      TargetPlatform.iOS => const [
        '1. Toque em Compartilhar (o quadrado com a seta para cima). Se ele '
            'não estiver na barra do navegador, fica no botão de três '
            'pontinhos. Vale no Safari, no Chrome e no Edge.',
        '2. Role as opções e toque em Adicionar à Tela de Início.',
        '3. Toque em Adicionar. O Devocional aparece entre os seus apps.',
        '4. Para receber os lembretes, abra o Devocional pelo ícone novo, '
            'toque no botão de ajustes dele (os controles deslizantes, no '
            'alto da tela) e ligue os lembretes. No iPhone, eles só chegam '
            'assim.',
      ],
      TargetPlatform.android => const [
        '1. Abra o menu do navegador (os três pontinhos no canto).',
        '2. Toque em Instalar app ou Adicionar à tela inicial.',
        '3. Confirme. O Devocional aparece entre os seus apps.',
      ],
      TargetPlatform.macOS => const [
        'No Chrome ou no Edge, clique no ícone de instalar no fim da barra '
            'de endereço, ou procure Instalar Devocional no menu do '
            'navegador.',
        'No Safari, abra o menu Arquivo e escolha Adicionar ao Dock.',
      ],
      _ => const [
        'No Chrome ou no Edge, clique no ícone de instalar no fim da barra '
            'de endereço, ou procure Instalar Devocional no menu do '
            'navegador.',
        'O Firefox no computador não instala sites como app.',
      ],
    };

Future<void> _mostrarPassos(BuildContext context) {
  final tema = Theme.of(context).textTheme;
  final passos = passosParaInstalar(defaultTargetPlatform);
  return showDialog<void>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text('Instalar como app', style: tema.headlineSmall),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DevocionalFilete(largura: 64),
            const SizedBox(height: DevocionalEspacamento.sp12),
            for (final passo in passos) ...[
              Text(passo, style: tema.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: DevocionalEspacamento.sp8),
            ],
          ],
        ),
      ),
      actions: [
        DevocionalBotaoTerciario(
          onPressed: () => Navigator.pop(dialogo),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
