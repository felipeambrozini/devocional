import '../canon.dart';

/// Um capítulo carregado: o sobrescrito (existe nos Salmos) e os versículos em ordem.
class Capitulo {
  const Capitulo({
    required this.livro,
    required this.numero,
    required this.titulo,
    required this.versiculos,
    String? nome,
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

  String get referencia =>
      '${nome.isNotEmpty ? nome : nomeDoLivro(livro)} $numero';
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
