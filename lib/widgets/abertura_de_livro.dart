import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/modelos.dart';
import '../data/voz.dart';
import '../funcoes/capa_biblia.dart';
import '../estilo/spacing.dart';
import 'area_de_selecao.dart';
import 'botao_de_voz.dart';
import 'carrega_uma_vez.dart';
import 'filete.dart';

/// Abertura de um livro: a introdução de Spurgeon, recolhida por padrão.
///
/// Recolhida porque o texto é longo e quem já leu a introdução quer chegar ao
/// texto sem rolar páginas. Expandida, lê inteira ali mesmo. Aparece tanto no
/// leitor da Bíblia quanto no devocional, por isso vive aqui e não numa tela só.
class AberturaDeLivro extends StatefulWidget {
  const AberturaDeLivro({super.key, required this.slug});

  final String slug;

  @override
  State<AberturaDeLivro> createState() => _AberturaDeLivroState();
}

class _AberturaDeLivroState extends State<AberturaDeLivro> {
  bool _aberta = false;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;

    return CarregaUmaVez<Introducao?>(
      chave: widget.slug,
      carregar: () => Conteudo.instancia.introducao(widget.slug),
      construir: (context, snap) {
        final introducao = snap.data;
        // Sem introdução escrita, nada é mostrado: o texto começa direto.
        if (introducao == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sp24),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _aberta = !_aberta),
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.sp16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.asset(
                            capaBibliaSpurgeon(context),
                            height: alturaCapa(context, 104),
                            fit: BoxFit.cover,
                            // Decorativa: o título ao lado já nomeia a obra.
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(width: Spacing.sp14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tituloDaIntroducao(livroPorSlug(widget.slug)!),
                                style: tema.titleLarge,
                              ),
                              const SizedBox(height: Spacing.sp4),
                              Text(
                                'Bíblia de Estudo Charles Haddon Spurgeon',
                                style: tema.labelMedium,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _aberta ? Icons.expand_less : Icons.expand_more,
                          color: cor.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_aberta)
                  _IntroducaoAberta(slug: widget.slug, introducao: introducao),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// O corpo aberto do cartão de abertura: voz, seções e frase final, com o
/// texto selecionável para copiar. Se já há uma área de seleção acima (o
/// leitor da Bíblia no toque, o devocional), ela é reaproveitada — aninhar
/// outra aqui truncaria a seleção que cruza a borda do cartão. Na web não há
/// área acima: o leitor abre mão da seleção no mouse porque o arrasto disputa
/// com o deslize de capítulo, então o corpo carrega a própria
/// [AreaDeSelecaoComCompartilhar].
class _IntroducaoAberta extends StatelessWidget {
  const _IntroducaoAberta({required this.slug, required this.introducao});

  final String slug;
  final Introducao introducao;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final dentroDeAreaDeSelecao = SelectionContainer.maybeOf(context) != null;

    final conteudo = Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sp16,
        0,
        Spacing.sp16,
        Spacing.sp16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Filete(),
          const SizedBox(height: Spacing.sp16),
          // A voz de Spurgeon lê a introdução inteira, do título à frase;
          // tocar de novo para a leitura.
          BotaoDeVoz(
            chave: chaveDaIntroducao(slug),
            referencia: 'Introdução de ${introducao.livro}',
          ),
          const SizedBox(height: Spacing.sp16),
          for (final (titulo, corpo) in introducao.secoes) ...[
            Text(titulo, style: tema.headlineSmall),
            const SizedBox(height: Spacing.sp8),
            for (final paragrafo in corpo.split('\n\n')) ...[
              Text(paragrafo, style: tema.bodyMedium?.copyWith(height: 1.7)),
              const SizedBox(height: Spacing.sp10),
            ],
            const SizedBox(height: Spacing.sp12),
          ],
          if (introducao.frase.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.sp14),
              decoration: BoxDecoration(
                color: cor.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: cor.primary, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${introducao.frase}"',
                    style: tema.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: cor.secondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: Spacing.sp8),
                  Text(introducao.atribuicao, style: tema.labelMedium),
                ],
              ),
            ),
        ],
      ),
    );

    if (dentroDeAreaDeSelecao) return conteudo;
    return AreaDeSelecaoComCompartilhar(child: conteudo);
  }
}
