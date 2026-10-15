import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:shared_preferences/shared_preferences.dart';

import 'biblioteca.dart';
import 'modelos.dart';
import 'registro.dart';

/// O que o usuário fez nos livros da biblioteca: onde parou, quais capítulos
/// leu, quantas vezes terminou cada livro e o que grifou. Vai ao
/// SharedPreferences, um blob JSON por assunto, e quem entra na conta também o
/// sincroniza na nuvem (ver [serializar], [fundir] e `nuvem.dart`).
///
/// O Estado continua dono da notificação: esta classe chama [aoMudar] nas
/// mudanças que importam aos ouvintes (a sincronia com a nuvem é um deles).
/// Guardar a posição durante a rolagem só avisa quando o capítulo ou o livro
/// muda, ou quando a rolagem andou um quarto do capítulo: avisar a cada pausa
/// do dedo acordaria a tela inteira e a sincronia sem necessidade.
class LeituraDeLivros {
  LeituraDeLivros._(this._prefs, this._aoMudar);

  /// Lê o que já estava gravado. Corrompido não impede o app de abrir: perde-se
  /// aquele assunto, não o app (mesma regra das marcações no Estado).
  factory LeituraDeLivros.ler(SharedPreferences prefs, VoidCallback aoMudar) {
    final leitura = LeituraDeLivros._(prefs, aoMudar);
    leitura._ler();
    return leitura;
  }

  static const _kPosicoes = 'livros_posicoes';
  static const _kLidos = 'livros_lidos';
  static const _kConcluidas = 'livros_concluidas';
  static const _kDestaques = 'livros_destaques';

  /// Versão do formato da cópia na nuvem, para ler uma cópia velha se mudar.
  static const _versaoDaCopia = 1;

  /// Quanto a rolagem precisa andar (fração do capítulo) para avisar os
  /// ouvintes e, por eles, a nuvem.
  static const _passoParaAvisar = 0.25;

  /// Maior nota guardada, em caracteres: o documento da conta tem teto de 1 MiB
  /// para tudo (cópia, conversas, planos e livros), e nota sem limite o encheria.
  static const tamanhoMaximoDaNota = 2000;

  // Tetos do que se aceita de uma cópia vinda da conta, que é dado de fora.
  static const _tetoDePosicoes = 10000;
  static const _tetoDeLeituras = 1000;
  static const _umDiaEmMs = 24 * 60 * 60 * 1000;

  static String _limitarNota(String nota) =>
      nota.runes.length <= tamanhoMaximoDaNota
      ? nota
      : String.fromCharCodes(nota.runes.take(tamanhoMaximoDaNota));

  /// Um carimbo de tempo não pode estar mais de um dia no futuro: um relógio
  /// errado em outro aparelho ganharia todas as fusões seguintes.
  static int _semFuturo(int em) =>
      min(em, DateTime.now().millisecondsSinceEpoch + _umDiaEmMs);

  final SharedPreferences _prefs;
  final VoidCallback _aoMudar;

  Map<String, PosicaoNoLivro> _posicoes = {};
  Map<String, Set<int>> _lidos = {};

  /// Quantas vezes cada livro foi terminado. Na fusão com a nuvem, a "volta"
  /// maior vence: um livro terminado em outro aparelho não ressuscita aqui
  /// como se estivesse na metade.
  Map<String, int> _concluidas = {};
  Map<String, DestaqueDeLivro> _destaques = {};

  /// Fração da última rolagem que avisou os ouvintes, por livro. Só da sessão.
  final Map<String, double> _fracaoAvisada = {};

  int _ultimoEm = 0;

  /// Agora em milissegundos, sempre maior que o anterior: duas gravações no
  /// mesmo milissegundo não podem empatar a ordem dos livros nem a fusão.
  int _agora() {
    final agora = DateTime.now().millisecondsSinceEpoch;
    return _ultimoEm = agora > _ultimoEm ? agora : _ultimoEm + 1;
  }

