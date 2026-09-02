import 'dart:math';

import 'canon.dart';
import 'conteudo.dart';
import 'modelos.dart';

int _contadorIdPlano = 0;

/// Um dia de um plano de leitura criado pelo usuário.
///
/// Diferente de [DiaDoPlano], não tem data: o plano do usuário é uma
/// sequência de 1 a N dias, e não um calendário.
class DiaDePlanoDoUsuario {
  const DiaDePlanoDoUsuario({required this.numero, required this.itens});

  /// Posição do dia no plano, de 1 em diante. É a chave de progresso.
  final int numero;

  final List<ItemDoDia> itens;

  /// Só as faixas de capítulo do dia, na ordem, sem os devocionais
  /// intercalados — o que a maioria do código precisa (rótulo, contagem de
  /// capítulos, o botão que abre a Bíblia).
  List<Faixa> get faixas => [
    for (final item in itens)
      if (item is ItemDeCapitulo) item.faixa,
  ];

  String get rotulo => faixas.map((f) => f.rotulo).join(', ');
}

/// Um plano de leitura criado pelo usuário na aba Meus Planos.
///
/// Guarda só a receita — livros e dias — e monta os dias na hora
/// ([diasDoPlano]): é determinístico, e mudar o algoritmo de distribuição
/// nunca deixa um plano gravado inconsistente.
///
/// [compartilhado] diz que o plano também vive num documento `planos/{id}`
/// do Firestore (ver `lib/data/planos_nuvem.dart`): aí o progresso é de cada
/// participante, gravado na própria entrada do documento. A cópia local é o
/// espelho; o documento é a verdade.
class PlanoDoUsuario {
  const PlanoDoUsuario({
    required this.id,
    required this.titulo,
    required this.livros,
    required this.dias,
    required this.criadoEm,
    this.compartilhado = false,
    this.criadoPor,
    this.incluirDevocionais = false,
    this.devocionalAntes = true,
  });

  factory PlanoDoUsuario.doJson(Map<String, dynamic> json) => PlanoDoUsuario(
    id: json['id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    livros: [
      for (final l in json['livros'] as List? ?? const [])
        if (l is String && livroPorSlug(l) != null) l,
    ],
    dias: json['dias'] as int? ?? 1,
    criadoEm: DateTime.fromMillisecondsSinceEpoch(
      json['criadoEm'] as int? ?? 0,
    ),
    compartilhado: json['compartilhado'] as bool? ?? false,
    criadoPor: json['criadoPor'] as String?,
    incluirDevocionais: json['incluirDevocionais'] as bool? ?? false,
    devocionalAntes: json['devocionalAntes'] as bool? ?? true,
  );

  /// De um documento `planos/{id}` do Firestore, cujo esquema é outro (ver
  /// `lib/data/planos_nuvem.dart`). O documento não traz o próprio id nem o
  /// campo `compartilhado` — quem vem de lá é compartilhado por definição.
  factory PlanoDoUsuario.doJsonDaNuvem(
    Map<String, dynamic> json, {
    required String id,
    required DateTime criadoEm,
  }) => PlanoDoUsuario(
    id: id,
    titulo: json['titulo'] as String? ?? '',
    livros: [
      for (final l in json['livros'] as List? ?? const [])
        if (l is String && livroPorSlug(l) != null) l,
    ],
    dias: json['dias'] as int? ?? 1,
    criadoEm: criadoEm,
    compartilhado: true,
    criadoPor: json['criadoPor'] as String?,
    incluirDevocionais: json['incluirDevocionais'] as bool? ?? false,
    devocionalAntes: json['devocionalAntes'] as bool? ?? true,
  );

  /// Identidade estável do plano, e o id do documento na nuvem quando
  /// compartilhado. Gerado por [novoIdDePlano], para um link compartilhado
  /// não ser adivinhável de propósito.
  final String id;
  final String titulo;

  /// Slugs dos livros, na ordem canônica.
  final List<String> livros;

  /// Quantos dias o plano tem. Pode ser maior que o número de dias de
  /// verdade quando passou do total de capítulos — a montagem corta os dias
  /// vazios (ver [montarPlanoDeLeitura]).
  final int dias;
  final DateTime criadoEm;
  final bool compartilhado;

