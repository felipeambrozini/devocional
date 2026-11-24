import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'audio_config.dart';
import 'canon.dart';
import 'modelos.dart';
import 'registro.dart';
import 'voz.dart';

/// Um livro inteiro cujo áudio se baixa, se conta e se apaga junto: um livro
/// da Bíblia ou um livro da Biblioteca. Quem baixa, conta ou desenha o botão
/// ([AudioOffline], `DevocionalBaixarLivro`) não precisa saber qual dos dois é.
@immutable
class LivroParaBaixar {
  const LivroParaBaixar({
    required this.titulo,
    required this.pasta,
    required this.chaves,
  });

  /// Um livro da Bíblia: pasta "biblia/joao", chaves "capitulo:joao.N".
  LivroParaBaixar.daBiblia(Livro livro)
    : titulo = livro.nome,
      pasta = 'biblia/${livro.slug}',
      chaves = [
        for (var c = 1; c <= livro.capitulos; c++)
          chaveDeCapitulo(livro.slug, c),
      ];

  /// Um livro da Biblioteca com [capitulos] capítulos (o tamanho da lista do
  /// JSON em `assets/livros/`): pasta `livros/<slug>`, chaves
  /// `livro:<slug>.N`, numeradas a partir de 1 como [chaveDoCapituloDoLivro].
  LivroParaBaixar.daBiblioteca(ObraDaBiblioteca obra, int capitulos)
    : titulo = obra.titulo,
      pasta = 'livros/${obra.slug}',
      chaves = [
        for (var n = 1; n <= capitulos; n++)
          chaveDoCapituloDoLivro(obra.slug, n),
      ];

  /// O nome que a pessoa lê ("João", "Penas para Flechas").
  final String titulo;

  /// A pasta dentro de `audio_offline/`, a mesma de
  /// [caminhoRelativoParaChave]: o livro se apaga e se conta por ela.
  final String pasta;

  /// As chaves da voz dos capítulos, na ordem. A primeira responde pelo livro
  /// todo na checagem do Storage: os livros ganham áudio inteiros.
  final List<String> chaves;

  @override
  bool operator ==(Object other) =>
      other is LivroParaBaixar && other.pasta == pasta;

  @override
  int get hashCode => pasta.hashCode;
}

/// Gerencia o download dos MP3 pré-gerados para uso offline.
///
/// Baixa por categoria (Bíblia, Introdução, Manhã e Noite, Promessas) ou por
/// livro ([LivroParaBaixar], da Bíblia ou da Biblioteca).
/// Web não tem sistema de arquivos: todos os métodos viram no-op.
class AudioOffline extends ChangeNotifier {
  AudioOffline._();
  static final AudioOffline instancia = AudioOffline._();

  bool _baixando = false;
  bool _cancelado = false;
  String? _categoriaAtiva;
  String? _loteAtivo;
  String? _loteDoErro;
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

  /// Arquivos baixados por pasta de livro (`biblia/joao`, `livros/<slug>`).
  /// Separado de [_contagemPorCategoria] de propósito: [estimarTamanhos]
  /// percorre as chaves daquele mapa, e um livro ali viraria um HEAD a mais
  /// cada vez que a folha de ajustes abre.
  final Map<String, int> _contagemPorLivro = {};

  bool get baixando => _baixando;

  /// A categoria em download, ou `null` quando o lote é um livro.
  String? get categoriaAtiva => _categoriaAtiva;

  /// O lote em download agora: a categoria ou a pasta do livro.
  String? get loteAtivo => _loteAtivo;

  /// O lote em que [erro] aconteceu, para cada tela mostrar só o erro dela.
  String? get loteDoErro => _loteDoErro;

  /// Quantos arquivos de [livro] já estão no aparelho, ou `null` se
  /// ainda não contou (ver [contarLivro] e [atualizarContagens]).
  int? contagemDoLivro(LivroParaBaixar livro) => _contagemPorLivro[livro.pasta];

  /// Se o lote em download agora é [livro].
  bool estaBaixando(LivroParaBaixar livro) =>
      _baixando && _loteAtivo == livro.pasta;

  /// O erro do último download de [livro], ou `null` se o último erro foi de
  /// outro lote (cada tela mostra só o dela).
  String? erroDo(LivroParaBaixar livro) =>
      _loteDoErro == livro.pasta ? _erro : null;
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