  void _ler() {
    _posicoes = _lerAssunto(_kPosicoes, (cru) {
      final mapa = json.decode(cru) as Map<String, dynamic>;
      return {
        for (final e in mapa.entries)
          e.key: PosicaoNoLivro.doJson(e.value as Map<String, dynamic>),
      };
    }, {});
    _lidos = _lerAssunto(_kLidos, (cru) {
      final mapa = json.decode(cru) as Map<String, dynamic>;
      return {
        for (final e in mapa.entries)
          e.key: {for (final c in e.value as List) c as int},
      };
    }, {});
    _concluidas = _lerAssunto(_kConcluidas, (cru) {
      final mapa = json.decode(cru) as Map<String, dynamic>;
      return {for (final e in mapa.entries) e.key: e.value as int};
    }, {});
    _destaques = _lerAssunto(_kDestaques, (cru) {
      final destaques = [
        for (final item in json.decode(cru) as List)
          DestaqueDeLivro.doJson(item as Map<String, dynamic>),
      ];
      return {for (final d in destaques) d.chave: d};
    }, {});
  }

  T _lerAssunto<T>(String chave, T Function(String cru) converter, T vazio) {
    final cru = _prefs.getString(chave);
    if (cru == null || cru.isEmpty) return vazio;
    try {
      return converter(cru);
    } catch (erro, pilha) {
      Registro.erro('LeituraDeLivros.ler($chave)', erro, pilha);
      return vazio;
    }
  }

  // --- onde parou ---------------------------------------------------------- //

  PosicaoNoLivro? posicaoDe(String slug) => _posicoes[slug];

  /// Os livros que o usuário começou a ler, do mais recente ao mais antigo.
  List<String> get livrosEmLeitura {
    final recentes = _posicoes.entries.toList()
      ..sort((a, b) => b.value.em.compareTo(a.value.em));
    return [for (final e in recentes) e.key];
  }

  /// O livro em que se leu por último, ou nulo se nenhum foi iniciado.
  String? get ultimoLivro => livrosEmLeitura.firstOrNull;

  Future<void> registrarPosicao(
    String slug,
    int capitulo,
    double fracao,
  ) async {
    final mudouDeCapitulo = _posicoes[slug]?.capitulo != capitulo;
    final deixouDeSerOUltimo = ultimoLivro != slug;
    final andou =
        (fracao - (_fracaoAvisada[slug] ?? 0)).abs() >= _passoParaAvisar;
    _posicoes[slug] = PosicaoNoLivro(
      capitulo: capitulo,
      fracao: fracao.clamp(0.0, 1.0),
      em: _agora(),
    );
    if (mudouDeCapitulo || deixouDeSerOUltimo || andou) {
      _fracaoAvisada[slug] = fracao;
      _aoMudar();
    }
    await _gravarPosicoes();
  }

  // --- capítulos lidos e leituras concluídas -------------------------------- //

  int quantosLidos(String slug) => _lidos[slug]?.length ?? 0;

  bool foiLido(String slug, int capitulo) =>
      _lidos[slug]?.contains(capitulo) ?? false;

  /// Quantas vezes o livro foi terminado.
  int vezesConcluido(String slug) => _concluidas[slug] ?? 0;

  Future<void> alternarLido(String slug, int capitulo) async {
    final lidos = _lidos[slug] ??= {};
    if (!lidos.remove(capitulo)) lidos.add(capitulo);
    _aoMudar();
    await _gravarLidos();
  }

  /// Termina a leitura do livro e a recomeça: o livro sai de "em leitura", a
  /// posição e os capítulos lidos voltam ao zero e a contagem de leituras
  /// concluídas sobe. Destaques e notas ficam: são trabalho do usuário, e
  /// valem também na próxima leitura.
  Future<void> concluir(String slug) async {
    _concluidas[slug] = vezesConcluido(slug) + 1;
    _posicoes.remove(slug);
    _lidos.remove(slug);
    _fracaoAvisada.remove(slug);
    _aoMudar();
    await _gravarPosicoes();
    await _gravarLidos();
    await _gravarConcluidas();
  }

  Future<void> _gravarPosicoes() => _prefs.setString(
    _kPosicoes,
    json.encode({for (final e in _posicoes.entries) e.key: e.value.paraJson()}),
  );

  Future<void> _gravarLidos() => _prefs.setString(
    _kLidos,
    json.encode({
      for (final e in _lidos.entries) e.key: e.value.toList()..sort(),
    }),
  );

  Future<void> _gravarConcluidas() =>
      _prefs.setString(_kConcluidas, json.encode(_concluidas));

  // --- destaques e notas ---------------------------------------------------- //

