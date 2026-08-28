import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart'
    show AppLifecycleState, ChangeNotifier, WidgetsBinding;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_config.dart';
import 'canon.dart';
import 'registro.dart';

/// Áudios pré-gerados em MP3 (voz clonada do usuário). Sem TTS em tempo real:
/// todo áudio vem de arquivo remoto (`AUDIO_BASE_URL`) ou do cache offline
/// (`AudioOffline` em `audio_offline.dart`).

/// Falha na voz, já traduzida para o que o usuário deve ler.
class VozException implements Exception {
  const VozException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// As chaves que identificam o que a voz toca ("capitulo:joao.3",
/// "introducao:joao"): quem monta o botão e quem mostra o estado na barra
/// precisam do mesmo formato, e um erro de digitação numa cópia quebraria o
/// pareamento em silêncio. Por isso os dois construtores vivem aqui.
String chaveDeCapitulo(String livro, int numero) => 'capitulo:$livro.$numero';

String chaveDaIntroducao(String slug) => 'introducao:$slug';

/// O caminho relativo do mp3 pré-gerado para [chave] (sem base nem barra
/// inicial): "biblia/joao/3.mp3", "introducao/joao.mp3",
/// "devocionais/manha_e_noite/manha/8-19.mp3",
/// "devocionais/promessas_de_deus/8-19.mp3" — o mesmo nome dos arquivos em
/// `assets/`. Null se a chave não tiver um desses formatos. Único
/// lugar que conhece essa estrutura de pastas (a mesma que `audio_gen/*.py`
/// escreve) — [Voz] (remoto) e [AudioOffline] (disco) só chamam, em vez de
/// cada um adivinhar a estrutura por conta própria.
String? caminhoRelativoParaChave(String chave) {
  if (chave.startsWith('capitulo:')) {
    final partes = chave.substring('capitulo:'.length).split('.');
    if (partes.length != 2) return null;
    return 'biblia/${partes[0]}/${partes[1]}.mp3';
  }
  if (chave.startsWith('introducao:')) {
    return 'introducao/${chave.substring('introducao:'.length)}.mp3';
  }
  if (chave.startsWith('devocional:')) {
    final resto = chave.substring('devocional:'.length);
    final idx = resto.indexOf(':');
    if (idx == -1) return null;
    final leitura = resto.substring(0, idx);
    final data = resto.substring(idx + 1).replaceAll('/', '-');
    if (leitura == 'promessas') return 'devocionais/promessas_de_deus/$data.mp3';
    return 'devocionais/manha_e_noite/$leitura/$data.mp3';
  }
  return null;
}

/// Mensagem da falha ao tocar (codec, player, rede no meio do caminho): não
/// há o que o usuário conserte além de tentar de novo.
const _erroDeTocagem =
    'Não foi possível tocar o áudio. Tente de novo em instantes.';

/// A voz em uma sessão: toca arquivo remoto ou offline e pausa sem recarregar.
///
/// É um ChangeNotifier de app inteiro, e não estado de tela, porque o botão de
/// ouvir existe em duas telas (a introdução e o leitor) e as duas precisam
/// refletir o mesmo áudio: tocar num lugar mostra o botão "Parar" no outro.
class Voz extends ChangeNotifier {
  Voz._();

  /// A voz de todo o app. Um único player para nunca ter duas leituras
  /// tocando ao mesmo tempo.
  static final Voz instancia = Voz._();

  /// O player nasce só no primeiro toque, e não com a classe: o botão de ouvir
  /// existe em telas que os testes montam sem áudio de verdade, e um player
  /// parado numa plataforma sem suporte não pode derrubar a tela só por
  /// existir. O fim do áudio é o retorno do [AudioPlayer.play], que completa
  /// quando a leitura para, pausa ou chega ao fim.
  AudioPlayer? _player;

  /// Janela do debounce: um toque na mesma chave logo depois de parar é o
  /// gesto repetido (o "Parar" e o "Ouvir" juntos), e recomeçar a leitura do
  /// zero aí seria trocar o que se ouvia por engano. Retomar (o "Desfazer" do
  /// deslize e a pílula pausada) é intenção explícita e não passa por aqui.
  static const _debounce = Duration(milliseconds: 400);

