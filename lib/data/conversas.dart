import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';

/// Histórico das conversas do chat, indexado pelo id da persona (ver
/// `lib/data/personas.dart`), com as lápides de exclusão e a fusão com a
/// cópia da nuvem. Vai sempre ao SharedPreferences, e quem entra na conta na
/// web também o sincroniza na nuvem (ver `nuvem.dart`).
///
/// Saiu de `estado.dart` num refactor: era o bloco mais denso do Estado e o
/// único com regra de negócio própria (a lápide vence a conversa, e a
/// conversa mais nova vence a lápide). O Estado continua dono da persistência
/// e da notificação: esta classe chama [aoMudar] em toda mutação, e o Estado
/// repassa aos próprios ouvintes — a sincronia com a nuvem é um deles, e é o
/// que faz a mudança subir sozinha.
class Conversas {
  Conversas._(this._prefs, this._aoMudar);

  /// Lê o que já estava gravado. Corrompido não impede o app de abrir;
  /// perde-se a conversa, não a fé (mesma regra das marcações no Estado).
  factory Conversas.ler(SharedPreferences prefs, VoidCallback aoMudar) {
    final conversas = Conversas._(prefs, aoMudar);
    conversas._ler();
    return conversas;
  }

  static const _chave = 'conversas';

  /// Teto de mensagens por conversa. O histórico inteiro volta ao modelo a
  /// cada pergunta, então a cauda antiga além disto custa contexto sem ganhar
  /// qualidade; também segura o tamanho do documento no Firestore.
  static const _maxMensagensPorConversa = 120;

  final SharedPreferences _prefs;
  final VoidCallback _aoMudar;

  Map<String, List<Mensagem>> _conversas = {};

  /// Lápides das conversas apagadas: persona → momento da exclusão. É o que
  /// impede a fusão com a nuvem de "ressuscitar" uma conversa que o usuário
  /// apagou: enquanto a lápide for mais nova que o histórico do outro lado,
  /// o remoto é descartado. Uma conversa que continuou em outro aparelho
  /// depois da exclusão volta, porque aí a lápide é mais velha que a
  /// conversa, e o que o usuário apagou era só a cópia antiga.
  Map<String, int> _apagadas = {};

  void _ler() {
    final cruas = _prefs.getString(_chave);
    if (cruas == null || cruas.isEmpty) return;
    try {
      final mapa = json.decode(cruas) as Map<String, dynamic>;
      _conversas = {};
      _apagadas = {};
      for (final entrada in mapa.entries) {
        if (entrada.key == 'apagadas') {
          final apagadas = entrada.value;
          if (apagadas is Map<String, dynamic>) {
            for (final e in apagadas.entries) {
              if (e.value is int) _apagadas[e.key] = e.value as int;
            }
          }
          continue;
        }
        if (entrada.value is! List) continue;
        _conversas[entrada.key] = [
          for (final item in entrada.value as List)
            if (item is Map<String, dynamic>) Mensagem.doJson(item),
        ];
      }
    } catch (_) {
      _conversas = {};
      _apagadas = {};
    }
  }

  /// O histórico da persona, na ordem em que foi conversado.
  List<Mensagem> mensagensDe(String persona) =>
      List.unmodifiable(_conversas[persona] ?? const []);

  Future<void> registrarMensagem(String persona, Mensagem mensagem) async {
    final lista = _conversas[persona] ??= [];
    lista.add(mensagem);
    if (lista.length > _maxMensagensPorConversa) {
      lista.removeRange(0, lista.length - _maxMensagensPorConversa);
    }
    _aoMudar();
    await _gravar();
  }

  /// Limpa a resposta interrompida das perguntas da persona.
  ///
  /// Uma pergunta é registrada com [Mensagem.pendente] e só deixa de ser
  /// quando a resposta chega, ou quando o usuário envia outra pergunta e
  /// segue a vida. Vem da tela do chat; este bloco não sabe o que é uma
  /// resposta, só sabe marcar e desmarcar.
  Future<void> marcarRespondidas(String persona) async {
    final lista = _conversas[persona];
    if (lista == null) return;
    var mudou = false;
    for (var i = 0; i < lista.length; i++) {
      final mensagem = lista[i];
      if (!mensagem.pendente) continue;
      // Mensagem é imutável; troca-se a instância no lugar da antiga.
      lista[i] = Mensagem(
        id: mensagem.id,
        papel: mensagem.papel,
        texto: mensagem.texto,
        momento: mensagem.momento,
      );
      mudou = true;
    }
    if (!mudou) return;
    _aoMudar();
    await _gravar();
  }

  Future<void> limparConversa(String persona) async {
    // A lápide é registrada sempre, mesmo sem histórico local: apagar no
    // celular tem de alcançar a cópia da nuvem, que pode ter mensagens que
    // este aparelho nunca viu. Sem ela, o remoto ressuscitaria a conversa.
    _apagadas[persona] = DateTime.now().millisecondsSinceEpoch;
    _conversas.remove(persona);
    _aoMudar();
    await _gravar();
  }

  Future<void> _gravar() async {
    await _prefs.setString(_chave, serializarConversas());
  }

