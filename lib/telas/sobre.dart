import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'comuns.dart';

/// Créditos das traduções, da fonte dos devocionais e o link dos canais.
class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
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
              'Bíblia King James 1611 em português e Nova Versão '
              'Transformadora (NVT), Editora Mundo Cristão. Devocionais na '
              'voz de Charles Spurgeon (Morning and Evening, Faith\'s '
              'Checkbook), domínio público, com título, comentário e '
              'Promessas de Deus traduzidos para este app.',
              style: tema.bodyLarge?.copyWith(height: 1.7),
            ),
            const SizedBox(height: 32),
            Text('Onde me encontrar', style: tema.headlineSmall),
            const SizedBox(height: 10),
            _LinkDeCanal(
              icone: Icons.smart_display_outlined,
              rotulo: 'YouTube',
              url: 'https://www.youtube.com/@felipe_ambrozini',
            ),
            _LinkDeCanal(
              icone: Icons.camera_alt_outlined,
              rotulo: 'Instagram',
              url: 'https://www.instagram.com/felipe_ambrozini/',
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkDeCanal extends StatelessWidget {
  const _LinkDeCanal({
    required this.icone,
    required this.rotulo,
    required this.url,
  });

  final IconData icone;
  final String rotulo;
  final String url;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone, color: cor.primary),
      title: Text(rotulo),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
