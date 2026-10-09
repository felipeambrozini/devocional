import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';
import 'registro.dart';

/// O que o usuário fez nos livros da biblioteca: onde parou, quais capítulos
/// leu e o que grifou. Vai ao SharedPreferences, um blob JSON por assunto.
///
/// O Estado continua dono da notificação: esta classe chama [aoMudar] nas
/// mudanças que importam aos ouvintes (a sincronia com a nuvem é um deles).
/// Guardar a posição durante a rolagem NÃO avisa, para não acordar a tela e a
/// sincronia a cada pausa do dedo; só a troca de capítulo avisa.
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
  static const _kDestaques = 'livros_destaques';

  final SharedPreferences _prefs;
  final VoidCallback _aoMudar;

  Map<String, PosicaoNoLivro> _posicoes = {};
  Map<String, Set<int>> _lidos = {};
  Map<String, DestaqueDeLivro> _destaques = {};

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

  Future<void> registrarPosicao(
    String slug,
    int capitulo,
    double fracao,
  ) async {
    final mudouDeCapitulo = _posicoes[slug]?.capitulo != capitulo;
    _posicoes[slug] = PosicaoNoLivro(
      capitulo: capitulo,
      fracao: fracao.clamp(0.0, 1.0),
    );
    if (mudouDeCapitulo) _aoMudar();
    await _prefs.setString(
      _kPosicoes,
      json.encode({
        for (final e in _posicoes.entries) e.key: e.value.paraJson(),
      }),
    );
  }

  // --- capítulos lidos ------------------------------------------------------ //

  int quantosLidos(String slug) => _lidos[slug]?.length ?? 0;

  bool foiLido(String slug, int capitulo) =>
      _lidos[slug]?.contains(capitulo) ?? false;

  Future<void> alternarLido(String slug, int capitulo) async {
    final lidos = _lidos[slug] ??= {};
    if (!lidos.remove(capitulo)) lidos.add(capitulo);
    _aoMudar();
    await _prefs.setString(
      _kLidos,
      json.encode({
        for (final e in _lidos.entries) e.key: e.value.toList()..sort(),
      }),
    );
  }

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
    _destaques[base.chave] = (existente ?? base).comNota(nota.trim());
    await _gravarDestaques();
  }

  Future<void> _gravarDestaques() async {
    _aoMudar();
    await _prefs.setString(
      _kDestaques,
      json.encode([for (final d in _destaques.values) d.paraJson()]),
    );
  }
}