  /// Contador de pedidos: trocar de capítulo ou fechar a tela no meio do
  /// carregamento não pode tocar um áudio que ninguém quer mais.
  int _versao = 0;

  bool _tocando = false;
  bool _carregando = false;
  String? _tocandoChave;

  /// Pausada de fora (chamada, perda de foco de áudio): a leitura não acabou
  /// nem foi parada — a sessão fica viva, esperando o retomar da posição em
  /// que estava. É campo próprio, e não derivação dos outros três, porque um
  /// preparo que falha também deixa "chave definida sem tocar" e não pode
  /// parecer uma pausa.
  bool _pausado = false;

  /// A posição em que a pausa de fora segurou a leitura: o retomar (pílula,
  /// barra e "Desfazer") volta a tocar daqui, e não do zero.
  Duration? _posicaoDaPausa;

  /// A última chave que o [parar] derrubou e quando: é o debounce do toque
  /// seguinte na mesma chave. O relógio é Stopwatch de verdade (não o tempo
  /// falso dos testes de widget) porque a janela é real.
  String? _ultimaChaveParada;
  Stopwatch? _relogioDaParada;

  /// Onde a leitura estava quando o [parar] a derrubou (posição da pausa ou do
  /// player, na ordem). O "Desfazer" do deslize devolve a leitura daqui.
  Duration? _desdeAParada;

  /// Exposto para AudioOffline e para debug. Use [audioBaseUrl] de
  /// `audio_config.dart` diretamente quando possível.
  static String get baseUrlAudio => audioBaseUrl;

  /// Override para testes: quando não há --dart-define, os testes injetam
  /// um base fake para que _urlParaChave não retorne null.
  static String? baseUrlForTest;

  /// Chaves já buscadas nesta sessão de teste — completaram a leitura ou
  /// chegaram a tocar/pausar antes de [parar] (apenas para testes). Em
  /// produção, a existência do arquivo offline é a fonte da verdade.
  static final Set<String> _chavesEmCacheParaTestes = <String>{};

  /// Mapeia a chave interna ("capitulo:joao.3", "introducao:genesis",
  /// "devocional:manha:8/19") para a URL do MP3 pré-gerado. Retorna null
  /// se a chave não tem áudio em arquivo.
  String? _urlParaChave(String chave) {
    final baseRaw = baseUrlForTest ?? audioBaseUrl;
    if (baseRaw.isEmpty) return null;
    if (baseUrlForTest == null && !_livroExisteNaChave(chave)) return null;
    final relativo = caminhoRelativoParaChave(chave);
    if (relativo == null) return null;
    final base = baseRaw.endsWith('/')
        ? baseRaw.substring(0, baseRaw.length - 1)
        : baseRaw;
    return '$base/$relativo';
  }

  /// Guarda contra chave com livro que não existe (dado corrompido/de teste
  /// sem override): "capitulo:xyz.3" ou "introducao:xyz" nunca tem áudio.
  bool _livroExisteNaChave(String chave) {
    if (chave.startsWith('capitulo:')) {
      final slug = chave.substring('capitulo:'.length).split('.').first;
      return livroPorSlug(slug) != null;
    }
    if (chave.startsWith('introducao:')) {
      return livroPorSlug(chave.substring('introducao:'.length)) != null;
    }
    return true;
  }

  /// Se há um arquivo de áudio para [chave] (base configurada e chave conhecida).
  bool temArquivoParaChave(String chave) => _urlParaChave(chave) != null;

  /// Override para testes: quando não nulo, [arquivoDisponivelRemoto] retorna
  /// isso direto, sem bater na rede. Com [baseUrlForTest] setado e este
  /// continuando nulo, assume disponível — a maioria dos testes de voz não é
  /// sobre disponibilidade de arquivo.
  static bool? disponibilidadeRemotaParaTeste;

