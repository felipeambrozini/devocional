import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/modelos.dart';
import '../estilo/spacing.dart';

/// Uma linha por versículo-base de um devocional: a citação entre aspas seguida
/// da referência em caixa alta.
///
/// A maioria dos dias tem um só versículo-base. O raro dia cuja epígrafe
/// encadeia mais de um, como o de 12 de julho (Judas 1:1, 1 Coríntios 1:2, 1
/// Pedro 1:2), mostra uma linha para cada, na ordem em que aparecem no
/// devocional original.
///
/// Com [aoAbrirReferencia], a referência que o canon resolve vira alvo de
/// toque e devolve livro, capítulo e faixa de versículos já resolvidos — é a
/// porta do devocional para o texto da BKJ. Referência que o canon não
/// reconhece segue como texto morto, sem prometer o que não cumpre. O toque
/// fica com quem chama (a navegação é de cada tela); aqui só se resolve o
/// alvo, porque `biblia.dart` importa este arquivo e o contrário seria ciclo.
List<InlineSpan> spansDeCitacao(
  Devocional dev, {
  required TextStyle? estiloCitacao,
  required TextStyle? estiloReferencia,
  void Function(Livro livro, int capitulo, int deVersiculo, int ateVersiculo)?
  aoAbrirReferencia,
}) {
  final pares = dev.paresDeVersiculos;
  final spans = <InlineSpan>[];
  for (final (referencia, versiculo) in pares) {
    if (referencia.isEmpty && versiculo.isEmpty) continue;
    if (spans.isNotEmpty) spans.add(const TextSpan(text: '\n'));
    if (versiculo.isNotEmpty) {
      spans.add(TextSpan(text: '"$versiculo" ', style: estiloCitacao));
    }
    if (referencia.isNotEmpty) {
      final faixa = aoAbrirReferencia == null
          ? null
          : faixasDaReferencia(referencia).firstOrNull;
      if (faixa == null || aoAbrirReferencia == null) {
        spans.add(
          TextSpan(text: referencia.toUpperCase(), style: estiloReferencia),
        );
      } else {
        final abrir = aoAbrirReferencia;
        // WidgetSpan, e não recognizer no TextSpan: dentro do SelectionArea
        // do devocional o recognizer não recebe o toque; um filho com gesto
        // próprio vence a disputa e preserva a seleção no resto do texto.
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _ReferenciaDaCitacao(
              rotulo: referencia.toUpperCase(),
              estilo: estiloReferencia,
              aoAbrir: () => abrir(faixa.$1, faixa.$2, faixa.$3, faixa.$4),
            ),
          ),
        );
      }
    }
  }
  return spans;
}

/// A citação de [spansDeCitacao] em texto puro, uma linha por versículo-base
/// na mesma ordem. Usada no texto de Compartilhar do devocional, que não tem
/// widget nem contexto de toque para os spans.
String textoDeCitacao(Devocional dev) => [
  for (final (referencia, versiculo) in dev.paresDeVersiculos)
    if (referencia.isNotEmpty || versiculo.isNotEmpty)
      [
        if (versiculo.isNotEmpty) '"$versiculo"',
        if (referencia.isNotEmpty) referencia.toUpperCase(),
      ].join(' '),
].join('\n');

/// O alvo de toque da referência da epígrafe. Visual idêntico ao texto morto
/// em repouso; a diferença mora no cursor clicável, no ripple contido e na
/// semântica de botão para leitor de tela.
class _ReferenciaDaCitacao extends StatelessWidget {
  const _ReferenciaDaCitacao({
    required this.rotulo,
    required this.estilo,
    required this.aoAbrir,
  });

  final String rotulo;
  final TextStyle? estilo;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir $rotulo na Bíblia',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: aoAbrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sp2),
          child: Text(rotulo, style: estilo),
        ),
      ),
    );
  }
}
