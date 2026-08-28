import '../canon.dart';

/// Uma faixa do cronograma: capítulos, ou versículos dentro de um capítulo quando o
/// dia pede algo como "Salmos 119:1 a 56".
class Faixa {
  const Faixa({
    required this.livro,
    required this.deCapitulo,
    required this.ateCapitulo,
    this.deVersiculo,
    this.ateVersiculo,
  });

  factory Faixa.doJson(Map<String, dynamic> json) => Faixa(
    livro: json['book'] as String,
    deCapitulo: json['fromChapter'] as int,
    ateCapitulo: json['toChapter'] as int,
    deVersiculo: json['fromVerse'] as int?,
    ateVersiculo: json['toVerse'] as int?,
  );

  final String livro;
  final int deCapitulo;
  final int ateCapitulo;
  final int? deVersiculo;
  final int? ateVersiculo;

  bool get porVersiculo => deVersiculo != null && ateVersiculo != null;

  /// Todos os capítulos que a faixa cobre, para montar a lista de leitura do dia.
  Iterable<int> get capitulos =>
      Iterable.generate(ateCapitulo - deCapitulo + 1, (i) => deCapitulo + i);

  String get rotulo {
    final nome = nomeDoLivro(livro);
    if (porVersiculo) return '$nome $deCapitulo:$deVersiculo-$ateVersiculo';
    if (deCapitulo == ateCapitulo) return '$nome $deCapitulo';
    return '$nome $deCapitulo-$ateCapitulo';
  }
}

/// Um dia do cronograma anual.
class DiaDoPlano {
  const DiaDoPlano({
    required this.data,
    required this.rotulo,
    required this.faixas,
  });

  factory DiaDoPlano.doJson(Map<String, dynamic> json) => DiaDoPlano(
    data: json['date'] as String,
    rotulo: json['label'] as String,
    faixas: [
      for (final f in json['ranges'] as List)
        Faixa.doJson(f as Map<String, dynamic>),
    ],
  );

  /// Chave 'DD-MM'. O plano é anual e se repete, então não guarda ano.
  final String data;

  /// O texto original do cronograma, por exemplo "Tiago 4 a 5, Gálatas 1".
  final String rotulo;

  final List<Faixa> faixas;

  int get mes => int.parse(data.substring(3, 5));
  int get dia => int.parse(data.substring(0, 2));
}
