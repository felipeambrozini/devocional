import '../canon.dart';

class Capitulo {
  const Capitulo({
    required this.livro,
    required this.numero,
    required this.titulo,
    required this.versiculos,
    String? nome,
    this.falasDivinas = const {},
  }) : nome = nome ?? '';

  final String livro;
  final int numero;

  /// O nome do livro como vem no JSON (`nome`). Vazio quando o arquivo não o
  /// traz; nesse caso a referência cai no nome do canon, que é o mesmo.
  final String nome;

  /// Sobrescrito do salmo, por exemplo "Ao Músico-chefe, Salmo de Davi.".
  /// Vazio na maioria dos capítulos.
  final String titulo;

  /// Pares (número, texto) na ordem numérica.
  final List<(int, String)> versiculos;

  /// Por versículo, os trechos `(início, fim)` do texto em que fala Deus Pai,
  /// Jesus ou o Espírito Santo, para a letra vermelha. Versículo sem fala
  /// divina não aparece. Ver `tools/falas_divinas/gerar.py`.
  final Map<int, List<(int, int)>> falasDivinas;

  /// Salmos é o único livro em que cada capítulo é um poema autônomo, então
  /// a referência usa o singular ("Salmo 23"), diferente do seletor de
  /// livro, que continua no plural ("Salmos").
  String get referencia =>
      '${livro == 'salmos' ? 'Salmo' : (nome.isNotEmpty ? nome : nomeDoLivro(livro))} $numero';
}

/// O texto de um versículo em pedaços, cada um marcado se é fala divina.
///
/// Os trechos vêm de um asset gerado à parte do texto; se algum dia o texto
/// mudar e um índice passar do fim, o trecho é aparado em vez de lançar, e o
/// pior caso é um pedaço sem vermelho, nunca o versículo sumindo.
List<(String, bool)> partesDoVersiculo(String texto, List<(int, int)> trechos) {
  final partes = <(String, bool)>[];
  var cursor = 0;
  for (final (inicio, fim) in trechos) {
    final a = inicio.clamp(cursor, texto.length);
    final b = fim.clamp(a, texto.length);
    if (a > cursor) partes.add((texto.substring(cursor, a), false));
    if (b > a) partes.add((texto.substring(a, b), true));
    cursor = b;
  }
  if (cursor < texto.length) partes.add((texto.substring(cursor), false));
  return partes;
}

/// Introdução de um livro, na voz de Spurgeon.
class Introducao {
  const Introducao({
    required this.livro,
    required this.secoes,
    required this.frase,
    required this.fraseComprovada,
    required this.fonteDaFrase,
  });

  factory Introducao.doJson(Map<String, dynamic> json) => Introducao(
    livro: json['book'] as String,
    secoes: [
      for (final s in json['sections'] as List)
        (s['heading'] as String, s['body'] as String),
    ],
    frase: json['quote'] as String? ?? '',
    fraseComprovada: json['quoteAttributed'] as bool? ?? false,
    fonteDaFrase: json['quoteSource'] as String? ?? '',
  );

  final String livro;
  final List<(String, String)> secoes;
  final String frase;

  /// Só exibimos a frase como citação de Spurgeon quando ela é comprovada e tem
  /// fonte. Sem isso, uma linha composta na voz dele passaria por citação real.
  final bool fraseComprovada;
  final String fonteDaFrase;

  /// A linha de crédito embaixo da frase.
  ///
  /// Fica no modelo, e não nas telas, porque é regra de correção e não de layout:
  /// rotular como citação de Spurgeon uma frase sem fonte comprovada seria atribuir
  /// a uma pessoa real palavras que ela não escreveu. Estava duplicada palavra por
  /// palavra em duas telas, onde uma correção num lugar não chegava ao outro.
  /// O `trim` importa: fonte só com espaços não é fonte, e sem ele a linha sairia
  /// como "Charles H. Spurgeon," com a vírgula solta e obra nenhuma. É a mesma
  /// checagem que a validação dos assets já faz.
  String get atribuicao => fraseComprovada && fonteDaFrase.trim().isNotEmpty
      ? 'Charles H. Spurgeon, ${fonteDaFrase.trim()}'
      : 'Escrito na voz de Spurgeon; sem citação comprovada';
}
