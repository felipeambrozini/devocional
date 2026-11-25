import 'package:material_ui/material_ui.dart';

import '../dados/canon.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import 'datas.dart';

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
/// porta do devocional para o texto da King James. Referência que o canon não
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
              rotuloFalado: referencia,
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

/// O texto de Copiar e Compartilhar de um devocional, na ordem em que se lê:
/// o nome da leitura ("Devocional da manhã", "Promessas de Deus"), a data, a
/// epígrafe ([textoDeCitacao]) e o comentário ([comentario], ou o do [dev]),
/// com o [link] que reabre a leitura no fim, como o [textoCitado] da Bíblia.
/// As partes vazias saem, e cada uma fica num parágrafo próprio.
String textoDoDevocional({
  required String nomeDaLeitura,
  required DateTime data,
  required Devocional dev,
  String? comentario,
  String link = '',
}) => [
  '$nomeDaLeitura\n${dataLonga(data)}',
  textoDeCitacao(dev),
  comentario ?? dev.texto,
  link,
].where((parte) => parte.isNotEmpty).join('\n\n');

/// O alvo de toque da referência da epígrafe. Sublinhada para não depender só
/// da cor (a mesma da citação) para parecer clicável; o padding vertical
/// leva o alvo aos 48 dp mínimos.
class _ReferenciaDaCitacao extends StatelessWidget {
  const _ReferenciaDaCitacao({
    required this.rotulo,
    required this.rotuloFalado,
    required this.estilo,
    required this.aoAbrir,
  });

  /// O texto à vista, em caixa alta, como a atribuição de uma epígrafe.
  final String rotulo;

  /// O mesmo em caixa normal, para o leitor de tela: em caixa alta alguns
  /// sintetizadores soletram a palavra como sigla.
  final String rotuloFalado;
  final TextStyle? estilo;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    // Nó próprio (`container`): dentro do WidgetSpan, sem ele o botão fundia
    // no texto da epígrafe, e o leitor de tela anunciava a citação inteira
    // como um botão só, com a referência lida duas vezes. Só o texto visível
    // sai da semântica (ExcludeSemantics nele, não `excludeSemantics` aqui):
    // o InkWell continua informando o toque e o foco, sem o que a referência
    // sumia da ordem de Tab de quem usa leitor de tela com teclado.
    return Semantics(
      container: true,
      button: true,
      label: 'Abrir $rotuloFalado na Bíblia',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: aoAbrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: TabernaculoEspacamento.sp14,
          ),
          child: ExcludeSemantics(
            child: Text(
              rotulo,
              style: estilo?.copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ),
    );
  }
}
