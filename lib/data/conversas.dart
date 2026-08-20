import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';
import 'personas.dart';
import 'registro.dart';

/// Histórico das conversas do chat: cada persona guarda quantas conversas
/// quiser (ver `lib/data/modelos.dart`), com as lápides de exclusão e a fusão
/// com a cópia da nuvem. Vai sempre ao SharedPreferences, e quem entra na
/// conta na web também o sincroniza na nuvem (ver `nuvem.dart`).
///
/// Antes havia uma conversa só por persona, e a chave era o id dela. O formato
/// antigo (persona → lista de mensagens) é migrado na leitura para uma única
/// conversa com id fixo (`conversa-<persona>`), e as lápides antigas (por
/// persona) migram junto; assim o histórico de quem já conversava não se perde
/// nem "ressuscita" uma exclusão feita antes da atualização.
///
/// As regras de negócio continuam as de sempre: a lápide vence a conversa, e
/// a conversa mais nova vence a lápide. O Estado continua dono da persistência
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
  static const maxMensagensPorConversa = 120;

  /// O id que a migração do formato antigo dá à conversa única de cada persona.
  static String _idDeConversaMigrada(String persona) => 'conversa-$persona';

  /// As personas conhecidas, para distinguir uma chave antiga de lápide (era o
  /// id da persona) de uma chave nova (o id da conversa). Quem é persona vira
  /// a conversa migrada na leitura.
  static final _idsDePersonas = {personaSpurgeon.id, personaFelipe.id};

  final SharedPreferences _prefs;
  final VoidCallback _aoMudar;

  /// Persona → conversas. A lista não tem ordem garantida; quem mostra ordena
  /// com [conversasDe].
  Map<String, List<Conversa>> _conversas = {};

  /// Lápides das conversas apagadas: id da conversa → momento da exclusão. É o
  /// que impede a fusão com a nuvem de "ressuscitar" uma conversa que o usuário
  /// apagou: enquanto a lápide for mais nova que o histórico do outro lado, o
  /// remoto é descartado. Uma conversa que continuou em outro aparelho depois
  /// da exclusão volta, porque aí a lápide é mais velha que a conversa.
  Map<String, int> _apagadas = {};

  /// A chave de uma lápide, migrando o formato antigo: lápide por persona vira
  /// lápide da conversa migrada daquela persona.
  String _chaveDeLapide(String chave) =>
      _idsDePersonas.contains(chave) ? _idDeConversaMigrada(chave) : chave;

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
              if (e.value is! int) continue;
              _apagadas[_chaveDeLapide(e.key)] = e.value as int;
            }
          }
          continue;
        }
        if (entrada.value is List) {
          // Formato antigo: uma conversa só por persona, o histórico era a
          // própria lista de mensagens. Vira uma conversa com id fixo.
          final mensagens = [
            for (final item in entrada.value as List)
              if (item is Map<String, dynamic>) Mensagem.doJson(item),
          ];
          if (mensagens.isEmpty) continue;
          (_conversas[entrada.key] ??= []).add(
            Conversa(
              id: _idDeConversaMigrada(entrada.key),
              titulo: _primeiraPergunta(mensagens),
              momento: mensagens.last.momento,
              mensagens: mensagens,
            ),
          );
          continue;
        }
        if (entrada.value is! Map<String, dynamic>) continue;
        final lista = _conversas[entrada.key] ??= [];
        for (final e in (entrada.value as Map<String, dynamic>).entries) {
          if (e.value is! Map<String, dynamic>) continue;
          final conversa = Conversa.doJson(e.value);
          if (conversa.id.isEmpty) continue;
          lista.add(conversa);
        }
      }
    } catch (erro, pilha) {
      Registro.erro('Conversas.ler', erro, pilha);
      _conversas = {};
      _apagadas = {};
    }
  }

  /// A primeira fala do visitante, para virar o título da conversa.
  static String _primeiraPergunta(List<Mensagem> mensagens) {
    for (final m in mensagens) {
      if (m.doUsuario) return m.texto;
    }
    return '';
  }

  /// As conversas da persona, da mais recente para a mais antiga.
  List<Conversa> conversasDe(String persona) {
    final lista = [...(_conversas[persona] ?? const <Conversa>[])];
    lista.sort((a, b) => b.momento.compareTo(a.momento));
    return List.unmodifiable(lista);
  }

  Conversa? conversaDe(String persona, String conversaId) {
    for (final c in _conversas[persona] ?? const <Conversa>[]) {
      if (c.id == conversaId) return c;
    }
    return null;
  }

  /// O histórico da conversa, na ordem em que foi conversado.
  List<Mensagem> mensagensDe(String persona, String conversaId) {
    final conversa = conversaDe(persona, conversaId);
    if (conversa == null) return const [];
    return List.unmodifiable(conversa.mensagens);
  }

  /// Uma conversa nova e vazia, já com o título da primeira pergunta. O chat
  /// chama isto na primeira mensagem e passa a registrar nela; a conversa só
  /// existe no histórico depois de alguém falar.
  Future<Conversa> novaConversa(String persona, {required String titulo}) async {
    final conversa = Conversa(
      id: _novoIdDeConversa(),
      titulo: titulo,
      momento: DateTime.now().millisecondsSinceEpoch,
      mensagens: [],
    );
    (_conversas[persona] ??= []).add(conversa);
    _aoMudar();
    await _gravar();
    return conversa;
  }

  Future<void> registrarMensagem(
    String persona,
    String conversaId,
    Mensagem mensagem,
  ) async {
    // Uma resposta que ainda voava quando a conversa foi apagada não pode
    // ressuscitá-la: a lápide manda.
    if (_apagadas.containsKey(conversaId)) return;
    var conversa = conversaDe(persona, conversaId);
    if (conversa == null) {
      // Quem registra direto (testes, uma mensagem que chegou sem a conversa
      // em memória) ganha a conversa na hora, com o título da primeira fala.
      conversa = Conversa(
        id: conversaId,
        titulo: mensagem.doUsuario ? mensagem.texto : '',
        momento: mensagem.momento,
        mensagens: [],
      );
      (_conversas[persona] ??= []).add(conversa);
    } else {
      _conversas[persona]!.remove(conversa);
    }
    _conversas[persona]!.add(
      conversa.comMensagem(mensagem, teto: maxMensagensPorConversa),
    );
    _aoMudar();
    await _gravar();
  }

  /// Limpa a resposta interrompida das perguntas da conversa.
  ///
  /// Uma pergunta é registrada com [Mensagem.pendente] e só deixa de ser
  /// quando a resposta chega, ou quando o usuário envia outra pergunta e
  /// segue a vida. Vem da tela do chat; este bloco não sabe o que é uma
  /// resposta, só sabe marcar e desmarcar.
  Future<void> marcarRespondidas(String persona, String conversaId) async {
    final conversa = conversaDe(persona, conversaId);
    if (conversa == null) return;
    var mudou = false;
    final novas = <Mensagem>[];
    for (final mensagem in conversa.mensagens) {
      if (!mensagem.pendente) {
        novas.add(mensagem);
        continue;
      }
      mudou = true;
      novas.add(
        Mensagem(
          id: mensagem.id,
          papel: mensagem.papel,
          texto: mensagem.texto,
          momento: mensagem.momento,
        ),
      );
    }
    if (!mudou) return;
    _conversas[persona]!.remove(conversa);
    _conversas[persona]!.add(
      Conversa(
        id: conversa.id,
        titulo: conversa.titulo,
        momento: conversa.momento,
        mensagens: novas,
      ),
    );
    _aoMudar();
    await _gravar();
  }

  /// Apaga só a conversa pedida. A lápide é registrada sempre, mesmo sem
  /// histórico local: apagar num aparelho tem de alcançar a cópia da nuvem,
  /// que pode ter mensagens que este aparelho nunca viu. Sem ela, o remoto
  /// ressuscitaria a conversa.
  Future<void> limparConversa(String persona, String conversaId) async {
    final lista = _conversas[persona];
    if (lista != null) {
      lista.removeWhere((c) => c.id == conversaId);
      // Persona sem conversa nenhuma não aparece mais na serialização: a
      // cópia fica só com as lápides, como antes do multi-conversas.
      if (lista.isEmpty) _conversas.remove(persona);
    }
    _apagadas[conversaId] = DateTime.now().millisecondsSinceEpoch;
    _aoMudar();
    await _gravar();
  }

  /// Apaga todas as conversas da persona, cada uma com a própria lápide.
  Future<void> limparTodasDe(String persona) async {
    final lista = _conversas.remove(persona);
    if (lista == null || lista.isEmpty) return;
    final agora = DateTime.now().millisecondsSinceEpoch;
    for (final c in lista) {
      _apagadas[c.id] = agora;
    }
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
      e.key: {for (final c in e.value) c.id: c.paraJson()},
    if (_apagadas.isNotEmpty) 'apagadas': Map<String, dynamic>.from(_apagadas),
  });

  /// Funde o histórico remoto com o local, por id de conversa e de mensagem:
  /// uma conversa que já existe aqui não é duplicada, e nada que existia só
  /// num dos lados se perde. Lixo remoto é engolido, como em `importar()`.
  ///
  /// O remoto pode chegar no formato antigo (persona → lista de mensagens):
  /// é migrado para a conversa única `conversa-<persona>`, exatamente como a
  /// leitura local, para uma conversa iniciada antes da atualização continuar
  /// sendo a mesma nos dois aparelhos.
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
          if (e.value is int) {
            lapidesRemotas[_chaveDeLapide(e.key)] = e.value as int;
          }
        }
      }

      final remotas = <(String, Conversa)>[];
      for (final entrada in mapa.entries) {
        if (entrada.key == 'apagadas') continue;
        if (entrada.value is List) {
          final mensagens = [
            for (final item in entrada.value as List)
              if (item is Map<String, dynamic>) Mensagem.doJson(item),
          ];
          if (mensagens.isEmpty) continue;
          remotas.add((
            entrada.key,
            Conversa(
              id: _idDeConversaMigrada(entrada.key),
              titulo: _primeiraPergunta(mensagens),
              momento: mensagens.last.momento,
              mensagens: mensagens,
            ),
          ));
        } else if (entrada.value is Map<String, dynamic>) {
          for (final e in (entrada.value as Map<String, dynamic>).entries) {
            if (e.value is! Map<String, dynamic>) continue;
            final conversa = Conversa.doJson(e.value);
            if (conversa.id.isEmpty) continue;
            remotas.add((entrada.key, conversa));
          }
        }
      }

      var mudou = false;

      // Uma exclusão pode chegar sem conversa por trás: o aparelho que apagou
      // empurra só a lápide. Sem este passe, o reencontro a ignoraria, a
      // conversa antiga ficaria aqui e voltaria a subir na próxima mudança.
      for (final entrada in lapidesRemotas.entries) {
        final id = entrada.key;
        if (remotas.any((r) => r.$2.id == id)) continue;
        final local = _acharLocal(id);
        final lapideLocal = _apagadas[id];
        if (local == null) {
          if (lapideLocal == null || entrada.value > lapideLocal) {
            _apagadas[id] = entrada.value;
            mudou = true;
          }
          continue;
        }
        if (entrada.value <= local.$2.momento) continue;
        _conversas[local.$1]!.remove(local.$2);
        if (lapideLocal == null || entrada.value > lapideLocal) {
          _apagadas[id] = entrada.value;
        }
        mudou = true;
      }

      for (final (persona, remota) in remotas) {
        final id = remota.id;
        final lapideLocal = _apagadas[id];
        final lapideRemota = lapidesRemotas[id];
        final local = _acharLocal(id);
        final localMaisNovo = local?.$2.momento ?? -1;

        if (lapideRemota != null &&
            lapideRemota >= remota.momento &&
            lapideRemota > localMaisNovo) {
          // A exclusão do outro lado é mais nova que todo o histórico local:
          // apaga aqui também, e a lápide passa a ser a mais nova das duas.
          if (local != null) _conversas[local.$1]!.remove(local.$2);
          if (lapideLocal == null || lapideRemota > lapideLocal) {
            _apagadas[id] = lapideRemota;
          }
          mudou = true;
          continue;
        }
        if (lapideLocal != null && remota.momento <= lapideLocal) {
          // Apaguei aqui e o remoto não traz nada mais novo: fica apagado.
          continue;
        }
        if (lapideLocal != null) {
          // O outro lado continuou a conversa depois da exclusão: ela volta
          // inteira, e a lápide deixa de valer para sempre.
          _apagadas.remove(id);
          mudou = true;
        }

        final lista = _conversas[persona] ??= [];
        var conversa = lista.where((c) => c.id == id).firstOrNull;
        if (conversa == null) {
          conversa = Conversa(
            id: id,
            titulo: remota.titulo,
            momento: remota.momento,
            mensagens: [],
          );
          lista.add(conversa);
          mudou = true;
        }

        final ids = conversa.mensagens.map((m) => m.id).toSet();
        var mudouNesta = false;
        final novas = <Mensagem>[
          for (final m in remota.mensagens)
            if (m.id.isNotEmpty && ids.add(m.id)) m,
        ];
        if (novas.isNotEmpty) {
          conversa = conversa.comMensagemDeTodas(novas, teto: maxMensagensPorConversa);
          lista[lista.indexWhere((c) => c.id == id)] = conversa;
          mudouNesta = true;
        }
        if (mudouNesta) {
          if (conversa.titulo.isEmpty && remota.titulo.isNotEmpty) {
            conversa = conversa.comTitulo(remota.titulo);
            lista[lista.indexWhere((c) => c.id == id)] = conversa;
          }
          mudou = true;
        }
      }

      if (mudou) {
        _aoMudar();
        await _gravar();
      }
    } catch (erro, pilha) {
      // Cópia ilegível: o local continua intacto e vai subir por cima.
      Registro.erro('Conversas.fundirDaNuvem', erro, pilha);
    }
  }

  /// A conversa local com aquele id, e a persona dela. Busca em todas as
  /// personas porque o id da conversa é único.
  (String, Conversa)? _acharLocal(String id) {
    for (final e in _conversas.entries) {
      for (final c in e.value) {
        if (c.id == id) return (e.key, c);
      }
    }
    return null;
  }

  String _novoIdDeConversa() {
    final agora = DateTime.now().millisecondsSinceEpoch;
    return 'c$agora-${Random().nextInt(0x7FFFFFFF)}';
  }
}