  /// O que a cópia na nuvem recebe para as conversas, num JSON à parte do
  /// `exportar()`: o histórico não entra na cópia de segurança manual que se
  /// exporta e importa, porque aquela é sobre trabalho do usuário (notas,
  /// favoritos) e esta é só o cache do chat entre aparelhos.
  ///
  /// O mesmo texto vai ao SharedPreferences via [_gravar]: uma escrita só, e
  /// a lápide viaja com o histórico nos dois caminhos.
  String serializarConversas() => json.encode({
    for (final e in _conversas.entries)
      e.key: [for (final m in e.value) m.paraJson()],
    if (_apagadas.isNotEmpty) 'apagadas': Map<String, dynamic>.from(_apagadas),
  });

  /// Funde o histórico remoto com o local, por id de mensagem: uma mensagem
  /// que já existe aqui não é duplicada, e nada que existia só num dos lados
  /// se perde. Lixo remoto é engolido, como em `importar()`.
  ///
  /// As lápides de exclusão (`apagadas`) entram na regra: a exclusão mais
  /// nova vence, e a conversa mais nova vence a exclusão. Assim apagar numa
  /// conta não ressuscita no reencontro com a nuvem, e uma conversa que
  /// continuou em outro aparelho depois da exclusão volta inteira.
  Future<void> fundirConversas(String remota) async {
    try {
      final mapa = json.decode(remota) as Map<String, dynamic>;
      final lapidesRemotas = <String, int>{};
      final apagadas = mapa['apagadas'];
      if (apagadas is Map<String, dynamic>) {
        for (final e in apagadas.entries) {
          if (e.value is int) lapidesRemotas[e.key] = e.value as int;
        }
      }
      var mudou = false;
      // Uma exclusão pode chegar sem mensagem nenhuma: o aparelho que apagou
      // empurra só a lápide. Sem este passe, o reencontro a ignoraria, a
      // conversa antiga ficaria aqui e voltaria a subir na próxima mudança.
      for (final entrada in lapidesRemotas.entries) {
        final remoto = mapa[entrada.key];
        if (remoto is List && remoto.isNotEmpty) continue;
        final persona = entrada.key;
        final lapideRemota = entrada.value;
        var localMaisNovo = -1;
        for (final m in (_conversas[persona] ?? const <Mensagem>[])) {
          if (m.momento > localMaisNovo) localMaisNovo = m.momento;
        }
        if (lapideRemota <= localMaisNovo) {
          // A conversa local continuou depois da exclusão remota: prevalece.
          continue;
        }
        if (_conversas.remove(persona) != null) mudou = true;
        final lapideLocal = _apagadas[persona];
        if (lapideLocal == null || lapideRemota > lapideLocal) {
          _apagadas[persona] = lapideRemota;
          mudou = true;
        }
      }
      for (final entrada in mapa.entries) {
        if (entrada.key == 'apagadas') continue;
        if (entrada.value is! List) continue;
        final remotos = [...entrada.value as List];
        if (remotos.isEmpty) continue;
        final persona = entrada.key;
        final local = [...(_conversas[persona] ?? const <Mensagem>[])];
        final lapideLocal = _apagadas[persona];
        final lapideRemota = lapidesRemotas[persona];

        var novoMaisNovo = -1;
        for (final cru in remotos) {
          if (cru is! Map<String, dynamic>) continue;
          final momento = cru['momento'];
          if (momento is int && momento > novoMaisNovo) novoMaisNovo = momento;
        }
        var localMaisNovo = -1;
        for (final m in local) {
          if (m.momento > localMaisNovo) localMaisNovo = m.momento;
        }

        if (lapideRemota != null &&
            lapideRemota >= novoMaisNovo &&
            lapideRemota > localMaisNovo) {
          // A exclusão do outro lado é mais nova que todo o histórico local:
          // apaga aqui também, e a lápide passa a ser a mais nova das duas.
          if (_conversas.remove(persona) != null) mudou = true;
          if (lapideLocal == null || lapideRemota > lapideLocal) {
            _apagadas[persona] = lapideRemota;
            mudou = true;
          }
          continue;
        }
        if (lapideLocal != null && novoMaisNovo <= lapideLocal) {
          // Apaguei aqui e o remoto não traz nada mais novo: fica apagado.
          continue;
        }
        if (lapideLocal != null) {
          // O outro lado continuou a conversa depois da exclusão: ela volta
          // inteira, e a lápide deixa de valer para sempre.
          _apagadas.remove(persona);
          mudou = true;
        }

        final ids = local.map((m) => m.id).toSet();
        var mudouNesta = false;
        for (final cru in remotos) {
          if (cru is! Map<String, dynamic>) continue;
          final mensagem = Mensagem.doJson(cru);
          if (mensagem.id.isEmpty || !ids.add(mensagem.id)) continue;
          local.add(mensagem);
          mudouNesta = true;
        }
        if (mudouNesta) {
          local.sort((a, b) => a.momento.compareTo(b.momento));
          if (local.length > _maxMensagensPorConversa) {
            local.removeRange(0, local.length - _maxMensagensPorConversa);
          }
          _conversas[persona] = local;
          mudou = true;
        }
      }
      if (mudou) {
        _aoMudar();
        await _gravar();
      }
    } catch (_) {
      // Cópia ilegível: o local continua intacto e vai subir por cima.
    }
  }
}