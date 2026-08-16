import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/nuvem.dart';
import 'comuns.dart';

/// Créditos das traduções, da fonte dos devocionais e o link dos canais.
class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: LarguraDeLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text('Devocional', style: tema.displayMedium),
            const SizedBox(height: 8),
            const Filete(largura: 64),
            const SizedBox(height: 24),
            Text('Fontes do texto', style: tema.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Este aplicativo utiliza uma tradução autoral e inédita da '
              'King James 1611, elaborada diretamente do texto '
              'inglês em domínio público. Também reúne traduções próprias '
              'dos devocionais clássicos de Charles H. Spurgeon, Morning '
              'and Evening e Faith\'s Checkbook. O texto busca conservar '
              'fidelidade teológica, reverência literária e rigor no respeito '
              'aos direitos autorais.',
              style: tema.bodyLarge?.copyWith(height: 1.7),
            ),
            const SizedBox(height: 32),
            Text('Onde me encontrar', style: tema.headlineSmall),
            const SizedBox(height: 10),
            _LinkDeCanal(
              asset: 'assets/images/youtube.webp',
              rotulo: 'YouTube',
              url: 'https://www.youtube.com/@felipe_ambrozini',
            ),
            _LinkDeCanal(
              asset: 'assets/images/instagram.webp',
              rotulo: 'Instagram',
              url: 'https://www.instagram.com/felipe_ambrozini/',
            ),
            // Só na web: é onde existe conta na nuvem (ver nuvem.dart).
            if (nuvemSuportada) ...[
              const SizedBox(height: 32),
              Text('Conta e privacidade', style: tema.headlineSmall),
              const SizedBox(height: 10),
              Text(
                'Quem entra com a conta Google salva favoritos, anotações e '
                'dias de leitura marcados numa conta na nuvem, para não '
                'perdê-los se o navegador limpar o armazenamento. Sobem só '
                'esses três itens, mais o e-mail e o identificador da conta '
                '— nunca o que você lê, nem quando lê; o tamanho da letra e '
                'o tema continuam só no aparelho. Quem não entra usa o app '
                'do mesmo jeito de sempre, sem nada saindo daqui.',
                style: tema.bodyLarge?.copyWith(height: 1.7),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: Nuvem.instancia,
                builder: (context, _) => Nuvem.instancia.logado
                    ? ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline, color: cor.error),
                        title: const Text('Apagar meus dados da nuvem'),
                        subtitle: const Text(
                          'Remove a cópia salva na conta. O que está neste '
                          'navegador não é tocado.',
                        ),
                        onTap: () => _apagarDaNuvem(context),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirma e apaga a cópia da conta. O "não pode ser desfeita" é literal:
/// `Nuvem.apagarDados` remove o documento no Firestore e a conta em si.
Future<void> _apagarDaNuvem(BuildContext context) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Apagar dados da nuvem?'),
      content: const Text(
        'Favoritos, anotações e progresso salvos na sua conta serão '
        'apagados. O que está neste navegador continua intacto. Essa ação '
        'não pode ser desfeita.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Apagar'),
        ),
      ],
    ),
  );
  if (confirmou != true || !context.mounted) return;

  final mensageiro = ScaffoldMessenger.of(context);
  try {
    await Nuvem.instancia.apagarDados();
    mensageiro.showSnackBar(
      const SnackBar(content: Text('Dados apagados da nuvem.')),
    );
  } catch (_) {
    mensageiro.showSnackBar(
      const SnackBar(
        content: Text('Não foi possível apagar agora. Tente de novo.'),
      ),
    );
  }
}

class _LinkDeCanal extends StatelessWidget {
  const _LinkDeCanal({
    required this.asset,
    required this.rotulo,
    required this.url,
  });

  final String asset;
  final String rotulo;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Image.asset(
        asset,
        // O logo oficial da marca, como o "G" do Google: não redesenhado.
        width: 26,
        height: 26,
      ),
      title: Text(rotulo),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
