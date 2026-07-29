import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'comuns.dart';

/// Introdução de um livro, na voz de Spurgeon.
class TelaIntroducao extends StatelessWidget {
  const TelaIntroducao({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(nomeDoLivro(slug))),
      body: FutureBuilder<Introducao?>(
        future: Conteudo.instancia.introducao(slug),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final intro = snap.data;
          if (intro == null) {
            return AvisoVazio(
              icone: Icons.article_outlined,
              titulo: 'Introdução ainda não escrita',
              detalhe: 'A introdução de ${nomeDoLivro(slug)} entra em '
                  'assets/intro/$slug.json.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/capa_biblia_spurgeon.png',
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(intro.livro, style: tema.displayMedium),
                        const SizedBox(height: 8),
                        Text('Introdução', style: tema.titleSmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Filete(largura: 64),
              const SizedBox(height: 24),
              for (final (titulo, corpo) in intro.secoes) ...[
                Text(titulo, style: tema.headlineSmall),
                const SizedBox(height: 10),
                // Os parágrafos vêm separados por linha em branco no JSON.
                for (final paragrafo in corpo.split('\n\n')) ...[
                  Text(paragrafo, style: tema.bodyLarge?.copyWith(height: 1.7)),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
              ],
              if (intro.frase.isNotEmpty) _Frase(intro: intro),
            ],
          );
        },
      ),
    );
  }
}

class _Frase extends StatelessWidget {
  const _Frase({required this.intro});

  final Introducao intro;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: Cores.dourado, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${intro.frase}"',
            style: tema.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.65,
              color: Cores.douradoClaro,
            ),
          ),
          const SizedBox(height: 12),
          Text(intro.atribuicao, style: tema.labelMedium),
        ],
      ),
    );
  }
}
