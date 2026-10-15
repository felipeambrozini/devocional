/// Um livro de Spurgeon da biblioteca. Distinto do `Livro` do canon (os 66
/// livros da Bíblia): aqui é uma obra traduzida, lida por capítulo.
class ObraDaBiblioteca {
  const ObraDaBiblioteca({
    required this.slug,
    required this.titulo,
    required this.subtitulo,
    required this.capa,
  });

  /// Nome do arquivo em `assets/livros/` e trecho da URL.
  final String slug;
  final String titulo;
  final String subtitulo;

  /// Caminho da capa em `assets/imagens/` (WebP, 225x300, como as outras). Sem
  /// o arquivo ainda, a capa tipográfica ocupa o lugar.
  final String capa;
}

class CapituloDoLivro {
  const CapituloDoLivro({required this.titulo, required this.paragrafos});

  factory CapituloDoLivro.doJson(Map<String, dynamic> json) => CapituloDoLivro(
    titulo: json['titulo'] as String,
    paragrafos: [for (final p in json['paragrafos'] as List) p as String],
  );

  final String titulo;
  final List<String> paragrafos;
}

/// Onde a leitura de um livro parou: o capítulo (a partir de 0) e quanto dele
/// já foi rolado, de 0 a 1. Fração e não parágrafo porque o tamanho da letra
/// muda a altura do texto, e a fração continua apontando para o mesmo ponto.
///
/// [em] é o momento do registro (milissegundos desde 1970): ordena os livros em
/// leitura e decide, na fusão com a nuvem, qual aparelho leu por último.
class PosicaoNoLivro {
  const PosicaoNoLivro({
    required this.capitulo,
    required this.fracao,
    this.em = 0,
  });

  factory PosicaoNoLivro.doJson(Map<String, dynamic> json) => PosicaoNoLivro(
    capitulo: json['capitulo'] as int,
    fracao: (json['fracao'] as num).toDouble().clamp(0.0, 1.0),
    em: json['em'] as int? ?? 0,
  );

  final int capitulo;
  final double fracao;
  final int em;

  Map<String, dynamic> paraJson() => {
    'capitulo': capitulo,
    'fracao': fracao,
    'em': em,
  };
}

/// Parágrafo grifado pelo usuário, com nota opcional. Por parágrafo inteiro:
/// grifar um trecho exato pediria posições dentro do texto, que o tamanho da
/// letra e as correções de tradução deslocariam.
class DestaqueDeLivro {
  const DestaqueDeLivro({
    required this.slug,
    required this.capitulo,
    required this.paragrafo,
    this.nota = '',
    this.em = 0,
  });

  factory DestaqueDeLivro.doJson(Map<String, dynamic> json) => DestaqueDeLivro(
    slug: json['slug'] as String,
    capitulo: json['capitulo'] as int,
    paragrafo: json['paragrafo'] as int,
    nota: json['nota'] as String? ?? '',
    em: json['em'] as int? ?? 0,
  );

  final String slug;
  final int capitulo;
  final int paragrafo;
  final String nota;

  /// Momento da última mudança, para a fusão com a nuvem ficar com o mais novo.
  final int em;

  /// Identidade estável usada como chave de armazenamento.
  String get chave => '$slug/$capitulo/$paragrafo';

  Map<String, dynamic> paraJson() => {
    'slug': slug,
    'capitulo': capitulo,
    'paragrafo': paragrafo,
    'nota': nota,
    'em': em,
  };

  DestaqueDeLivro comNota(String novaNota, int novoEm) => DestaqueDeLivro(
    slug: slug,
    capitulo: capitulo,
    paragrafo: paragrafo,
    nota: novaNota,
    em: novoEm,
  );
}
