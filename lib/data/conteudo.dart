import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'canon.dart';
import 'modelos.dart';

/// Leitura dos assets, com cache em memória.
///
/// Um arquivo por livro por versão. Abrir João não custa carregar Gênesis, e na web
/// o navegador baixa só o livro aberto em vez de 4 MB no primeiro frame.
class Conteudo {
  Conteudo._();

  static final Conteudo instancia = Conteudo._();

  final Map<String, Map<String, dynamic>> _livros = {};
  Map<String, Map<String, dynamic>>? _devocionais;
  List<DiaDoPlano>? _planoComum;
  List<DiaDoPlano>? _planoBissexto;
  final Map<String, Introducao?> _introducoes = {};

  /// Regra gregoriana padrão: bissexto a cada 4 anos, exceto séculos não
  /// divisíveis por 400.
  static bool ehBissexto(int ano) =>
      (ano % 4 == 0 && ano % 100 != 0) || ano % 400 == 0;

  /// Quantos dias o cronograma tem no ano, que é o total contra o qual o
  /// progresso é medido. Um dono só para esse número: ele estava escrito como 365
  /// à mão na fração do progresso, no rótulo da tela e na escolha do asset, e em
  /// ano bissexto os três discordavam do cronograma de 366 dias.
  static int diasDoAno(int ano) => ehBissexto(ano) ? 366 : 365;

  /// Chave 'MM-DD' de uma data. Os devocionais e o cronograma são anuais e se
  /// repetem, então nenhum deles guarda ano.
  ///
  /// 29 de fevereiro se resolve sozinho: em ano comum essa data não existe, e o
  /// próprio DateTime a normaliza para 1 de março. Não há caminho no app que
  /// produza a chave '02-29' fora de um ano bissexto.
  static String chaveDoDia(DateTime data) =>
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _carregarLivro(Versao versao, String slug) async {
    final chave = '${versao.pasta}/$slug';
    final cacheado = _livros[chave];
    if (cacheado != null) return cacheado;
    final cru = await rootBundle.loadString('assets/bible/${versao.pasta}/$slug.json');
    final dados = json.decode(cru) as Map<String, dynamic>;
    _livros[chave] = dados;
    return dados;
  }

  Future<Capitulo> capitulo(Versao versao, String slug, int numero) async {
    final livro = await _carregarLivro(versao, slug);
    final capitulos = livro['chapters'] as Map<String, dynamic>;
    final cap = capitulos['$numero'] as Map<String, dynamic>?;
    if (cap == null) {
      return Capitulo(livro: slug, numero: numero, titulo: '', versiculos: const []);
    }
    final versiculos = (cap['verses'] as Map<String, dynamic>)
        .entries
        .map((e) => (int.parse(e.key), e.value as String))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return Capitulo(
      livro: slug,
      numero: numero,
      titulo: cap['title'] as String? ?? '',
      versiculos: versiculos,
    );
  }

  /// Um único versículo, para mostrar o texto de um favorito ou de uma nota sem
  /// abrir o capítulo inteiro na tela.
  Future<String> versiculo(Versao versao, String slug, int capitulo, int numero) async {
    final cap = await this.capitulo(versao, slug, capitulo);
    for (final (n, texto) in cap.versiculos) {
      if (n == numero) return texto;
    }
    return '';
  }

  /// O cronograma anual. Em ano bissexto usa a variante de 366 dias, com 29 de
  /// fevereiro como dia próprio em vez de dobrar a leitura de 28/2.
  Future<List<DiaDoPlano>> plano({bool bissexto = false}) async {
    final cacheado = bissexto ? _planoBissexto : _planoComum;
    if (cacheado != null) return cacheado;
    final arquivo = bissexto ? 'reading_plan_bissexto.json' : 'reading_plan.json';
    final cru = await rootBundle.loadString('assets/$arquivo');
    final dias = [
      for (final d in json.decode(cru) as List)
        DiaDoPlano.doJson(d as Map<String, dynamic>),
    ];
    if (bissexto) {
      _planoBissexto = dias;
    } else {
      _planoComum = dias;
    }
    return dias;
  }

  /// O dia do cronograma para uma data.
  Future<DiaDoPlano?> diaDoPlano(DateTime data) async {
    final chave = chaveDoDia(data);
    final dias = await plano(bissexto: ehBissexto(data.year));
    for (final dia in dias) {
      if (dia.data == chave) return dia;
    }
    return null;
  }

  Future<Map<String, Map<String, dynamic>>> _carregarDevocionais() async {
    final cacheado = _devocionais;
    if (cacheado != null) return cacheado;
    final cru = await rootBundle.loadString('assets/devotional/morning_evening.json');
    final dados = (json.decode(cru) as Map<String, dynamic>).map(
      (chave, valor) => MapEntry(chave, valor as Map<String, dynamic>),
    );
    _devocionais = dados;
    return dados;
  }

