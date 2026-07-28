import 'canon.dart';

/// Um capítulo carregado: o sobrescrito (existe nos Salmos) e os versículos em ordem.
class Capitulo {
  const Capitulo({
    required this.livro,
    required this.numero,
    required this.titulo,
    required this.versiculos,
  });

  final String livro;
  final int numero;

  /// Sobrescrito do salmo, por exemplo "Ao Músico-chefe, Salmo de Davi.".
  /// Vazio na maioria dos capítulos.
  final String titulo;

  /// Pares (número, texto) na ordem numérica.
  final List<(int, String)> versiculos;

  String get referencia => '${nomeDoLivro(livro)} $numero';
}

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
  const DiaDoPlano({required this.data, required this.rotulo, required this.faixas});

  factory DiaDoPlano.doJson(Map<String, dynamic> json) => DiaDoPlano(
        data: json['date'] as String,
        rotulo: json['label'] as String,
        faixas: [
          for (final f in json['ranges'] as List) Faixa.doJson(f as Map<String, dynamic>),
        ],
      );

  /// Chave 'MM-DD'. O plano é anual e se repete, então não guarda ano.
  final String data;

  /// O texto original do cronograma, por exemplo "Tiago 4 a 5, Gálatas 1".
  final String rotulo;

  final List<Faixa> faixas;

  int get mes => int.parse(data.substring(0, 2));
  int get dia => int.parse(data.substring(3, 5));
}

/// Uma das duas leituras diárias de Manhã e Noite.
class Devocional {
  const Devocional({required this.referencia, required this.texto});

  factory Devocional.doJson(Map<String, dynamic> json) => Devocional(
        referencia: json['reference'] as String? ?? '',
        texto: json['text'] as String? ?? '',
      );

  final String referencia;
  final String texto;
}

enum Periodo {
  manha('manha', 'Manhã'),
  noite('noite', 'Noite');

  const Periodo(this.chave, this.nome);

  final String chave;
  final String nome;

  /// O app abre no período conforme o relógio: a virada às 18h é o que separa
  /// a leitura da manhã da leitura da noite.
  static Periodo pelaHora(int hora) => hora < 18 ? Periodo.manha : Periodo.noite;
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
}

/// Um versículo marcado como favorito, com nota opcional.
class Marcacao {
  const Marcacao({
    required this.versao,
    required this.livro,
    required this.capitulo,
    required this.versiculo,
    this.nota = '',
  });

  factory Marcacao.doJson(Map<String, dynamic> json) => Marcacao(
        versao: Versao.values.firstWhere(
          (v) => v.pasta == json['versao'],
          orElse: () => Versao.bkj,
        ),
        livro: json['livro'] as String,
        capitulo: json['capitulo'] as int,
        versiculo: json['versiculo'] as int,
        nota: json['nota'] as String? ?? '',
      );

  final Versao versao;
  final String livro;
  final int capitulo;
  final int versiculo;
  final String nota;

  /// Identidade estável usada como chave de armazenamento.
  String get chave => '${versao.pasta}/$livro/$capitulo/$versiculo';

  String get referencia => '${nomeDoLivro(livro)} $capitulo:$versiculo';

  Map<String, dynamic> paraJson() => {
        'versao': versao.pasta,
        'livro': livro,
        'capitulo': capitulo,
        'versiculo': versiculo,
        'nota': nota,
      };

  Marcacao comNota(String novaNota) => Marcacao(
        versao: versao,
        livro: livro,
        capitulo: capitulo,
        versiculo: versiculo,
        nota: novaNota,
      );
}

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
