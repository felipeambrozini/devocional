import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'audio_config.dart';
import 'canon.dart';
import 'voz.dart';

/// Gerencia o download dos MP3 pré-gerados para uso offline.
///
/// Ordem pedida pelo usuário: Bíblia, Introdução, Manhã e Noite, Promessas.
/// Cada categoria é um lote de arquivos em `lib/data/voz.dart` (`_urlParaChave`).
/// Web não tem sistema de arquivos: todos os métodos viram no-op.
class AudioOffline extends ChangeNotifier {
  AudioOffline._();
  static final AudioOffline instancia = AudioOffline._();

  bool _baixando = false;
  String? _categoriaAtiva; // biblia, introducao, manha_noite, promessas
  double _progresso = 0; // 0..1 do lote atual
  int _baixadosNoLote = 0;
  int _totalNoLote = 0;
  String? _erro;

  bool get baixando => _baixando;
  String? get categoriaAtiva => _categoriaAtiva;
  double get progresso => _progresso;
  int get baixadosNoLote => _baixadosNoLote;
  int get totalNoLote => _totalNoLote;
  String? get erro => _erro;

  bool get _suportado => !kIsWeb;

  Future<Directory> _dirBase() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/audio_offline');
  }

  String _caminhoLocalParaChave(String chave) =>
      caminhoRelativoParaChave(chave) ??
      '${chave.replaceAll(':', '_').replaceAll('/', '-')}.mp3';

  Future<File> _arquivoLocal(String chave) async {
    final dir = await _dirBase();
    return File('${dir.path}/${_caminhoLocalParaChave(chave)}');
  }

  /// Override para testes: evita bater no path_provider de verdade (sem
  /// plugin registrado em teste de widget). Null usa o caminho real.
  static bool Function(String chave)? temOfflineParaTeste;

  /// Se o arquivo offline já existe para [chave].
  Future<bool> temOffline(String chave) async {
    final paraTeste = temOfflineParaTeste;
    if (paraTeste != null) return paraTeste(chave);
    if (!_suportado) return false;
    final f = await _arquivoLocal(chave);
    return f.exists();
  }

  /// Retorna o caminho do arquivo offline se existir, senão null.
  Future<String?> caminhoOffline(String chave) async {
    if (!_suportado) return null;
    final f = await _arquivoLocal(chave);
    return f.existsSync() ? f.path : null;
  }

  List<String> _chavesDaCategoria(String categoria) {
    switch (categoria) {
      case 'biblia':
        return [
          for (final l in canon)
            for (var c = 1; c <= l.capitulos; c++) chaveDeCapitulo(l.slug, c),
        ];
      case 'introducao':
        return [for (final l in canon) chaveDaIntroducao(l.slug)];
      case 'manha_noite':
        // Todas as datas do ano, 366 dias (ano bissexto) x manhã/noite.
        final chaves = <String>[];
        for (var m = 1; m <= 12; m++) {
          final dias = DateTime(2024, m + 1, 0).day;
          for (var d = 1; d <= dias; d++) {
            chaves.add(chaveDeDevocional('manha', d, m));
            chaves.add(chaveDeDevocional('noite', d, m));
          }
        }
        return chaves;
      case 'promessas':
        final chaves = <String>[];
        for (var m = 1; m <= 12; m++) {
          final dias = DateTime(2024, m + 1, 0).day;
          for (var d = 1; d <= dias; d++) {
            chaves.add(chaveDeDevocional('promessas', d, m));
          }
        }
        return chaves;
      default:
        return [];
    }
  }

  /// Baixa todos os arquivos de [categoria] (biblia, introducao, manha_noite, promessas).
  /// Se AUDIO_BASE_URL não estiver configurada, não faz nada.
  Future<void> baixarCategoria(String categoria, {http.Client? cliente}) async {
    if (!_suportado) return;
    if (_baixando) return;
    final base = audioBaseUrl;
    if (base.isEmpty) {
      _erro = 'AUDIO_BASE_URL não configurada no build.';
      notifyListeners();
      return;
    }
    final chaves = _chavesDaCategoria(categoria);
    _baixando = true;
    _categoriaAtiva = categoria;
    _baixadosNoLote = 0;
    _totalNoLote = chaves.length;
    _progresso = 0;
    _erro = null;
    notifyListeners();

    final httpClient = cliente ?? http.Client();
    var falhou = false;
    for (var i = 0; i < chaves.length; i++) {
      final chave = chaves[i];
      final url = _urlParaChaveHttp(chave, base);
      if (url == null) continue;
      final arquivo = await _arquivoLocal(chave);
      if (await arquivo.exists()) {
        _baixadosNoLote++;
        _progresso = _baixadosNoLote / _totalNoLote;
        notifyListeners();
        continue;
      }
      try {
        final resp = await httpClient.get(Uri.parse(url));
        if (resp.statusCode == 200) {
          await arquivo.parent.create(recursive: true);
          await arquivo.writeAsBytes(resp.bodyBytes);
        } else {
          falhou = true;
          _erro = 'Falha em $chave: ${resp.statusCode}';
        }
      } catch (e) {
        falhou = true;
        _erro = 'Erro em $chave: $e';
      }
      _baixadosNoLote++;
      _progresso = _baixadosNoLote / _totalNoLote;
      notifyListeners();
      // Evita sobrecarregar a rede/storage.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _baixando = false;
    _categoriaAtiva = null;
    if (!falhou) _erro = null;
    notifyListeners();
  }

  String? _urlParaChaveHttp(String chave, String base) {
    final relativo = caminhoRelativoParaChave(chave);
    if (relativo == null) return null;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$b/$relativo';
  }

  /// Apaga todos os arquivos offline de [categoria].
  Future<void> apagarCategoria(String categoria) async {
    if (!_suportado) return;
    final dir = await _dirBase();
    final sub = switch (categoria) {
      'biblia' => 'biblia',
      'introducao' => 'introducao',
      'manha_noite' => 'devocionais/manha_e_noite',
      'promessas' => 'devocionais/promessas_de_deus',
      _ => null,
    };
    if (sub == null) return;
    final alvo = Directory('${dir.path}/$sub');
    if (await alvo.exists()) await alvo.delete(recursive: true);
    notifyListeners();
  }

  /// Apaga tudo.
  Future<void> apagarTudo() async {
    if (!_suportado) return;
    final dir = await _dirBase();
    if (await dir.exists()) await dir.delete(recursive: true);
    notifyListeners();
  }

  /// Tamanho em bytes do offline atual.
  Future<int> tamanhoEmBytes() async {
    if (!_suportado) return 0;
    final dir = await _dirBase();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list(recursive: true)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  /// Conta quantos arquivos offline já existem por categoria.
  Future<Map<String, int>> contarPorCategoria() async {
    if (!_suportado) return {};
    final dir = await _dirBase();
    final out = <String, int>{
      'biblia': 0,
      'introducao': 0,
      'manha_noite': 0,
      'promessas': 0,
    };
    if (!await dir.exists()) return out;
    await for (final e in dir.list(recursive: true)) {
      if (e is! File) continue;
      final p = e.path;
      if (p.contains('/biblia/')) {
        out['biblia'] = out['biblia']! + 1;
      } else if (p.contains('/introducao/')) {
        out['introducao'] = out['introducao']! + 1;
      } else if (p.contains('/promessas_de_deus/')) {
        out['promessas'] = out['promessas']! + 1;
      } else if (p.contains('/manha_e_noite/')) {
        out['manha_noite'] = out['manha_noite']! + 1;
      }
    }
    return out;
  }
}