  /// Os destaques de um capítulo, por índice do parágrafo.
  Map<int, DestaqueDeLivro> destaquesDe(String slug, int capitulo) => {
    for (final d in _destaques.values)
      if (d.slug == slug && d.capitulo == capitulo) d.paragrafo: d,
  };

  /// Todos os destaques de todos os livros, do mais antigo no livro ao mais
  /// novo, para uma listagem estável.
  List<DestaqueDeLivro> get todosOsDestaques =>
      _destaques.values.toList()..sort(_porPosicaoNoLivro);

  static int _porPosicaoNoLivro(DestaqueDeLivro a, DestaqueDeLivro b) {
    final porLivro = a.slug.compareTo(b.slug);
    if (porLivro != 0) return porLivro;
    final porCapitulo = a.capitulo.compareTo(b.capitulo);
    return porCapitulo != 0 ? porCapitulo : a.paragrafo.compareTo(b.paragrafo);
  }

  /// Grifa o parágrafo, ou tira o grifo. Um destaque com nota permanece: a
  /// nota é trabalho do usuário, e desmarcar a apagaria junto (mesma regra de
  /// `Estado.alternarFavorito`).
  Future<void> alternarDestaque(
    String slug,
    int capitulo,
    int paragrafo,
  ) async {
    final novo = DestaqueDeLivro(
      slug: slug,
      capitulo: capitulo,
      paragrafo: paragrafo,
      em: _agora(),
    );
    final existente = _destaques[novo.chave];
    if (existente == null) {
      _destaques[novo.chave] = novo;
    } else if (existente.nota.trim().isEmpty) {
      _destaques.remove(novo.chave);
    } else {
      return;
    }
    await _gravarDestaques();
  }

  /// Define a nota do parágrafo, grifando-o se ainda não estava. Nota vazia
  /// limpa a nota e mantém o grifo.
  Future<void> definirNota(
    String slug,
    int capitulo,
    int paragrafo,
    String nota,
  ) async {
    final base = DestaqueDeLivro(
      slug: slug,
      capitulo: capitulo,
      paragrafo: paragrafo,
    );
    final existente = _destaques[base.chave];
    if (nota.trim().isEmpty && existente == null) return;
    _destaques[base.chave] = (existente ?? base).comNota(
      _limitarNota(nota.trim()),
      _agora(),
    );
    await _gravarDestaques();
  }

  Future<void> _gravarDestaques() async {
    _aoMudar();
    await _prefs.setString(
      _kDestaques,
      json.encode([for (final d in _destaques.values) d.paraJson()]),
    );
  }

  // --- sincronia com a conta ------------------------------------------------ //

  /// Tudo o que a conta guarda dos livros, num JSON estável (chaves em ordem):
  /// o mesmo conteúdo dá o mesmo texto, e a sincronia só envia quando muda.
  String serializar() {
    final slugs = {
      ..._posicoes.keys,
      ..._lidos.keys,
      ..._concluidas.keys,
    }.toList()..sort();
    final destaques = _destaques.values.toList()..sort(_porPosicaoNoLivro);
    return json.encode({
      'versao': _versaoDaCopia,
      'livros': {
        for (final slug in slugs)
          slug: {
            'concluidas': vezesConcluido(slug),
            'posicao': ?_posicoes[slug]?.paraJson(),
            'lidos': [...?_lidos[slug]]..sort(),
          },
      },
      'destaques': [for (final d in destaques) d.paraJson()],
    });
  }

  /// Funde a cópia da conta com o que há aqui, sem perder nada de nenhum lado.
  ///
  /// Por livro: a volta (leituras concluídas) maior vence por inteiro, porque
  /// terminar um livro zera a leitura e não pode ser desfeito por uma cópia
  /// velha; na mesma volta, os capítulos lidos se somam e vale a posição mais
  /// recente. Destaques se somam, e no mesmo parágrafo vale a mudança mais
  /// nova. Tirar um destaque não sincroniza (a cópia de outro aparelho o traria
  /// de volta): a mesma limitação das marcações da Bíblia.
  Future<void> fundir(String remota) async {
    try {
      final mapa = json.decode(remota) as Map<String, dynamic>;
      var mudou = false;

      final livros = mapa['livros'] as Map<String, dynamic>? ?? const {};
      for (final MapEntry(key: slug, value: bruto) in livros.entries) {
        if (_fundirLivro(slug, bruto)) mudou = true;
      }
      for (final item in mapa['destaques'] as List? ?? const []) {
        if (_fundirDestaque(item)) mudou = true;
      }

      if (!mudou) return;
      _aoMudar();
      await _gravarPosicoes();
      await _gravarLidos();
      await _gravarConcluidas();
      await _prefs.setString(
        _kDestaques,
        json.encode([for (final d in _destaques.values) d.paraJson()]),
      );
    } catch (erro, pilha) {
      Registro.erro('LeituraDeLivros.fundir', erro, pilha);
    }
  }

