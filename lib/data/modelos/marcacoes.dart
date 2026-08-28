import '../canon.dart';

/// Um versículo marcado como favorito, com nota opcional.
class Marcacao {
  const Marcacao({
    required this.livro,
    required this.capitulo,
    required this.versiculo,
    this.nota = '',
  });

  factory Marcacao.doJson(Map<String, dynamic> json) => Marcacao(
    livro: json['livro'] as String,
    capitulo: json['capitulo'] as int,
    versiculo: json['versiculo'] as int,
    nota: json['nota'] as String? ?? '',
  );

  final String livro;
  final int capitulo;
  final int versiculo;
  final String nota;

  /// Identidade estável usada como chave de armazenamento.
  String get chave => '$livro/$capitulo/$versiculo';

  String get referencia => '${nomeDoLivro(livro)} $capitulo:$versiculo';

  Map<String, dynamic> paraJson() => {
    'livro': livro,
    'capitulo': capitulo,
    'versiculo': versiculo,
    'nota': nota,
  };

  Marcacao comNota(String novaNota) => Marcacao(
    livro: livro,
    capitulo: capitulo,
    versiculo: versiculo,
    nota: novaNota,
  );
}
