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
  bool _cancelado = false;
  String? _categoriaAtiva; // biblia, introducao, manha_noite, promessas
  double _progresso = 0; // 0..1 do lote atual
  int _baixadosNoLote = 0;
  int _totalNoLote = 0;
  String? _erro;

  /// Contagem e tamanho já baixados, mantidos em memória e atualizados
  /// incrementalmente a cada arquivo — nunca por uma varredura do disco. A
  /// tela de ajustes só varre o disco uma vez, ao abrir (ver
  /// [atualizarContagens]); sem isto, cada notificação de progresso durante
  /// um download disparava `dir.list(recursive: true)` várias vezes sobre
  /// até 2.353 arquivos, e a folha travava enquanto baixava.
  final Map<String, int> _contagemPorCategoria = {
    'biblia': 0,
    'introducao': 0,
    'manha_noite': 0,
    'promessas': 0,
  };
  int _tamanhoTotalBytes = 0;

  bool get baixando => _baixando;
  String? get categoriaAtiva => _categoriaAtiva;
  double get progresso => _progresso;
  Map<String, int> get contagemPorCategoria =>
      Map.unmodifiable(_contagemPorCategoria);
  int get tamanhoTotalBytes => _tamanhoTotalBytes;

  /// Bytes estimados por arquivo de cada categoria, de uma amostra (ver
  /// [estimarTamanhos]). `null` quando ainda não amostrou ou a amostra falhou
  /// — nesse caso a tela simplesmente não mostra estimativa, em vez de um
  /// número inventado.
  Map<String, int?> get tamanhoMedioPorCategoria =>
      Map.unmodifiable(_tamanhoMedioPorCategoria);
  final Map<String, int?> _tamanhoMedioPorCategoria = {};
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

  /// Override para testes: [audioBaseUrl] é `const` (`String.fromEnvironment`),
  /// e por isso nunca dá para trocar em runtime sem `--dart-define` — o
  /// mesmo problema que [Voz.baseUrlForTest] resolve do lado da leitura em
  /// voz. Null usa o valor real do build.
  static String? baseUrlParaTeste;

  String get _baseUrl => baseUrlParaTeste ?? audioBaseUrl;

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
  /// Se AUDIO_BASE_URL não estiver configurada, não faz nada. Interrompível
  /// por [cancelar]: o que já baixou fica — só para de pedir o resto.
  Future<void> baixarCategoria(String categoria, {http.Client? cliente}) async {
    if (!_suportado) return;
    if (_baixando) return;
    final base = _baseUrl;
    if (base.isEmpty) {
      _erro = 'AUDIO_BASE_URL não configurada no build.';
      notifyListeners();
      return;
    }
    final chaves = _chavesDaCategoria(categoria);
    _baixando = true;
    _cancelado = false;
    _categoriaAtiva = categoria;
    _baixadosNoLote = 0;
    _totalNoLote = chaves.length;
    _progresso = 0;
    _erro = null;
    notifyListeners();

    final httpClient = cliente ?? http.Client();
    var falhou = false;
    for (var i = 0; i < chaves.length; i++) {
      if (_cancelado) break;
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
          // Incremental, não uma nova varredura do disco: os arquivos já
          // existentes ao abrir a folha já entraram na contagem em
          // [atualizarContagens] — só o recém-baixado soma aqui.
          _contagemPorCategoria[categoria] =
              (_contagemPorCategoria[categoria] ?? 0) + 1;
          _tamanhoTotalBytes += resp.bodyBytes.length;
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

  /// Para o download em andamento no próximo arquivo — o que já baixou
  /// continua no aparelho, e "Continuar" mais tarde retoma dali.
  void cancelar() {
    if (_baixando) _cancelado = true;
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
    // Apagar é ação rara e deliberada — ao contrário do download, uma
    // varredura aqui não vira um loop apertado, então recontar do disco é
    // mais simples e mais seguro do que tentar acertar a subtração exata.
    await atualizarContagens();
  }

  /// Apaga tudo.
  Future<void> apagarTudo() async {
    if (!_suportado) return;
    final dir = await _dirBase();
    if (await dir.exists()) await dir.delete(recursive: true);
    await atualizarContagens();
  }

  /// Varre o disco uma vez e atualiza [contagemPorCategoria] e
  /// [tamanhoTotalBytes] em memória. Chamar ao abrir a tela que mostra esses
  /// números (ver `ajustesDeLeitura` em `lib/widgets/folha_de_ajustes.dart`)
  /// — nunca a cada notificação de progresso, que é o que travava a folha
  /// durante um download grande.
  Future<void> atualizarContagens() async {
    if (!_suportado) return;
    final dir = await _dirBase();
    final contagem = {
      'biblia': 0,
      'introducao': 0,
      'manha_noite': 0,
      'promessas': 0,
    };
    var bytes = 0;
    if (await dir.exists()) {
      await for (final e in dir.list(recursive: true)) {
        if (e is! File) continue;
        bytes += await e.length();
        // `Directory.list()` devolve o separador nativo da plataforma
        // (`\` no Windows do desenvolvimento, `/` em Android/iOS/web, onde
        // o app roda de verdade) — normalizar antes de comparar evita a
        // contagem sempre zerada num dos dois mundos.
        final p = e.path.replaceAll('\\', '/');
        if (p.contains('/biblia/')) {
          contagem['biblia'] = contagem['biblia']! + 1;
        } else if (p.contains('/introducao/')) {
          contagem['introducao'] = contagem['introducao']! + 1;
        } else if (p.contains('/promessas_de_deus/')) {
          contagem['promessas'] = contagem['promessas']! + 1;
        } else if (p.contains('/manha_e_noite/')) {
          contagem['manha_noite'] = contagem['manha_noite']! + 1;
        }
      }
    }
    _contagemPorCategoria
      ..clear()
      ..addAll(contagem);
    _tamanhoTotalBytes = bytes;
    notifyListeners();
  }

  /// Amostra um HEAD no primeiro arquivo que falta de cada categoria, para
  /// dar uma ideia de MB antes de a pessoa tocar em "Baixar" — sem isso, o
  /// tamanho só aparecia depois, quando a rede (e a franquia de dados) já
  /// tinham sido gastas. Chamar junto de [atualizarContagens], ao abrir a
  /// folha. Os arquivos têm duração diferente entre si, então é estimativa
  /// pela amostra, não uma soma exata.
  Future<void> estimarTamanhos() async {
    if (!_suportado) return;
    final base = _baseUrl;
    if (base.isEmpty) return;
    for (final categoria in _contagemPorCategoria.keys) {
      if (_tamanhoMedioPorCategoria.containsKey(categoria)) continue;
      _tamanhoMedioPorCategoria[categoria] = await _amostrarTamanho(
        categoria,
        base,
      );
    }
    notifyListeners();
  }

  Future<int?> _amostrarTamanho(String categoria, String base) async {
    for (final chave in _chavesDaCategoria(categoria)) {
      if (await temOffline(chave)) continue;
      final url = _urlParaChaveHttp(chave, base);
      if (url == null) continue;
      try {
        final resp = await http
            .head(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        final tamanho = resp.headers['content-length'];
        return tamanho == null ? null : int.tryParse(tamanho);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
