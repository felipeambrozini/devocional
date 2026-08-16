import 'canon.dart';

/// Passos do controle de tamanho do texto de leitura, e o rótulo de cada um.
///
/// Fatores e não pixels: o tema é quem sabe o tamanho base de cada estilo, e
/// assim o versículo, o comentário do devocional e a introdução crescem juntos,
/// na mesma proporção. O menor passo existe porque quem lê numa janela grande
/// às vezes quer caber mais texto na tela, não menos.
///
/// Vivem aqui, e não no tema, porque o [Estado] precisa deles para recusar um
/// valor gravado fora da lista, e o `data` não importa `theme.dart`.
const escalasDeLeitura = <double>[0.9, 1.0, 1.15, 1.3, 1.5];
const rotulosDeEscala = <String>[
  'Pequeno',
  'Padrão',
  'Médio',
  'Grande',
  'Maior',
];

/// Claro, escuro ou o que o aparelho estiver usando.
///
/// Seguir o aparelho é o padrão, mas não pode ser a única opção: às nove da
/// noite o celular pode ainda estar no claro, e quem lê na cama quer o escuro
/// independente disso.
///
/// Vive aqui pelo mesmo motivo das escalas: o [Estado] precisa dele para ler e
/// gravar a preferência, e o `data` não importa `theme.dart` nem `material.dart`.
/// Quem traduz para `ThemeMode` é o `main.dart`.
enum ModoDoTema {
  sistema('sistema', 'Automático'),
  claro('claro', 'Claro'),
  escuro('escuro', 'Escuro');

  const ModoDoTema(this.chave, this.rotulo);

  final String chave;
  final String rotulo;
}

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

/// Uma leitura diária: Manhã, Noite ou a promessa do dia.
class Devocional {
  const Devocional({
    required this.referencia,
    required this.texto,
    this.titulo = '',
    this.versiculo = '',
    this.outrosVersiculos = const [],
  });

  factory Devocional.doJson(Map<String, dynamic> json) => Devocional(
    referencia: json['referencia'] as String? ?? '',
    texto: json['devocional'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    versiculo: json['versiculo'] as String? ?? '',
  );

  final String referencia;
  final String texto;

  /// Promessas de Deus dá um título a cada dia; Manhã e Noite não.
  final String titulo;

  /// A promessa bíblica em destaque, separada do comentário. Vazio em
  /// Manhã e Noite, onde o versículo vem embutido no próprio texto.
  final String versiculo;

  /// Versículos-base além do principal, para o raro dia cuja epígrafe encadeia
  /// mais de uma passagem, como o de 12 de julho de Manhã e Noite, que abre
  /// citando Judas 1:1, 1 Coríntios 1:2 e 1 Pedro 1:2 em sequência.
  final List<(String referencia, String versiculo)> outrosVersiculos;
}

enum Periodo {
  manha('manha', 'Manhã'),
  noite('noite', 'Noite');

  const Periodo(this.chave, this.nome);

  final String chave;
  final String nome;

  /// A virada segue o horário do aparelho: manhã até 17h59, noite a partir das 18h.
  static Periodo pelaHora(int hora) =>
      hora < 18 ? Periodo.manha : Periodo.noite;
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

/// Uma mensagem do chat com uma persona.
///
/// [id] é o que faz a fusão com a cópia da nuvem não duplicar: uma mensagem
/// que chega com um id já visto é ignorada. [momento] em milissegundos desde
/// a época, para ordenar depois de uma fusão de dois aparelhos.
///
/// [papel] é string de propósito, como a ponte `Leitura` de
/// `AchadoDevocional`: o chat envia papéis ao Gemini como "user"/"model", e a
/// UI lê "assistant" com [doUsuario] para saber de que lado desenhar o balão.
class Mensagem {
  const Mensagem({
    required this.id,
    required this.papel,
    required this.texto,
    required this.momento,
  });

  factory Mensagem.doJson(Map<String, dynamic> json) => Mensagem(
    id: json['id'] as String? ?? '',
    papel: json['papel'] as String? ?? 'assistant',
    texto: json['texto'] as String? ?? '',
    momento: json['momento'] as int? ?? 0,
  );

  final String id;
  final String papel;
  final String texto;
  final int momento;

  bool get doUsuario => papel == 'user';

  Map<String, dynamic> paraJson() => {
    'id': id,
    'papel': papel,
    'texto': texto,
    'momento': momento,
  };
}
