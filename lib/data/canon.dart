/// Os 66 livros, na ordem canônica.
///
/// O `index.json` de cada versão traz os mesmos dados, mas esta lista é síncrona e
/// sempre disponível, o que evita um `await` só para desenhar o seletor de livros ou
/// resolver o nome de um livro vindo do cronograma de leitura.
class Livro {
  const Livro(
    this.slug,
    this.nome,
    this.abrev,
    this.capitulos,
    this.testamento,
    this.tituloFormal,
  );

  final String slug;
  final String nome;
  final String abrev;
  final int capitulos;
  final Testamento testamento;

  /// O título completo do livro, como está na Bíblia King James 1611 em
  /// português ("O Primeiro Livro de Moisés, chamado Gênesis"). Aparece só no
  /// topo do livro na Bíblia e na tela de Introdução; em todo outro lugar
  /// (botão do cronograma, referência do devocional, seletor) continua valendo
  /// [nome], o nome curto.
  final String tituloFormal;
}

enum Testamento { antigo, novo }

/// RegExp constants to avoid deprecated RegExp warnings.
  // ignore: deprecated_member_use
  final _digitosInicio = RegExp(r'^\d+');
  // ignore: deprecated_member_use
  final _faixaVersiculos = RegExp(r'^(\d+)(?:[-,](\d+))?');
  // ignore: deprecated_member_use
  final _separadorDeReferencias = RegExp(r'[,;]\s*|\s+e\s+');
  // ignore: deprecated_member_use
  final _numeroOuFaixa = RegExp(r'^\d+(-\d+)?$');

const _at = Testamento.antigo;
const _nt = Testamento.novo;