  /// O uid de quem criou, só em plano compartilhado — é quem tem o poder de
  /// excluir para todos; os demais só podem sair (ver `excluirPlano` e
  /// `sairDoPlano` em `lib/funcoes/planos_acoes.dart`).
  final String? criadoPor;

  /// Se o plano intercala os devocionais dos livros entre os capítulos —
  /// ver [montarPlanoDeLeitura]. Escolhido na criação do plano
  /// (`lib/telas/novo_plano.dart`), não editável depois.
  final bool incluirDevocionais;

  /// Só relevante com [incluirDevocionais]: se o devocional do capítulo
  /// aparece antes ou depois dele no dia.
  final bool devocionalAntes;

  List<DiaDePlanoDoUsuario> get diasDoPlano => montarPlanoDeLeitura(
    livros: livros,
    dias: dias,
    incluirDevocionais: incluirDevocionais,
    devocionalAntes: devocionalAntes,
  );

  int get totalDeCapitulos {
    var total = 0;
    for (final slug in livros) {
      total += livroPorSlug(slug)?.capitulos ?? 0;
    }
    return total;
  }

  PlanoDoUsuario compartilhadoComo(bool novo) => PlanoDoUsuario(
    id: id,
    titulo: titulo,
    livros: livros,
    dias: dias,
    criadoEm: criadoEm,
    compartilhado: novo,
    criadoPor: criadoPor,
    incluirDevocionais: incluirDevocionais,
    devocionalAntes: devocionalAntes,
  );

  Map<String, dynamic> paraJson() => {
    'id': id,
    'titulo': titulo,
    'livros': livros,
    'dias': dias,
    'criadoEm': criadoEm.millisecondsSinceEpoch,
    if (compartilhado) 'compartilhado': true,
    if (criadoPor != null) 'criadoPor': criadoPor,
    'incluirDevocionais': incluirDevocionais,
    'devocionalAntes': devocionalAntes,
  };
}

/// Gerador criptográfico: o id de um plano compartilhado é o único controle
/// de acesso a ele (ver firestore.rules, `planos/{planoId}`) — quem o
/// conhece entra. Um `Random()` comum (não semeado por entropia do sistema)
/// não é o bastante para isso.
final _aleatorioSeguro = Random.secure();

/// Um id novo de plano: instante em base 36 mais contador + aleatório.
/// O contador garante unicidade mesmo em laços apertados; os 32 bits
/// aleatórios (8 dígitos hex) são o que torna o id de um link
/// compartilhado difícil de adivinhar — 16 bits era pouco para o único
/// controle de acesso ao plano.
String novoIdDePlano() {
  _contadorIdPlano++;
  final aleatorio = _aleatorioSeguro
      .nextInt(0x100000000)
      .toRadixString(16)
      .padLeft(8, '0');
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_contadorIdPlano.toRadixString(36).padLeft(2, '0')}$aleatorio';
}

/// Distribui os capítulos de [livros] por [dias] dias, do primeiro capítulo
/// do primeiro livro ao último do último.
///
/// Cada dia recebe um trecho contíguo dos capítulos, com contagens o mais
/// parecidas possível (Salmos tem 150 capítulos; em 30 dias, uns dias pegam
/// 5 e outros 6). Os capítulos de um mesmo livro que ficam no mesmo dia
/// viram uma faixa só — "Salmos 51 a 55" — e a virada de livro quebra a
/// faixa, como no cronograma anual.
///
/// Quando [dias] passa do total de capítulos, os dias que sobrariam vazios
/// são cortados: a tela de criação já impede isso (valida dias até o total),
/// e esta defesa é para planos gravados por uma versão futura ou corrompidos.
List<DiaDePlanoDoUsuario> montarPlanoDeLeitura({
  required List<String> livros,
  required int dias,
  bool incluirDevocionais = false,
  bool devocionalAntes = true,
}) {
  final capitulos = <(String, int)>[];
  for (final slug in livros) {
    final livro = livroPorSlug(slug);
    if (livro == null) continue;
    for (var numero = 1; numero <= livro.capitulos; numero++) {
      capitulos.add((slug, numero));
    }
  }
  if (capitulos.isEmpty) return const [];
  if (dias < 1) return const [];

  final porDia = capitulos.length / dias;
  final plano = <DiaDePlanoDoUsuario>[];
  for (var dia = 0; dia < dias; dia++) {
    final de = (dia * porDia).round();
    final ate = ((dia + 1) * porDia).round();
    if (ate <= de) continue;
    final faixas = _agruparEmFaixas(capitulos.sublist(de, ate));
    plano.add(
      DiaDePlanoDoUsuario(
        numero: plano.length + 1,
        itens: incluirDevocionais
            ? _itensComDevocionais(faixas, devocionalAntes)
            : [for (final f in faixas) ItemDeCapitulo(f)],
      ),
    );
  }
  return plano;
}

