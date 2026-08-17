import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/voz.dart';
import 'comuns.dart';

/// Introdução de um livro, na voz de Spurgeon.
class TelaIntroducao extends StatefulWidget {
  const TelaIntroducao({super.key, required this.slug});

  final String slug;

  @override
  State<TelaIntroducao> createState() => _TelaIntroducaoState();
}

class _TelaIntroducaoState extends State<TelaIntroducao> {
  @override
  void dispose() {
    // Sem o botão de parar à vista, não se deixa o áudio tocando ao fechar
    // a tela: quem ouve a introdução a ouve por inteiro na tela dela.
    Voz.instancia.parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final slug = widget.slug;
    // Em tela estreita os balões de conversa moram embaixo, na base da tela;
    // o fim da lista precisa de folga para a última linha não ficar atrás
    // deles. Em tela larga os balões ficam fora da coluna de leitura.
    final protegerDosBaloes =
        EscopoDoEstado.de(context).baloesVisiveis &&
        MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      appBar: AppBar(title: Text(nomeDoLivro(slug))),
      body: LarguraDeLeitura(
        // CarregaUmaVez e não FutureBuilder: a tela lê o tema, e o tema agora
        // muda quando se troca o tamanho do texto. Com um FutureBuilder cru, cada
        // mudança criaria outro Future e a introdução inteira voltaria ao spinner
        // no meio da leitura.
        child: CarregaUmaVez<Introducao?>(
          chave: slug,
          carregar: () => Conteudo.instancia.introducao(slug),
          construir: (context, snap) {
            if (snap.hasError) return const AvisoDeErro();
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final introducao = snap.data;
            if (introducao == null) {
              return AvisoVazio(
                icone: Icons.article_outlined,
                titulo: 'Introdução ainda não escrita',
                detalhe: 'Ainda não há uma introdução de ${nomeDoLivro(slug)}.',
              );
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                protegerDosBaloes ? folgaDosBaloes : 40,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        capaBibliaSpurgeon(context),
                        height: alturaCapa(context, 160),
                        fit: BoxFit.cover,
                        // Decorativa: o título ao lado já diz de onde o texto vem.
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(introducao.livro, style: tema.displayMedium),
                          const SizedBox(height: 4),
                          Text(
                            livroPorSlug(slug)!.tituloFormal,
                            style: tema.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: cor.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Introdução', style: tema.titleSmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Filete(largura: 64),
                const SizedBox(height: 14),
                // A voz de Spurgeon lê a introdução inteira, do título à
                // frase; tocar de novo para a leitura.
                BotaoDeVoz(
                  chave: 'introducao:$slug',
                  texto: textoDeIntroducao(introducao),
                ),
                const SizedBox(height: 24),
                for (final (titulo, corpo) in introducao.secoes) ...[
                  Text(titulo, style: tema.headlineSmall),
                  const SizedBox(height: 10),
                  // Os parágrafos vêm separados por linha em branco no JSON.
                  for (final paragrafo in corpo.split('\n\n')) ...[
                    Text(
                      paragrafo,
                      style: tema.bodyLarge?.copyWith(height: 1.7),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                ],
                if (introducao.frase.isNotEmpty) _Frase(introducao: introducao),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Frase extends StatelessWidget {
  const _Frase({required this.introducao});

  final Introducao introducao;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cor.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: cor.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${introducao.frase}"',
            style: tema.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.65,
              color: cor.secondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(introducao.atribuicao, style: tema.labelMedium),
        ],
      ),
    );
  }
}