const canon = <Livro>[
  Livro(
    'genesis',
    'Gênesis',
    'Gn',
    50,
    _at,
    'O Primeiro Livro de Moisés, chamado Gênesis',
  ),
  Livro(
    'exodo',
    'Êxodo',
    'Êx',
    40,
    _at,
    'O Segundo Livro de Moisés, chamado Êxodo',
  ),
  Livro(
    'levitico',
    'Levítico',
    'Lv',
    27,
    _at,
    'O Terceiro Livro de Moisés, chamado Levítico',
  ),
  Livro(
    'numeros',
    'Números',
    'Nm',
    36,
    _at,
    'O Quarto Livro de Moisés, chamado Números',
  ),
  Livro(
    'deuteronomio',
    'Deuteronômio',
    'Dt',
    34,
    _at,
    'O Quinto Livro de Moisés, chamado Deuteronômio',
  ),
  Livro('josue', 'Josué', 'Js', 24, _at, 'O Livro de Josué'),
  Livro('juizes', 'Juízes', 'Jz', 21, _at, 'O Livro de Juízes'),
  Livro('rute', 'Rute', 'Rt', 4, _at, 'O Livro de Rute'),
  Livro('1samuel', '1 Samuel', '1Sm', 31, _at, 'O Primeiro Livro de Samuel'),
  Livro('2samuel', '2 Samuel', '2Sm', 24, _at, 'O Segundo Livro de Samuel'),
  Livro('1reis', '1 Reis', '1Rs', 22, _at, 'O Primeiro Livro de Reis'),
  Livro('2reis', '2 Reis', '2Rs', 25, _at, 'O Segundo Livro de Reis'),
  Livro(
    '1cronicas',
    '1 Crônicas',
    '1Cr',
    29,
    _at,
    'O Primeiro Livro das Crônicas',
  ),
  Livro(
    '2cronicas',
    '2 Crônicas',
    '2Cr',
    36,
    _at,
    'O Segundo Livro das Crônicas',
  ),
  Livro('esdras', 'Esdras', 'Ed', 10, _at, 'O Livro de Esdras'),
  Livro('neemias', 'Neemias', 'Ne', 13, _at, 'O Livro de Neemias'),
  Livro('ester', 'Ester', 'Et', 10, _at, 'O Livro de Ester'),
  Livro('jo', 'Jó', 'Jó', 42, _at, 'O Livro de Jó'),
  Livro('salmos', 'Salmos', 'Sl', 150, _at, 'O Livro de Salmos'),
  Livro('proverbios', 'Provérbios', 'Pv', 31, _at, 'O Livro de Provérbios'),
  Livro('eclesiastes', 'Eclesiastes', 'Ec', 12, _at, 'O Livro de Eclesiastes'),
  Livro('cantares', 'Cantares de Salomão', 'Ct', 8, _at, 'Cantares de Salomão'),
  Livro('isaias', 'Isaías', 'Is', 66, _at, 'O Livro de Isaías'),
  Livro('jeremias', 'Jeremias', 'Jr', 52, _at, 'O Livro de Jeremias'),
  Livro(
    'lamentacoes',
    'Lamentações',
    'Lm',
    5,
    _at,
    'As Lamentações de Jeremias',
  ),
  Livro('ezequiel', 'Ezequiel', 'Ez', 48, _at, 'O Livro de Ezequiel'),
  Livro('daniel', 'Daniel', 'Dn', 12, _at, 'O Livro de Daniel'),
  Livro('oseias', 'Oseias', 'Os', 14, _at, 'O Livro de Oseias'),
  Livro('joel', 'Joel', 'Jl', 3, _at, 'O Livro de Joel'),
  Livro('amos', 'Amós', 'Am', 9, _at, 'O Livro de Amós'),
  Livro('obadias', 'Obadias', 'Ob', 1, _at, 'O Livro de Obadias'),
  Livro('jonas', 'Jonas', 'Jn', 4, _at, 'O Livro de Jonas'),
  Livro('miqueias', 'Miquéias', 'Mq', 7, _at, 'O Livro de Miquéias'),
  Livro('naum', 'Naum', 'Na', 3, _at, 'O Livro de Naum'),
  Livro('habacuque', 'Habacuque', 'Hc', 3, _at, 'O Livro de Habacuque'),
  Livro('sofonias', 'Sofonias', 'Sf', 3, _at, 'O Livro de Sofonias'),
  Livro('ageu', 'Ageu', 'Ag', 2, _at, 'O Livro de Ageu'),
  Livro('zacarias', 'Zacarias', 'Zc', 14, _at, 'O Livro de Zacarias'),
  Livro('malaquias', 'Malaquias', 'Ml', 4, _at, 'O Livro de Malaquias'),
  Livro('mateus', 'Mateus', 'Mt', 28, _nt, 'O Evangelho Segundo Mateus'),
  Livro('marcos', 'Marcos', 'Mc', 16, _nt, 'O Evangelho Segundo Marcos'),
  Livro('lucas', 'Lucas', 'Lc', 24, _nt, 'O Evangelho Segundo Lucas'),
  Livro('joao', 'João', 'Jo', 21, _nt, 'O Evangelho Segundo João'),
  Livro('atos', 'Atos', 'At', 28, _nt, 'Os Atos dos Apóstolos'),
  Livro(
    'romanos',
    'Romanos',
    'Rm',
    16,
    _nt,
    'A Carta do Apóstolo Paulo aos Romanos',
  ),
  Livro(
    '1corintios',
    '1 Coríntios',
    '1Co',
    16,
    _nt,
    'Primeira Carta do Apóstolo Paulo aos Coríntios',
  ),
  Livro(
    '2corintios',
    '2 Coríntios',
    '2Co',
    13,
    _nt,
    'A Segunda Carta do Apóstolo Paulo aos Coríntios',
  ),
  Livro(
    'galatas',
    'Gálatas',
    'Gl',
    6,
    _nt,
    'A Carta do Apóstolo Paulo aos Gálatas',
  ),
  Livro(
    'efesios',
    'Efésios',
    'Ef',
    6,
    _nt,
    'A Carta do Apóstolo Paulo aos Efésios',
  ),
  Livro(
    'filipenses',
    'Filipenses',
    'Fp',
    4,
    _nt,
    'A Carta do Apóstolo Paulo aos Filipenses',
  ),
  Livro(
    'colossenses',
    'Colossenses',
    'Cl',
    4,
    _nt,
    'A Carta do Apóstolo Paulo aos Colossenses',
  ),
  Livro(
    '1tessalonicenses',
    '1 Tessalonicenses',
    '1Ts',
    5,
    _nt,
    'A Primeira Carta do Apóstolo Paulo aos Tessalonicenses',
  ),
  Livro(
    '2tessalonicenses',
    '2 Tessalonicenses',
    '2Ts',
    3,
    _nt,
    'A Segunda Carta do Apóstolo Paulo aos Tessalonicenses',
  ),
  Livro(
    '1timoteo',
    '1 Timóteo',
    '1Tm',
    6,
    _nt,
    'A Primeira Carta do Apóstolo Paulo a Timóteo',
  ),
  Livro(
    '2timoteo',
    '2 Timóteo',
    '2Tm',
    4,
    _nt,
    'A Segunda Carta do Apóstolo Paulo a Timóteo',
  ),
  Livro('tito', 'Tito', 'Tt', 3, _nt, 'A Carta de Paulo a Tito'),
  Livro('filemom', 'Filemom', 'Fm', 1, _nt, 'A Carta de Paulo a Filemom'),
  Livro('hebreus', 'Hebreus', 'Hb', 13, _nt, 'A Carta aos Hebreus'),
  Livro('tiago', 'Tiago', 'Tg', 5, _nt, 'A Carta de Tiago'),
  Livro('1pedro', '1 Pedro', '1Pe', 5, _nt, 'A Primeira Carta de Pedro'),
  Livro('2pedro', '2 Pedro', '2Pe', 3, _nt, 'A Segunda Carta de Pedro'),
  Livro('1joao', '1 João', '1Jo', 5, _nt, 'A Primeira Carta de João'),
  Livro('2joao', '2 João', '2Jo', 1, _nt, 'A Segunda Carta de João'),
  Livro('3joao', '3 João', '3Jo', 1, _nt, 'A Terceira Carta de João'),
  Livro('judas', 'Judas', 'Jd', 1, _nt, 'A Carta de Judas'),
  Livro('apocalipse', 'Apocalipse', 'Ap', 22, _nt, 'O Apocalipse de João'),
];