  /// Se [chave] já tem áudio publicado no Storage agora — não confunde com
  /// [temArquivoParaChave], que só valida o formato da chave. Confere na
  /// hora com um HEAD no arquivo (sem manifesto/lista para manter
  /// atualizado): a geração roda aos poucos, em lotes, por semanas, e sem
  /// essa checagem o botão de ouvir apareceria para áudio que ainda não
  /// existe. É assíncrono; quem mostra o botão deve esconder até a resposta
  /// chegar, em vez de mostrar um "Ouvir" que falharia ao tocar.
  Future<bool> arquivoDisponivelRemoto(String chave) async {
    final url = _urlParaChave(chave);
    if (url == null) return false;
    if (baseUrlForTest != null) return disponibilidadeRemotaParaTeste ?? true;
    try {
      final resp = await http.head(Uri.parse(url));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Há um áudio tocando agora (a leitura começou e não terminou).
  bool get tocando => _tocando;

  /// A voz ainda está preparando o áudio (baixando).
  bool get carregando => _carregando;

  /// O que está tocando ou carregando: o botão com a mesma chave mostra
  /// "Parar", e os outros ficam em "Ouvir".
  String? get tocandoChave => _tocandoChave;

  /// Pausada de fora: a leitura não acabou nem foi parada, e a sessão espera
  /// o retomar da posição em que estava.
  bool get pausado => _pausado;

  /// A posição em que o [parar] derrubou a leitura: o "Desfazer" do deslize
  /// passa isto para o [retomar] e a leitura volta de onde estava.
  Duration? get desdeAParada => _desdeAParada;

  /// A posição da leitura atual, para a linha fina de progresso do botão. Sem
  /// player (nos testes não há plataforma de áudio) a stream fica vazia e
  /// nada é desenhado.
  Stream<Duration> get posicao =>
      _leitorDeAudio?.posicao ??
      _player?.positionStream ??
      Stream<Duration>.empty();

  /// A duração total do áudio carregado, que junto com [posicao] vira o
  /// progresso. É nula até o player conhecer o áudio.
  Stream<Duration?> get duracao =>
      _leitorDeAudio?.duracao ??
      _player?.durationStream ??
      Stream<Duration?>.empty();

  /// A posição atual da leitura, em Duration. No leitor de testes, a posição
  /// é a que o teste ajustou no campo [LeitorDeAudio.posicaoAtual]; sem
  /// leitor nenhum, a do player (ou zero, sem player).
  Duration get posicaoAtual => _posicaoDoLeitor() ?? Duration.zero;

  /// Avisa quando uma leitura chega ao fim sozinha, com a chave do que
  /// terminou ("capitulo:joao.3"). O botão dessa chave mostra a confirmação
  /// "Leitura concluída." — parar no meio, pelo usuário ou pela navegação,
  /// e a pausa de fora não emitem nada.
  Stream<String> get conclusoes => _conclusoes.stream;

  final StreamController<String> _conclusoes = StreamController.broadcast();

  /// Toca o áudio de [chave], ou para se ele já estiver tocando. Todo áudio
  /// vem de arquivo MP3 pré-gerado (local offline ou remoto): [chave] sozinha
  /// resolve o arquivo, ver [caminhoRelativoParaChave].
  Future<void> alternar(String chave) async {
    final relogio = _relogioDaParada;
    if (_ultimaChaveParada == chave &&
        relogio != null &&
        relogio.elapsed < _debounce) {
      return;
    }
    if (_carregando) {
      if (_tocandoChave == chave) {
        await parar();
        return;
      }
    } else if (_tocando && _tocandoChave == chave) {
      await parar();
      return;
    }
    // Pausada com a mesma chave, o toque retoma de onde parou sem
    // recriar a source: é só seek+play, sem recarregar da rede.
    if (_pausado && _tocandoChave == chave) {
      final url = _urlParaChave(chave);
      if (url != null) {
        final de = _posicaoDaPausa;
        _posicaoDaPausa = null;
        final versao = ++_versao;
        _pausado = false;
        _tocando = true;
        _carregando = false;
        notifyListeners();
        await _tocarComGuarda(
          versao,
          () => _retomarArquivo(url, de: de, versao: versao),
        );
        return;
      }
    }

    final versao = ++_versao;
    final trocouDeChave = _tocandoChave != null && _tocandoChave != chave;
    _tocandoChave = chave;
    _carregando = true;
    _tocando = false;
    _pausado = false;
    notifyListeners();
    await _silenciar();
    final url = _urlParaChave(chave);
    if (url == null) {
      _carregando = false;
      notifyListeners();
      throw const VozException('Áudio ainda não disponível para esta leitura.');
    }
    await _tocarComGuarda(versao, () async {
      if (versao != _versao) return;
      if (!_appEmPrimeiroPlano()) return;
      // Troca de chave: garante que "tocando" continua false até a leitura nova
      // realmente iniciar (em _tocarArquivo, depois do "iniciado" completar).
      if (trocouDeChave) {
        _tocando = false;
      }
      await _tocarArquivo(
        url,
        chave,
        versao: versao,
        segurarTocando: trocouDeChave,
      );
    });
  }

  /// Toca com a guarda padrão das leituras: [VozException] passa como veio,
  /// qualquer outra falha vira [_erroDeTocagem], e o fim limpa o preparo.
  Future<void> _tocarComGuarda(
    int versao,
    Future<void> Function() tocar,
  ) async {
    try {
      await tocar();
    } on VozException {
      rethrow;
    } catch (erro, pilha) {
      Registro.erro('Voz.tocar', erro, pilha);
      throw const VozException(_erroDeTocagem);
    } finally {
      if (versao == _versao) {
        _carregando = false;
        if (!_tocando && !_pausado) _tocandoChave = null;
        notifyListeners();
      }
    }
  }

  /// Para a leitura, se houver uma; também cancela um carregamento no meio.
  Future<void> parar() async {
    final chave = _tocandoChave;
    // Uma leitura que chegou a tocar ou pausar já buscou o áudio: em teste,
    // isso basta para o "Desfazer" do deslize poder retomá-la depois (ver
    // [retomar]), sem esperar o fim natural que um stop no meio nunca vê.
    if (chave != null && baseUrlForTest != null && (_tocando || _pausado)) {
      _chavesEmCacheParaTestes.add(chave);
    }
    _ultimaChaveParada = chave;
    _relogioDaParada = Stopwatch()..start();
    _desdeAParada = _posicaoDaPausa ?? _posicaoDoLeitor();
    _posicaoDaPausa = null;
    _versao++;
    _tocando = false;
    _carregando = false;
    _pausado = false;
    _tocandoChave = null;
    await _silenciar();
    notifyListeners();
  }

  /// Pausa a leitura sem encerrar a sessão.
  Future<void> pausar() async {
    if (!_tocando) return;
    final leitor = _leitorDeAudio;
    if (leitor != null) {
      await leitor.pausar();
      return;
    }
    final player = _player;
    if (player == null) return;
    try {
      await player.pause();
    } catch (_) {}
  }

  /// Tenta retomar a leitura pausada sem recriar a source: se o player já
  /// tem a source carregada, é só seek+play, sem recarregar da rede.
  Future<bool> _tentarRetomarSemRecriar(
    Duration? de, {
    required int versao,
  }) async {
    final player = _player;
    if (player == null) return false;
    try {
      if (player.audioSource == null) return false;
      if (de != null) await player.seek(de);
      final fim = player.play();
      await _acompanharLeitura(fim, _tocandoChave!, versao: versao);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toca um arquivo de áudio pré-gerado (Firebase Storage / Hosting / offline local).
  ///
  /// [segurarTocando] segura a marcação de "tocando" numa troca de chave em
  /// andamento: sem um sinal de início independente do fim no leitor de
  /// testes, marcar "tocando" assim que [_iniciarLeituraDeUrl] devolve
  /// marcaria por cima de uma troca que ainda pode ser cancelada.
  Future<void> _tocarArquivo(
    String url,
    String chave, {
    required int versao,
    Duration? de,
    bool segurarTocando = false,
  }) async {
    var fim = Future<void>.value();
    await _iniciarLeituraDeUrl(
      url,
      chave: chave,
      versao: versao,
      de: de,
      segurarTocando: segurarTocando,
      aoFim: (f) => fim = f,
    );
    if (versao != _versao) return;
    _tocando = true;
    _carregando = false;
    notifyListeners();
    await _acompanharLeitura(fim, chave, versao: versao);
  }

  /// Retoma um arquivo pausado sem recriar a source quando possível.
  Future<void> _retomarArquivo(
    String url, {
    Duration? de,
    required int versao,
  }) async {
    if (await _tentarRetomarSemRecriar(de, versao: versao)) return;
    await _tocarArquivo(url, _tocandoChave!, versao: versao, de: de);
  }

  /// Resolve a fonte preferindo arquivo offline local, depois URL remota.
  Future<String?> _fonteComOffline(String url, String chave) async {
    if (kIsWeb) return url;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final local = _caminhoLocalParaChave(chave);
      final f = File('${dir.path}/$local');
      if (await f.exists()) return f.uri.toString();
    } catch (_) {}
    return url;
  }

  String _caminhoLocalParaChave(String chave) {
    final relativo = caminhoRelativoParaChave(chave);
    if (relativo != null) return 'audio_offline/$relativo';
    return 'audio_offline/${chave.replaceAll(':', '_').replaceAll('/', '-')}.mp3';
  }

  /// Inicia a leitura de uma URL (arquivo pré-gerado) preferindo offline local.
  /// Retorna um future que completa quando a leitura *inicia* (para transição
  /// carregando->tocando); [aoFim] recebe a future que completa quando a
  /// leitura *termina*, para quem acompanha o fim (ver [_acompanharLeitura]).
  Future<void> _iniciarLeituraDeUrl(
    String url, {
    required String chave,
    required int versao,
    required void Function(Future<void> fim) aoFim,
    Duration? de,
    bool segurarTocando = false,
  }) async {
    final leitor = _leitorDeAudio;
    if (leitor != null) {
      Future<void>? fim;
      await leitor.tocar(
        Uint8List(0),
        de: de,
        aoFim: (f) {
          fim = f;
          aoFim(f);
        },
      );
      // Numa troca de chave em andamento, o "iniciou" do leitor não basta:
      // só marca "tocando" quando a leitura nova também terminar (ou for
      // interrompida), para não pintar por cima de uma troca cancelável.
      if (segurarTocando) await fim;
      return;
    }
    final player = _player ??= AudioPlayer();
    final fonte = await _fonteComOffline(url, chave);
    await player.setAudioSource(AudioSource.uri(Uri.parse(fonte ?? url)));
    if (versao != _versao) return;
    if (de != null) {
      await player.seek(de);
    }
    // player.play() retorna future que completa no fim; usamos playerStateStream para "iniciou"
    final iniciado = Completer<void>();
    late StreamSubscription<PlayerState> sub;
    sub = player.playerStateStream.listen((state) {
      if (state.playing) {
        iniciado.complete();
        sub.cancel();
      }
    });
    aoFim(player.play());
    return iniciado.future;
  }

  /// Retoma a leitura de [chave] que o "Desfazer" do deslize devolveu.
  /// Sem arquivo offline em disco (ou cache de teste), não há o que retomar.
  Future<bool> retomar(String chave, {Duration? de}) async {
    final url = _urlParaChave(chave);
    if (url == null) return false;
    if (baseUrlForTest != null) {
      if (!_chavesEmCacheParaTestes.contains(chave)) return false;
    } else if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final local = _caminhoLocalParaChave(chave);
        final f = File('${dir.path}/$local');
        if (!await f.exists()) return false;
      } catch (_) {
        return false;
      }
    }
    final versao = ++_versao;
    _tocandoChave = chave;
    _tocando = true;
    _carregando = false;
    _pausado = false;
    notifyListeners();
    await _silenciar();
    await _tocarComGuarda(
      versao,
      () => _tocarArquivo(url, chave, versao: versao, de: de),
    );
    return true;
  }

  /// Retoma a leitura pausada de fora: do arquivo na posição da pausa.
  Future<bool> retomarDaPausa() async {
    if (!_pausado) return false;
    final chave = _tocandoChave!;
    final de = _posicaoDaPausa;
    final url = _urlParaChave(chave);
    if (url != null) {
      _posicaoDaPausa = null;
      final versao = ++_versao;
      _pausado = false;
      _tocando = true;
      _carregando = false;
      notifyListeners();
      await _tocarComGuarda(
        versao,
        () => _retomarArquivo(url, de: de, versao: versao),
      );
      return true;
    }
    return false;
  }

  /// Acompanha a leitura até o fim e fecha o ciclo.
  Future<void> _acompanharLeitura(
    Future<void> fim,
    String chave, {
    required int versao,
  }) async {
    await fim;
    if (versao != _versao) return;
    final leitor = _leitorDeAudio;
    if (leitor == null) {
      final player = _player!;
      if (player.processingState != ProcessingState.completed) {
        _posicaoDaPausa = player.position;
        _pausado = true;
        _tocando = false;
        _carregando = false;
        notifyListeners();
        return;
      }
    } else if (leitor.pausadoDeFora) {
      _posicaoDaPausa = leitor.posicaoAtual ?? Duration.zero;
      _pausado = true;
      _tocando = false;
      _carregando = false;
      notifyListeners();
      return;
    } else if (!leitor.concluida) {
      _tocando = false;
      _tocandoChave = null;
      _carregando = false;
      notifyListeners();
      return;
    }
    _tocando = false;
    _tocandoChave = null;
    _carregando = false;
    _conclusoes.add(chave);
    if (baseUrlForTest != null) _chavesEmCacheParaTestes.add(chave);
    notifyListeners();
  }

  /// Silencia o que estiver tocando sem tocar no estado da sessão.
  Future<void> _silenciar() async {
    final leitor = _leitorDeAudio;
    if (leitor != null) {
      await leitor.silenciar();
      return;
    }
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
  }

  /// Onde a leitura está agora: no leitor de testes, a posição que o teste
  /// ajustou; no app, a do player.
  Duration? _posicaoDoLeitor() {
    final leitor = _leitorDeAudio;
    if (leitor != null) return leitor.posicaoAtual;
    return _player?.position;
  }

  /// A janela está no primeiro plano? Com a aba escondida (web), a tela
  /// bloqueada ou uma ligação no meio, o áudio pronto não toca nem conclui —
  /// fica na cache esperando o primeiro plano. O flag dos testes decide
  /// sozinho; sem binding (teste simples), assume o primeiro plano.
  bool _appEmPrimeiroPlano() {
    final paraTestes = primeiroPlanoParaTestes;
    if (paraTestes != null) return paraTestes;
    try {
      final estado = WidgetsBinding.instance.lifecycleState;
      return estado != AppLifecycleState.paused &&
          estado != AppLifecycleState.detached;
    } catch (_) {
      return true;
    }
  }

  LeitorDeAudio? _leitorDeAudio;

  set injetarLeitor(LeitorDeAudio? leitor) {
    _leitorDeAudio = leitor;
    notifyListeners();
  }

  LeitorDeAudio? get leitorDeAudio => _leitorDeAudio;

  void limparCacheParaTestes() {
    _versao++;
    notifyListeners();
  }

  bool? primeiroPlanoParaTestes;
}

/// Mock leitor de áudio que os testes usam no lugar do just_audio.
abstract class LeitorDeAudio {
  /// Inicia a leitura de [bytes] a partir de [de]. Completa quando a leitura
  /// *começa* de fato (a transição carregando->tocando); [aoFim] recebe a
  /// future que completa quando a leitura *termina* (naturalmente, por
  /// pausa de fora ou por [silenciar]) — o mesmo par que o player de verdade
  /// expõe via `playerStateStream` (início) e o retorno de `play()` (fim).
  Future<void> tocar(
    Uint8List bytes, {
    Duration? de,
    required void Function(Future<void> fim) aoFim,
  });
  Future<void> silenciar();
  Future<void> pausar();
  Stream<Duration> get posicao;
  Stream<Duration?> get duracao;
  Duration? get posicaoAtual;
  bool get pausadoDeFora;
  bool get concluida;
}
