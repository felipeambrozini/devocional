import 'modelos.dart';

/// De que dia veio a leitura aberta na Bíblia, para marcar o dia como lido
/// quando a pessoa tiver chegado ao fim de **todos** os capítulos dele. Quem
/// sabe o dia é o cartão que abriu a Bíblia (a leitura de hoje, o cronograma,
/// um plano); a Bíblia só recebe este valor, sem recalcular "hoje": o
/// cronograma mostra outras datas também.
///
/// Os capítulos lidos de cada dia ficam guardados ([ProgressoDosDias]), porque
/// as leituras de um dia podem ser feitas em momentos diferentes: Gênesis de
/// manhã, Salmos à noite.
///
/// Vai na URL da leitura
/// (`/ler/genesis/1?diaDoCronograma=...&capitulos=genesis.1,salmos.1`), então
/// um F5 no meio da leitura não perde o dia.
sealed class DiaDaLeitura {
  const DiaDaLeitura({required this.capitulos});

  /// Os capítulos do dia, como "genesis.1", na ordem da leitura. Chegar ao fim
  /// de todos marca o dia.
  final List<String> capitulos;

  /// O que identifica o dia no [ProgressoDosDias] (`cronograma:2026-11-24`,
  /// `plano:<id>:5`).
  String get chaveDoProgresso;

  /// O capítulo [numero] de [livro] no formato de [capitulos].
  static String capitulo(String livro, int numero) => '$livro.$numero';

  /// Se o capítulo faz parte do dia.
  bool temCapitulo(String livro, int numero) =>
      capitulos.contains(capitulo(livro, numero));

  /// O dia [chave] do cronograma com estes [itens], ou `null` quando não dá
  /// para marcar sozinho (ver [capitulosDosItens]).
  static DiaDoCronograma? doCronograma(String chave, List<ItemDoDia> itens) {
    final capitulos = capitulosDosItens(itens);
    if (capitulos == null) return null;
    return DiaDoCronograma(chave: chave, capitulos: capitulos);
  }

  /// O dia [numero] do plano [planoId] com estes [itens], ou `null` quando
  /// não dá para marcar sozinho (ver [capitulosDosItens]).
  static DiaDePlano? doPlano(
    String planoId,
    int numero,
    List<ItemDoDia> itens,
  ) {
    final capitulos = capitulosDosItens(itens);
    if (capitulos == null) return null;
    return DiaDePlano(planoId: planoId, numero: numero, capitulos: capitulos);
  }

  /// Todos os capítulos de [itens], cada faixa aberta capítulo a capítulo
  /// ("Gênesis 1–2" vira genesis.1 e genesis.2). `null` quando o dia não tem
  /// capítulo nenhum ou tem um devocional: a leitura do devocional não passa
  /// pela Bíblia, e marcar o dia sem ela deixaria uma leitura de fora.
  static List<String>? capitulosDosItens(List<ItemDoDia> itens) {
    final capitulos = <String>[];
    for (final item in itens) {
      switch (item) {
        case ItemDeCapitulo(:final faixa):
          for (var c = faixa.deCapitulo; c <= faixa.ateCapitulo; c++) {
            final este = capitulo(faixa.livro, c);
            if (!capitulos.contains(este)) capitulos.add(este);
          }
        case ItemDeDevocional():
          return null;
      }
    }
    return capitulos.isEmpty ? null : capitulos;
  }

  /// Os parâmetros da URL (ver [doParametros]).
  Map<String, String> get parametros;

  /// O dia de [parametros], ou `null` se faltar algo ou vier torto (link
  /// velho ou digitado): a leitura abre normal, só sem marcar o dia. Aceita
  /// também o `fim` da versão anterior, que guardava só o último capítulo.
  static DiaDaLeitura? doParametros(Map<String, String> parametros) {
    final capitulos = _capitulosDoParametro(
      parametros['capitulos'] ?? parametros['fim'],
    );
    if (capitulos == null) return null;
    final cronograma = parametros['diaDoCronograma'];
    if (cronograma != null && cronograma.isNotEmpty) {
      return DiaDoCronograma(chave: cronograma, capitulos: capitulos);
    }
    final plano = parametros['plano'];
    final numero = int.tryParse(parametros['diaDoPlano'] ?? '');
    if (plano != null && plano.isNotEmpty && numero != null && numero > 0) {
      return DiaDePlano(planoId: plano, numero: numero, capitulos: capitulos);
    }
    return null;
  }

  static List<String>? _capitulosDoParametro(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    final capitulos = <String>[];
    for (final parte in texto.split(',')) {
      final pedacos = parte.split('.');
      if (pedacos.length != 2 || pedacos[0].isEmpty) return null;
      final numero = int.tryParse(pedacos[1]);
      if (numero == null || numero < 1) return null;
      capitulos.add(capitulo(pedacos[0], numero));
    }
    return capitulos;
  }

  String get _capitulosNaUrl => capitulos.join(',');
}

/// Um dia do cronograma anual, pela chave de `Estado.chaveDeLeitura`
/// ("2026-11-24").
final class DiaDoCronograma extends DiaDaLeitura {
  const DiaDoCronograma({required this.chave, required super.capitulos});

  final String chave;

  @override
  String get chaveDoProgresso => 'cronograma:$chave';

  @override
  Map<String, String> get parametros => {
    'diaDoCronograma': chave,
    'capitulos': _capitulosNaUrl,
  };
}

/// Um dia (a partir de 1) de um plano do usuário ou do Plano de Jesus.
final class DiaDePlano extends DiaDaLeitura {
  const DiaDePlano({
    required this.planoId,
    required this.numero,
    required super.capitulos,
  });

  final String planoId;
  final int numero;

  @override
  String get chaveDoProgresso => 'plano:$planoId:$numero';

  @override
  Map<String, String> get parametros => {
    'plano': planoId,
    'diaDoPlano': '$numero',
    'capitulos': _capitulosNaUrl,
  };
}