final Map<String, Livro> _porSlug = {for (final l in canon) l.slug: l};

Livro? livroPorSlug(String slug) => _porSlug[slug];

/// Nome de exibição a partir do slug, com o próprio slug como último recurso para
/// que uma referência desconhecida apareça na tela em vez de sumir.
String nomeDoLivro(String slug) => _porSlug[slug]?.nome ?? slug;

/// Abreviações alternativas vistas nas fontes originais dos devocionais, que não
/// batem com a abreviação oficial do canon: "Ex" sem acento para Êxodo, "Isa"
/// de três letras para Isaías, "Cantares" sem "de Salomão", e "Miqueias" sem
/// acento.
const _apelidosDeLivro = <String, String>{
  'Ex': 'exodo',
  'Isa': 'isaias',
  'Cantares': 'cantares',
  'Miqueias': 'miqueias',
};

/// Sem diferenciar maiúsculas: o Devocional reescreve a referência do dia com o
/// nome do livro todo em caixa alta ("JOSUÉ 5:12"), e essa comparação precisa
/// reconhecer esse formato tanto quanto o abreviado original ("Js 5:12").
(Livro, String)? _livroEPrefixo(String referencia) {
  final minuscula = referencia.toLowerCase();
  for (final l in canon) {
    if (minuscula.startsWith('${l.nome.toLowerCase()} ')) return (l, l.nome);
    if (minuscula.startsWith('${l.abrev.toLowerCase()} ')) return (l, l.abrev);
  }
  for (final MapEntry(key: apelido, value: slug) in _apelidosDeLivro.entries) {
    if (minuscula.startsWith('${apelido.toLowerCase()} ')) {
      return (livroPorSlug(slug)!, apelido);
    }
  }
  return null;
}

/// Livro a partir de uma referência como "Js 5:12" ou "Gênesis 3:15": os
/// devocionais citam o livro por nome cheio ou abreviado, conforme a fonte.
Livro? livroDaReferencia(String referencia) => _livroEPrefixo(referencia)?.$1;

/// Livro, capítulo e versículo a partir de uma referência como "Jo 6:37".
///
/// Numa faixa de versículos, como "Ex 15:22-27", ou com marca de edição atrás,
/// como "1Tm 3:16 ACF", usa só o primeiro número: é o que serve para buscar o
/// texto de um único versículo em destaque.
(Livro, int, int)? capituloEVersiculoDaReferencia(String referencia) {
  final encontrado = _livroEPrefixo(referencia);
  if (encontrado == null) return null;
  final (livro, prefixo) = encontrado;
  final partes = referencia.substring(prefixo.length + 1).split(':');
  if (partes.length != 2) return null;
  final capitulo = int.tryParse(_digitosInicio.firstMatch(partes[0])?.group(0) ?? '');
  final versiculo = int.tryParse(_digitosInicio.firstMatch(partes[1])?.group(0) ?? '');
  if (capitulo == null || versiculo == null) return null;
  return (livro, capitulo, versiculo);
}

/// Livro, capítulo e faixa de versículos a partir de uma referência como "Jo
/// 6:37" ou "Sl 102:13-14". Igual a [capituloEVersiculoDaReferencia], mas sem
/// descartar o segundo número de uma faixa: Promessas de Deus cita faixas de
/// dois versículos, e cortar no primeiro perderia metade da promessa.
(Livro, int, int, int)? faixaDeVersiculoDaReferencia(String referencia) {
  final encontrado = _livroEPrefixo(referencia);
  if (encontrado == null) return null;
  final (livro, prefixo) = encontrado;
  final partes = referencia.substring(prefixo.length + 1).split(':');
  if (partes.length != 2) return null;
  final capitulo = int.tryParse(_digitosInicio.firstMatch(partes[0])?.group(0) ?? '');
  final match = _faixaVersiculos.firstMatch(partes[1]);
  if (capitulo == null || match == null) return null;
  final deVersiculo = int.parse(match.group(1)!);
  final ateVersiculo = int.tryParse(match.group(2) ?? '') ?? deVersiculo;
  return (livro, capitulo, deVersiculo, ateVersiculo);
}