  /// Funde um livro da cópia e diz se algo mudou aqui. A cópia é dado de fora:
  /// livro que não está no catálogo, número fora da faixa ou entrada torta são
  /// ignorados, e uma entrada ruim não impede as outras.
  bool _fundirLivro(String slug, Object? bruto) {
    if (obraPorSlug(slug) == null) return false;
    try {
      final remoto = bruto as Map<String, dynamic>;
      final concluidasRemotas = (remoto['concluidas'] as int? ?? 0).clamp(
        0,
        _tetoDeLeituras,
      );
      final posicaoRemota = remoto['posicao'] is Map<String, dynamic>
          ? _posicaoConfiavel(remoto['posicao'] as Map<String, dynamic>)
          : null;
      final lidosRemotos = {
        for (final c in remoto['lidos'] as List? ?? const [])
          if (c is int && c >= 0 && c < _tetoDePosicoes) c,
      };

      final concluidasLocais = vezesConcluido(slug);
      if (concluidasRemotas > concluidasLocais) {
        _concluidas[slug] = concluidasRemotas;
        if (posicaoRemota == null) {
          _posicoes.remove(slug);
        } else {
          _posicoes[slug] = posicaoRemota;
        }
        if (lidosRemotos.isEmpty) {
          _lidos.remove(slug);
        } else {
          _lidos[slug] = lidosRemotos;
        }
        return true;
      }
      if (concluidasRemotas < concluidasLocais) return false;

      var mudou = false;
      final lidosLocais = _lidos[slug] ?? <int>{};
      if (!lidosLocais.containsAll(lidosRemotos)) {
        _lidos[slug] = {...lidosLocais, ...lidosRemotos};
        mudou = true;
      }
      final posicaoLocal = _posicoes[slug];
      if (posicaoRemota != null &&
          (posicaoLocal == null || posicaoRemota.em > posicaoLocal.em)) {
        _posicoes[slug] = posicaoRemota;
        mudou = true;
      }
      return mudou;
    } catch (erro, pilha) {
      Registro.erro('LeituraDeLivros.fundirLivro($slug)', erro, pilha);
      return false;
    }
  }

  PosicaoNoLivro? _posicaoConfiavel(Map<String, dynamic> json) {
    final posicao = PosicaoNoLivro.doJson(json);
    if (posicao.capitulo < 0 || posicao.capitulo >= _tetoDePosicoes) {
      return null;
    }
    return PosicaoNoLivro(
      capitulo: posicao.capitulo,
      fracao: posicao.fracao,
      em: _semFuturo(posicao.em),
    );
  }

  bool _fundirDestaque(Object? item) {
    try {
      final bruto = DestaqueDeLivro.doJson(item as Map<String, dynamic>);
      final naFaixa =
          bruto.capitulo >= 0 &&
          bruto.capitulo < _tetoDePosicoes &&
          bruto.paragrafo >= 0 &&
          bruto.paragrafo < _tetoDePosicoes;
      if (obraPorSlug(bruto.slug) == null || !naFaixa) return false;
      final remoto = DestaqueDeLivro(
        slug: bruto.slug,
        capitulo: bruto.capitulo,
        paragrafo: bruto.paragrafo,
        nota: _limitarNota(bruto.nota),
        em: _semFuturo(bruto.em),
      );
      final local = _destaques[remoto.chave];
      if (local != null && remoto.em <= local.em) return false;
      _destaques[remoto.chave] = remoto;
      return true;
    } catch (erro, pilha) {
      Registro.erro('LeituraDeLivros.fundirDestaque', erro, pilha);
      return false;
    }
  }
}
