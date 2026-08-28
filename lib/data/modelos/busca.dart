import '../canon.dart';

/// Um resultado de busca.
class Achado {
  const Achado({
    required this.livro,
    required this.capitulo,
    required this.versiculo,
    required this.texto,
  });

  final String livro;
  final int capitulo;
  final int versiculo;
  final String texto;

  String get referencia => '${nomeDoLivro(livro)} $capitulo:$versiculo';
}

/// Um resultado de busca nos devocionais (Manhã, Noite ou Promessas de Deus).
///
/// [leitura] é uma string ("manha"/"noite"/"promessas"), não o enum `Leitura`
/// de `lib/telas/devocional.dart`: `data/` não importa `telas/`, mesma ponte
/// que `Lembretes` já usa em `lib/data/lembretes.dart`. Quem navega faz
/// `Leitura.values.byName(leitura)`.
class AchadoDevocional {
  const AchadoDevocional({
    required this.leitura,
    required this.data,
    required this.titulo,
    required this.texto,
  });

  final String leitura;

  /// Chave 'DD-MM', mesma convenção de [DiaDoPlano.data]: os devocionais são
  /// anuais e não guardam ano.
  final String data;

  final String titulo;
  final String texto;
}