/// Separador de trechos numa referência que cita mais de uma passagem, como
/// "Js 5:12 e Hb 4:9": vírgula, ponto e vírgula ou "e".
/// Separa [referencia] em trechos, cada um citando uma única passagem.
///
/// A vírgula também aparece dentro de uma única passagem para citar dois
/// versículos do mesmo capítulo ("Zc 1:12,13" ou "1Jo 3:1,2"): só vira um
/// trecho novo quando o que segue é uma passagem de verdade, não um número
/// solto de versículo.
List<String> trechosDaReferencia(String referencia) {
  final trechos = <String>[];
  for (final bruto in referencia.split(_separadorDeReferencias)) {
    final trecho = bruto.trim();
    if (trechos.isNotEmpty && _numeroOuFaixa.hasMatch(trecho)) {
      trechos[trechos.length - 1] = '${trechos.last},$trecho';
    } else {
      trechos.add(trecho);
    }
  }
  return trechos;
}

/// Todos os livros citados numa referência, na ordem em que aparecem.
///
/// Cobre o dia comum, de um só livro, e o raro dia que cita mais de um.
List<Livro> livrosDaReferencia(String referencia) {
  final encontrados = <Livro>[];
  for (final trecho in trechosDaReferencia(referencia)) {
    final livro = livroDaReferencia(trecho);
    if (livro != null && !encontrados.contains(livro)) encontrados.add(livro);
  }
  return encontrados;
}

/// Livro, capítulo e versículo de cada trecho de uma referência que cita mais de
/// uma passagem, na ordem em que aparecem.
///
/// Cobre o dia comum, de um só versículo base, e o raro dia cuja epígrafe
/// encadeia mais de um, como o de 12 de julho de Manhã e Noite ("Jd 1:1, 1Co
/// 1:2, 1Pe 1:2"), que abre citando Judas, 1 Coríntios e 1 Pedro em sequência.
List<(Livro, int, int)> versiculosDaReferencia(String referencia) {
  final resolvidos = <(Livro, int, int)>[];
  for (final trecho in trechosDaReferencia(referencia)) {
    final resolvido = capituloEVersiculoDaReferencia(trecho);
    if (resolvido != null) resolvidos.add(resolvido);
  }
  return resolvidos;
}

/// Livro, capítulo e faixa de versículos de cada trecho de uma referência que
/// cita mais de uma passagem. Ver [faixaDeVersiculoDaReferencia].
List<(Livro, int, int, int)> faixasDaReferencia(String referencia) {
  final resolvidos = <(Livro, int, int, int)>[];
  for (final trecho in trechosDaReferencia(referencia)) {
    final resolvido = faixaDeVersiculoDaReferencia(trecho);
    if (resolvido != null) resolvidos.add(resolvido);
  }
  return resolvidos;
}

/// A única tradução interna disponível no aplicativo.
enum Versao {
  bkj('bkj', 'King James 1611', 'BKJ');

  const Versao(this.pasta, this.nome, this.sigla);

  final String pasta;
  final String nome;
  final String sigla;
}

/// Onde o build web fica publicado. Usado para montar o link absoluto de um
/// versículo (o rastreador de prévia do WhatsApp não resolve caminho relativo)
/// e para reconhecer, em `main.dart`, se `Uri.base` é o próprio site ou o
/// diretório de trabalho de uma plataforma que não é web.
const enderecoDoSite = 'https://felipeambrozini.com.br/devocional/';

/// Livro, capítulo e versículo (opcional) a partir do parâmetro `ler` de um
/// link, como `joao.3.16` ou `joao.3`. Serve para main.dart abrir a leitura
/// que veio por URL, sem duplicar a validação de slug que `livroPorSlug` já
/// faz. `null` para slug inexistente ou número que não faz sentido — melhor
/// cair na tela Hoje do que abrir uma leitura errada.
(String, int, int?)? alvoDoLink(String parametro) {
  final partes = parametro.split('.');
  if (partes.length < 2 || partes.length > 3) return null;
  final livro = livroPorSlug(partes[0]);
  final capitulo = int.tryParse(partes[1]);
  if (livro == null || capitulo == null) return null;
  if (capitulo < 1 || capitulo > livro.capitulos) return null;
  final versiculo = partes.length == 3 ? int.tryParse(partes[2]) : null;
  if (partes.length == 3 && versiculo == null) return null;
  return (livro.slug, capitulo, versiculo);
}

/// Link direto para um versículo, o inverso de [alvoDoLink]. Vai junto do
/// texto de Copiar e Compartilhar em `biblia.dart`.
String linkDoVersiculo(String slug, int capitulo, int versiculo) =>
    '$enderecoDoSite?ler=$slug.$capitulo.$versiculo';