/// Para cada faixa, busca os devocionais de cada capítulo que ela cobre e os
/// intercala antes ou depois do [ItemDeCapitulo] correspondente.
List<ItemDoDia> _itensComDevocionais(List<Faixa> faixas, bool antes) {
  final itens = <ItemDoDia>[];
  for (final faixa in faixas) {
    // Um devocional cuja referência cita mais de um capítulo da mesma faixa
    // (raro, mas possível) seria encontrado uma vez por capítulo citado; o
    // Set dedupe antes de intercalar, preservando a ordem de entrada — que
    // importa aqui (manhã antes de noite, por exemplo).
    final devocionais = {
      for (final capitulo in faixa.capitulos)
        ...Conteudo.instancia.devocionaisDoCapitulo(faixa.livro, capitulo),
    }.toList();
    if (antes) itens.addAll(devocionais);
    itens.add(ItemDeCapitulo(faixa));
    if (!antes) itens.addAll(devocionais);
  }
  return itens;
}

/// Capítulos consecutivos do mesmo livro viram uma faixa; a troca de livro
/// (ou um salto de capítulo, impossível aqui porque o trecho é contíguo)
/// fecha a faixa anterior.
List<Faixa> _agruparEmFaixas(List<(String, int)> trecho) {
  final faixas = <Faixa>[];
  String? livroAtual;
  var de = 0;
  var ate = 0;
  for (final (livro, capitulo) in trecho) {
    if (livro == livroAtual && capitulo == ate + 1) {
      ate = capitulo;
    } else {
      if (livroAtual != null) {
        faixas.add(Faixa(livro: livroAtual, deCapitulo: de, ateCapitulo: ate));
      }
      livroAtual = livro;
      de = capitulo;
      ate = capitulo;
    }
  }
  if (livroAtual != null) {
    faixas.add(Faixa(livro: livroAtual, deCapitulo: de, ateCapitulo: ate));
  }
  return faixas;
}

/// Os nomes dos livros num resumo curto para listas: "Gênesis", "Gênesis e
/// Êxodo" ou "Gênesis, Êxodo e mais 3 livros".
String resumoDosLivros(List<String> livros) {
  final nomes = [for (final slug in livros) nomeDoLivro(slug)];
  return switch (nomes.length) {
    0 => '',
    1 => nomes.first,
    2 => '${nomes[0]} e ${nomes[1]}',
    3 => '${nomes[0]}, ${nomes[1]} e ${nomes[2]}',
    _ => '${nomes[0]}, ${nomes[1]} e mais ${nomes.length - 2} livros',
  };
}

/// Os nomes de todos os livros do plano, sem truncar — ao contrário de
/// [resumoDosLivros]: "Gênesis, Êxodo e Levítico".
String listaDosLivros(List<String> livros) {
  final nomes = [for (final slug in livros) nomeDoLivro(slug)];
  return switch (nomes.length) {
    0 => '',
    1 => nomes.first,
    _ => '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}',
  };
}

/// Título padrão de um plano, para quando quem cria não dá nome próprio:
/// "Gênesis em 30 dias" ou "Gênesis, Êxodo e mais 64 livros em 365 dias".
String tituloDePlano(List<String> livros, int dias) {
  final livrosTexto = resumoDosLivros(livros);
  if (livrosTexto.isEmpty) return 'Plano de leitura em $dias dias';
  return '$livrosTexto em $dias ${dias == 1 ? 'dia' : 'dias'}';
}