  Future<bool> temOffline(String chave) async {
    final paraTeste = temOfflineParaTeste;
    if (paraTeste != null) return paraTeste(chave);
    if (!_suportado) return false;
    final f = await _arquivoLocal(chave);
    return f.exists();
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

  /// Se AUDIO_BASE_URL não estiver configurada, não faz nada. Interrompível
  /// por [cancelar]: o que já baixou fica — só para de pedir o resto.
  Future<void> baixarCategoria(String categoria, {http.Client? cliente}) =>
      _baixarLote(
        _chavesDaCategoria(categoria),
        lote: categoria,
        cliente: cliente,
      );

  /// Baixa os capítulos de [livro], gravados na pasta dele. Para no primeiro
  /// arquivo que o Storage disser que não existe: os livros ganham áudio
  /// inteiros, então um capítulo ausente quer dizer livro sem áudio, e seguir
  /// seriam centenas de pedidos fadados ao mesmo erro.
  Future<void> baixarLivro(LivroParaBaixar livro, {http.Client? cliente}) =>
      _baixarLote(
        livro.chaves,
        lote: livro.pasta,
        pararSeFaltar: true,
        cliente: cliente,
      );

  Future<void> _baixarLote(
    List<String> chaves, {
    required String lote,
    bool pararSeFaltar = false,
    http.Client? cliente,
  }) async {
    if (!_suportado) return;
    if (_baixando) return;
    final base = _baseUrl;
    if (base.isEmpty) {
      _erro = 'AUDIO_BASE_URL não configurada no build.';
      _loteDoErro = lote;
      notifyListeners();
      return;
    }
    _baixando = true;
    _cancelado = false;
    _loteAtivo = lote;
    _categoriaAtiva = _contagemPorCategoria.containsKey(lote) ? lote : null;
    _baixadosNoLote = 0;
    _totalNoLote = chaves.length;
    _progresso = 0;
    _erro = null;
    _loteDoErro = null;
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
          _somarArquivo(caminhoRelativoParaChave(chave) ?? '');
          _tamanhoTotalBytes += resp.bodyBytes.length;
        } else {
          falhou = true;
          _erro = 'Falha em $chave: ${resp.statusCode}';
          // O Storage responde 403 para objeto ausente (sem permissão de
          // listar), como em [Voz.disponibilidadeRemota].
          if (pararSeFaltar &&
              const {403, 404, 410}.contains(resp.statusCode)) {
            _erro = 'Áudio deste livro ainda não publicado';
            _loteDoErro = lote;
            break;
          }
        }
      } catch (e) {
        falhou = true;
        _erro = 'Erro em $chave: $e';
      }
      if (falhou) _loteDoErro = lote;
      _baixadosNoLote++;
      _progresso = _baixadosNoLote / _totalNoLote;
      notifyListeners();
      // Evita sobrecarregar a rede/storage.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _baixando = false;
    _categoriaAtiva = null;
    _loteAtivo = null;
    if (!falhou) {
      _erro = null;
      _loteDoErro = null;
    }
    notifyListeners();
  }

  /// Soma um arquivo recém-baixado à categoria e ao livro de [relativo]
  /// ("biblia/joao/3.mp3" conta para "biblia" e para "biblia/joao").
  void _somarArquivo(String relativo) {
    final categoria = _categoriaDoCaminho(relativo);
    if (categoria != null) {
      _contagemPorCategoria[categoria] =
          (_contagemPorCategoria[categoria] ?? 0) + 1;
    }
    final pasta = _pastaDoLivroDoCaminho(relativo);
    if (pasta != null) {
      _contagemPorLivro[pasta] = (_contagemPorLivro[pasta] ?? 0) + 1;
    }
  }

  /// A categoria de um caminho relativo a `audio_offline/`, ou `null` para o
  /// que não tem categoria (livros da Biblioteca, comentários).
  static String? _categoriaDoCaminho(String relativo) {
    if (relativo.startsWith('biblia/')) return 'biblia';
    if (relativo.startsWith('introducoes/')) return 'introducao';
    if (relativo.startsWith('devocionais/promessas_de_deus/')) {
      return 'promessas';
    }
    if (relativo.startsWith('devocionais/manha_e_noite/')) {
      return 'manha_noite';
    }
    return null;
  }

  /// A pasta do livro de um caminho relativo ("biblia/joao/3.mp3" →
  /// "biblia/joao"), ou `null` fora de `biblia/` e `livros/`.
  static String? _pastaDoLivroDoCaminho(String relativo) {
    final partes = relativo.split('/');
    if (partes.length < 3) return null;
    if (partes[0] != 'biblia' && partes[0] != 'livros') return null;
    return '${partes[0]}/${partes[1]}';
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

  Future<void> apagarCategoria(String categoria) async {
    if (!_suportado) return;
    final dir = await _dirBase();
    final sub = switch (categoria) {
      'biblia' => 'biblia',
      'introducao' => 'introducoes',
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

  Future<void> apagarTudo() async {
    if (!_suportado) return;
    final dir = await _dirBase();
    if (await dir.exists()) await dir.delete(recursive: true);
    await atualizarContagens();
  }

  /// Apaga o áudio de [livro] (a pasta dele) e reconta do disco.
  Future<void> apagarLivro(LivroParaBaixar livro) async {
    if (!_suportado) return;
    final pasta = livro.pasta;
    // Só pasta de livro: um caminho torto aqui apagaria outra coisa.
    if (_pastaDoLivroDoCaminho('$pasta/x.mp3') != pasta) return;
    final dir = await _dirBase();
    final alvo = Directory('${dir.path}/$pasta');
    if (await alvo.exists()) await alvo.delete(recursive: true);
    await atualizarContagens();
  }

  /// Conta só os arquivos de [livro], para a tela de um livro saber o que já
  /// tem sem varrer o áudio inteiro como [atualizarContagens]. Sem disco (web,
  /// teste de widget sem path_provider) a contagem fica em 0.
  Future<void> contarLivro(LivroParaBaixar livro) async {
    final pasta = livro.pasta;
    // Quem chama costuma ser o initState de um widget: sem esta espera, o
    // caminho sem disco avisava os ouvintes no meio do build.
    await Future<void>.microtask(() {});
    var total = 0;
    if (_suportado && temOfflineParaTeste == null) {
      try {
        final dir = await _dirBase();
        final alvo = Directory('${dir.path}/$pasta');
        if (await alvo.exists()) {
          await for (final e in alvo.list()) {
            if (e is File) total++;
          }
        }
      } catch (erro, pilha) {
        Registro.erro('AudioOffline: contar $pasta', erro, pilha);
      }
    }
    if (_contagemPorLivro[pasta] == total) return;
    _contagemPorLivro[pasta] = total;
    notifyListeners();
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
    final porLivro = <String, int>{};
    var bytes = 0;
    if (await dir.exists()) {
      final raiz = '${dir.path.replaceAll('\\', '/')}/';
      await for (final e in dir.list(recursive: true)) {
        if (e is! File) continue;
        bytes += await e.length();
        // `Directory.list()` devolve o separador nativo da plataforma
        // (`\` no Windows do desenvolvimento, `/` em Android/iOS/web, onde
        // o app roda de verdade) — normalizar antes de comparar evita a
        // contagem sempre zerada num dos dois mundos.
        final p = e.path.replaceAll('\\', '/');
        if (p.startsWith(raiz)) {
          final pasta = _pastaDoLivroDoCaminho(p.substring(raiz.length));
          if (pasta != null) porLivro[pasta] = (porLivro[pasta] ?? 0) + 1;
        }
        if (p.contains('/biblia/')) {
          contagem['biblia'] = contagem['biblia']! + 1;
        } else if (p.contains('/introducoes/')) {
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
    _contagemPorLivro
      ..clear()
      ..addAll(porLivro);
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
    // Cópia das chaves: `atualizarContagens` roda em paralelo (mesmo
    // `unawaited` em folha_de_ajustes.dart) e faz `clear()+addAll()` no fim
    // da varredura de disco — iterar a `Map` viva enquanto este loop está
    // parado num `await` (a amostra HTTP abaixo) lançava
    // ConcurrentModificationError se as duas terminassem no mesmo instante.
    for (final categoria in _contagemPorCategoria.keys.toList()) {
      if (_tamanhoMedioPorCategoria.containsKey(categoria)) continue;
      _tamanhoMedioPorCategoria[categoria] = await _amostrarTamanho(
        categoria,
        base,
      );
    }
    notifyListeners();
  }

  /// Bytes por arquivo de um livro, de uma amostra como em
  /// [estimarTamanhos]; `null` se ainda não amostrou ou não deu.
  int? tamanhoMedioDoLivro(LivroParaBaixar livro) =>
      _tamanhoMedioPorLivro[livro.pasta];
  final Map<String, int?> _tamanhoMedioPorLivro = {};

  /// Amostra o tamanho de um arquivo de [livro] para a tela do livro mostrar
  /// o MB antes do toque em "Baixar". Uma vez por livro e por sessão.
  Future<void> estimarLivro(LivroParaBaixar livro) async {
    final pasta = livro.pasta;
    if (!_suportado) return;
    if (_tamanhoMedioPorLivro.containsKey(pasta)) return;
    final base = _baseUrl;
    if (base.isEmpty) return;
    _tamanhoMedioPorLivro[pasta] = await _amostrarTamanhoDe(livro.chaves, base);
    notifyListeners();
  }

  Future<int?> _amostrarTamanho(String categoria, String base) =>
      _amostrarTamanhoDe(_chavesDaCategoria(categoria), base);

  Future<int?> _amostrarTamanhoDe(List<String> chaves, String base) async {
    for (final chave in chaves) {
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
