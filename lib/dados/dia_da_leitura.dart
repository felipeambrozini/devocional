import 'modelos.dart';

/// De que dia veio a leitura aberta na Bíblia, para marcar o dia como lido
/// quando a pessoa chega ao fim do último capítulo dele. Quem sabe o dia é o
/// cartão que abriu a Bíblia (a leitura de hoje, o cronograma, um plano); a
/// Bíblia só recebe este valor, sem recalcular "hoje": o cronograma mostra
/// outras datas também.
///
/// Vai na URL da leitura (`/ler/joao/3?dia=...&fim=joao.3`), então um F5 no
/// meio da leitura não perde o dia.
sealed class DiaDaLeitura {
  const DiaDaLeitura({required this.livroDoFim, required this.capituloDoFim});

  /// O último capítulo do dia: chegar ao fim dele marca o dia.
  final String livroDoFim;
  final int capituloDoFim;

  /// O dia [chave] do cronograma com estes [itens], ou `null` quando não há
  /// fim a marcar (ver [fimDosItens]).
  static DiaDoCronograma? doCronograma(String chave, List<ItemDoDia> itens) {
    final fim = fimDosItens(itens);
    if (fim == null) return null;
    return DiaDoCronograma(
      chave: chave,
      livroDoFim: fim.$1,
      capituloDoFim: fim.$2,
    );
  }

  /// O dia [numero] do plano [planoId] com estes [itens], ou `null` quando não
  /// há fim a marcar (ver [fimDosItens]).
  static DiaDePlano? doPlano(
    String planoId,
    int numero,
    List<ItemDoDia> itens,
  ) {
    final fim = fimDosItens(itens);
    if (fim == null) return null;
    return DiaDePlano(
      planoId: planoId,
      numero: numero,
      livroDoFim: fim.$1,
      capituloDoFim: fim.$2,
    );
  }

  bool ehOFim(String livro, int capitulo) =>
      livro == livroDoFim && capitulo == capituloDoFim;

  /// O último capítulo de [itens], ou `null` quando o dia termina num
  /// devocional (marcar ao fim da Bíblia deixaria o devocional de fora) ou não
  /// tem capítulo nenhum.
  static (String, int)? fimDosItens(List<ItemDoDia> itens) {
    if (itens.isEmpty) return null;
    return switch (itens.last) {
      ItemDeCapitulo(:final faixa) => (faixa.livro, faixa.ateCapitulo),
      ItemDeDevocional() => null,
    };
  }

  /// Os parâmetros da URL (ver [doParametros]).
  Map<String, String> get parametros;

  /// O dia de [parametros], ou `null` se faltar algo ou vier torto (link
  /// velho ou digitado): a leitura abre normal, só sem marcar o dia.
  static DiaDaLeitura? doParametros(Map<String, String> parametros) {
    final fim = parametros['fim']?.split('.');
    if (fim == null || fim.length != 2) return null;
    final livro = fim[0];
    final capitulo = int.tryParse(fim[1]);
    if (livro.isEmpty || capitulo == null || capitulo < 1) return null;
    final cronograma = parametros['diaDoCronograma'];
    if (cronograma != null && cronograma.isNotEmpty) {
      return DiaDoCronograma(
        chave: cronograma,
        livroDoFim: livro,
        capituloDoFim: capitulo,
      );
    }
    final plano = parametros['plano'];
    final numero = int.tryParse(parametros['diaDoPlano'] ?? '');
    if (plano != null && plano.isNotEmpty && numero != null && numero > 0) {
      return DiaDePlano(
        planoId: plano,
        numero: numero,
        livroDoFim: livro,
        capituloDoFim: capitulo,
      );
    }
    return null;
  }
}

/// Um dia do cronograma anual, pela chave de `Estado.chaveDeLeitura`
/// ("2026-11-24").
final class DiaDoCronograma extends DiaDaLeitura {
  const DiaDoCronograma({
    required this.chave,
    required super.livroDoFim,
    required super.capituloDoFim,
  });

  final String chave;

  @override
  Map<String, String> get parametros => {
    'diaDoCronograma': chave,
    'fim': '$livroDoFim.$capituloDoFim',
  };
}

/// Um dia (a partir de 1) de um plano do usuário ou do Plano de Jesus.
final class DiaDePlano extends DiaDaLeitura {
  const DiaDePlano({
    required this.planoId,
    required this.numero,
    required super.livroDoFim,
    required super.capituloDoFim,
  });

  final String planoId;
  final int numero;

  @override
  Map<String, String> get parametros => {
    'plano': planoId,
    'diaDoPlano': '$numero',
    'fim': '$livroDoFim.$capituloDoFim',
  };
}
