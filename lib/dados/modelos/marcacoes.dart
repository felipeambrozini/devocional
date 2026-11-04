import '../canon.dart';
import '../carimbo.dart';

class Marcacao {
  const Marcacao({
    required this.livro,
    required this.capitulo,
    required this.versiculo,
    this.nota = '',
    this.em = 0,
  });

  factory Marcacao.doJson(Map<String, dynamic> json) => Marcacao(
    livro: json['livro'] as String,
    capitulo: json['capitulo'] as int,
    versiculo: json['versiculo'] as int,
    nota: json['nota'] as String? ?? '',
    em: limitarCarimboNoFuturo(json['em'] as int? ?? 0),
  );

  final String livro;
  final int capitulo;
  final int versiculo;
  final String nota;

  /// Milissegundos desde a época em que a nota foi criada ou editada; 0 quando
  /// não se sabe (marcação sem nota ou gravada por versão antiga). Decide qual
  /// nota vence ao importar uma cópia.
  final int em;

  /// Identidade estável usada como chave de armazenamento.
  String get chave => '$livro/$capitulo/$versiculo';

  String get referencia => '${nomeNaReferencia(livro)} $capitulo:$versiculo';

  Map<String, dynamic> paraJson() => {
    'livro': livro,
    'capitulo': capitulo,
    'versiculo': versiculo,
    'nota': nota,
    if (em > 0) 'em': em,
  };

  Marcacao comNota(String novaNota, {int em = 0}) => Marcacao(
    livro: livro,
    capitulo: capitulo,
    versiculo: versiculo,
    nota: novaNota,
    em: em,
  );
}