  /// Manhã e Noite para uma data. Manhã e Noite tem 366 dias, inclusive 29 de
  /// fevereiro, então não há fallback a fazer aqui.
  ///
  /// A referência do JSON vem abreviada ("Jo 6:37") e o versículo vem embutido
  /// no próprio texto do comentário. Aqui ela é trocada pelo nome do livro por
  /// extenso em maiúsculas ("JOÃO 6:37") e o versículo completo é buscado na
  /// BKJ, para o cartão mostrar o mesmo formato de Promessas de Deus: livro em
  /// destaque, depois o versículo, depois o comentário.
  Future<Devocional?> devocional(DateTime data, Periodo periodo) async {
    final dados = await _carregarDevocionais();
    final chave = chaveDoDia(data);
    final dia = dados[chave];
    if (dia == null) return null;
    final entrada = dia[periodo.chave] as Map<String, dynamic>?;
    if (entrada == null) return null;
    final dev = Devocional.doJson(entrada);

    final resolvida = capituloEVersiculoDaReferencia(dev.referencia);
    if (resolvida == null) return dev;
    final (livro, capitulo, numero) = resolvida;
    final texto = await versiculo(Versao.bkj, livro.slug, capitulo, numero);
    if (texto.isEmpty) return dev;

    return Devocional(
      referencia: '${livro.nome.toUpperCase()} $capitulo:$numero',
      texto: dev.texto,
      titulo: dev.titulo,
      versiculo: texto,
    );
  }

  /// Promessas de Deus. Ainda sem texto: o arquivo pode não existir, e nesse caso a
  /// tela mostra o aviso em vez de estourar.
  ///
  /// A ausência também é cacheada, senão cada reconstrução da tela tentaria carregar
  /// de novo um asset que não existe.
  Map<String, Map<String, dynamic>>? _promessas;
  bool _tentouPromessas = false;

  Future<Devocional?> promessa(DateTime data) async {
    if (!_tentouPromessas) {
      _tentouPromessas = true;
      try {
        final cru = await rootBundle.loadString('assets/devotional/promises.json');
        _promessas = (json.decode(cru) as Map<String, dynamic>).map(
          (chave, valor) => MapEntry(chave, valor as Map<String, dynamic>),
        );
      } catch (_) {
        _promessas = null;
      }
    }
    final dados = _promessas;
    if (dados == null) return null;
    final chave = chaveDoDia(data);
    final dia = dados[chave];
    return dia == null ? null : Devocional.doJson(dia);
  }

  /// Introdução de um livro. Devolve nulo quando ainda não foi escrita.
  Future<Introducao?> introducao(String slug) async {
    if (_introducoes.containsKey(slug)) return _introducoes[slug];
    Introducao? intro;
    try {
      final cru = await rootBundle.loadString('assets/intro/$slug.json');
      intro = Introducao.doJson(json.decode(cru) as Map<String, dynamic>);
    } catch (_) {
      intro = null;
    }
    _introducoes[slug] = intro;
    return intro;
  }

  /// Busca no texto de uma versão, emitindo os achados livro por livro.
  ///
  /// ponytail: varredura sequencial, sem índice invertido. A primeira busca na Bíblia
  /// inteira lê cerca de 4 MB e leva uns segundos; depois tudo está em cache. Como é
  /// um stream, a tela já mostra Gênesis enquanto o resto carrega, e cancelar a busca
  /// interrompe a leitura. Se incomodar, o caminho é SQLite com FTS5.
  Stream<Achado> buscar(Versao versao, String termo, {int limite = 300}) async* {
    final alvo = _normalizar(termo);
    if (alvo.length < 3) return;
    var total = 0;
    for (final livro in canon) {
      final dados = await _carregarLivro(versao, livro.slug);
      final capitulos = dados['chapters'] as Map<String, dynamic>;
      for (var n = 1; n <= livro.capitulos; n++) {
        final cap = capitulos['$n'] as Map<String, dynamic>?;
        if (cap == null) continue;
        for (final entrada in (cap['verses'] as Map<String, dynamic>).entries) {
          final texto = entrada.value as String;
          if (_normalizar(texto).contains(alvo)) {
            yield Achado(
              livro: livro.slug,
              capitulo: n,
              versiculo: int.parse(entrada.key),
              texto: texto,
            );
            if (++total >= limite) return;
          }
        }
      }
    }
  }

  /// Busca sem acento e sem caixa: procurar "coracao" precisa achar "coração".
  /// Pública porque a tela de busca usa a mesma normalização para realçar o termo
  /// no texto original; duas normalizações diferentes desalinhariam o destaque.
  static String normalizar(String valor) => _normalizar(valor);

  static String _normalizar(String valor) {
    final minusculo = valor.toLowerCase();
    final saida = StringBuffer();
    for (final unidade in minusculo.codeUnits) {
      saida.writeCharCode(_semAcento[unidade] ?? unidade);
    }
    return saida.toString();
  }

  static final Map<int, int> _semAcento = _montarTabelaDeAcentos();

  static Map<int, int> _montarTabelaDeAcentos() {
    const acentuados = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const simples = 'aaaaaeeeeiiiiooooouuuucn';
    final tabela = <int, int>{};
    for (var i = 0; i < acentuados.length; i++) {
      tabela[acentuados.codeUnitAt(i)] = simples.codeUnitAt(i);
    }
    return tabela;
  }
}
