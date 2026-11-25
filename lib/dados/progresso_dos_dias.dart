import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quais capítulos de cada dia do cronograma ou de um plano a pessoa já leu
/// até o fim, para marcar o dia só quando todos estiverem lidos (ver
/// `DiaDaLeitura` e `marcarDiaDaLeituraAoTerminar`).
///
/// Fica no aparelho, não na nuvem: é andamento de um dia, que some quando o
/// dia é marcado. A marca do dia, essa sim, vai para a nuvem como sempre.
class ProgressoDosDias {
  ProgressoDosDias._(this._prefs, this._aoMudar);

  /// Lê o que já estava gravado. Corrompido não impede o app de abrir: perde
  /// só o andamento dos dias, como nas outras leituras do `Estado`.
  factory ProgressoDosDias.ler(SharedPreferences prefs, VoidCallback aoMudar) {
    final progresso = ProgressoDosDias._(prefs, aoMudar);
    progresso._ler();
    return progresso;
  }

  static const _kProgresso = 'progresso_dos_dias';

  /// Quantos dias em andamento guardar. Quem começa um dia e nunca termina
  /// deixaria a lista crescer para sempre; os mais antigos saem primeiro.
  static const maximoDeDias = 60;

  final SharedPreferences _prefs;
  final VoidCallback _aoMudar;

  /// Da chave do dia (`DiaDaLeitura.chaveDoProgresso`) aos capítulos lidos,
  /// na ordem em que o dia começou a ser lido (o mais antigo primeiro).
  final Map<String, Set<String>> _lidos = {};

  void _ler() {
    final cru = _prefs.getString(_kProgresso);
    if (cru == null) return;
    try {
      final dados = json.decode(cru) as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in dados.entries) {
        _lidos[key] = {for (final c in value as List) c as String};
      }
    } catch (_) {
      _lidos.clear();
    }
  }

  Future<void> _gravar() => _prefs.setString(
    _kProgresso,
    json.encode({for (final e in _lidos.entries) e.key: e.value.toList()}),
  );

  /// Os capítulos do dia [chave] já lidos até o fim.
  Set<String> lidosDoDia(String chave) => Set.unmodifiable(_lidos[chave] ?? {});

  /// Registra que [capitulo] do dia [chave] foi lido até o fim.
  Future<void> registrar(String chave, String capitulo) async {
    final lidos = _lidos.remove(chave) ?? <String>{};
    // Reinsere no fim: o dia mexido por último é o último a sair do limite.
    _lidos[chave] = lidos;
    if (!lidos.add(capitulo)) return;
    while (_lidos.length > maximoDeDias) {
      _lidos.remove(_lidos.keys.first);
    }
    _aoMudar();
    await _gravar();
  }

  /// Esquece o andamento de todos os dias, ao sair da conta (ver
  /// `Estado.limparDadosPessoais`). Não avisa: quem limpa avisa uma vez só.
  Future<void> limpar() async {
    _lidos.clear();
    await _prefs.remove(_kProgresso);
  }

  /// Esquece o andamento do dia [chave] (depois de marcado como lido).
  Future<void> esquecer(String chave) async {
    if (_lidos.remove(chave) == null) return;
    _aoMudar();
    await _gravar();
  }
}
