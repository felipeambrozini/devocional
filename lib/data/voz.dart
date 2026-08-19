import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart'
    show AppLifecycleState, ChangeNotifier, WidgetsBinding, debugPrint;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'google.dart';
import 'modelos.dart';

/// A voz em que Spurgeon lê: um narrador masculino de barítono, timbre
/// profundo e caloroso, solene e reverente. A chave TTS_API_KEY mora em
/// `lib/data/google.dart` (o console do Cloud não combina a Generative
/// Language API com a Cloud Text-to-Speech na mesma chave, por isso a voz tem
/// a própria). A Google Cloud Text-to-Speech entra no tier gratuito de 1
/// milhão de caracteres por mês, e um capítulo inteiro gasta ~3 mil — dá para
/// ouvir o ano inteiro sem pagar nada.
///
/// O ritmo e o conteúdo mudam, a voz não: todo tipo de conteúdo
/// ([TipoConteudoAudio]) lê na mesma voz, o Iapetus. Para trocar, é só editar
/// o enum em `lib/data/modelos.dart` e audicionar em
/// https://cloud.google.com/text-to-speech (sem chave).

/// Falha na voz, já traduzida para o que o usuário deve ler.
///
/// Quem chama (o [BotaoDeVoz]) mostra [mensagem] num aviso; nada disto é
/// guardado.
class VozException implements Exception {
  const VozException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// O texto que a voz lê para uma introdução: o título, as seções na ordem e,
/// quando a frase tem fonte comprovada, a citação com a atribuição — o mesmo
/// conteúdo da tela, da primeira linha à última.
String textoDeIntroducao(Introducao introducao) {
  final partes = <String>['Introdução de ${introducao.livro}.'];
  for (final (titulo, corpo) in introducao.secoes) {
    partes.add(titulo);
    // Os parágrafos vêm separados por linha em branco no JSON; a voz respeita
    // a quebra como pausa natural entre parágrafos.
    partes.addAll(corpo.split('\n\n'));
  }
  if (introducao.frase.isNotEmpty) {
    partes.add('"${introducao.frase}" ${introducao.atribuicao}');
  }
  return partes.join(' ');
}

/// O texto que a voz lê para um capítulo: a referência ("João 3"), o
/// sobrescrito quando há (os Salmos) e cada versículo com o número falado —
/// assim dá para acompanhar a leitura olhando o texto na tela.
String textoDeCapitulo(Capitulo capitulo) {
  final partes = <String>[capitulo.referencia];
  if (capitulo.titulo.isNotEmpty) partes.add(capitulo.titulo);
  for (final (numero, texto) in capitulo.versiculos) {
    partes.add('$numero. $texto');
  }
  return partes.join(' ');
}

/// O texto que a voz lê para um devocional: o cabeçalho ("Devocional da
/// manhã, 18 de agosto"), o título quando a leitura tem um (as Promessas),
/// cada versículo falado com a referência — também os versículos extras do
/// dia raro — e o comentário inteiro: o mesmo conteúdo da tela, da primeira
/// linha à última, como nas introduções e nos capítulos.
String textoDeDevocional(Devocional dev, {required String cabecalho}) {
  final partes = <String>[cabecalho];
  if (dev.titulo.isNotEmpty) partes.add(dev.titulo);
  final pares = [(dev.referencia, dev.versiculo), ...dev.outrosVersiculos];
  for (final (referencia, versiculo) in pares) {
    if (versiculo.isNotEmpty) partes.add('"$versiculo"');
    if (referencia.isNotEmpty) partes.add(referencia);
  }
  if (dev.texto.isNotEmpty) partes.add(dev.texto);
  return partes.join(' ');
}

/// Cliente compartilhado do app. Os testes injetam o próprio cliente falso.
final _clientePadrao = http.Client();

/// O teto de um pedido à API: 5000 bytes de texto. Capítulos inteiros
/// estouram isto, então o texto é fatiado em frases e cada pedaço vira um
/// pedido à API, com os áudios emendados na ordem — a leitura sai sem
/// costura.
const _limiteDeBytesDoTexto = 5000;

/// O teto de um pedaço da leitura em streaming, menor que o teto da API de
/// propósito: a primeira parte chega mais rápido e a voz começa enquanto o
/// resto ainda está sendo sintetizado. Mais pedaços não custam mais na
/// quota — ela conta caracteres, não pedidos.
const _limiteDeBytesDoPedaco = 2000;

/// Fim de frase em português: ponto, exclamação ou interrogação seguido de
/// espaço e de maiúscula ou número — o "1. " dos versículos também é um bom
/// lugar para a voz respirar entre pedaços.
final _fimDeFrase = RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9"“])');

/// Corta [texto] em pedaços que a API aceita — cada um com no máximo
/// [limite] bytes de UTF-8 — sempre na fronteira de frases. Uma frase que
/// sozinha estoure o teto (não existe nos capítulos) é cortada na fronteira
/// de palavras. Quem toca em streaming usa um teto menor ([limite] abaixo do
/// da API) para a primeira parte chegar mais cedo.
List<String> _fatiar(
  String texto, {
  int limite = _limiteDeBytesDoTexto,
}) {
  if (utf8.encode(texto).length <= limite) return [texto];
  final pedacos = <String>[];
  var atual = StringBuffer();
  var bytesAtuais = 0;
  void fechar() {
    if (bytesAtuais == 0) return;
    pedacos.add(atual.toString());
    atual = StringBuffer();
    bytesAtuais = 0;
  }

  for (final frase in texto.split(_fimDeFrase)) {
    final tamanho = utf8.encode(frase).length;
    if (tamanho > limite) {
      fechar();
      pedacos.addAll(_fatiarPorPalavras(frase, limite: limite));
      continue;
    }
    if (bytesAtuais > 0 && bytesAtuais + 1 + tamanho > limite) {
      fechar();
    }
    if (bytesAtuais > 0) atual.write(' ');
    atual.write(frase);
    bytesAtuais += tamanho + (bytesAtuais == 0 ? 0 : 1);
  }
  fechar();
  return pedacos;
}

/// Uma frase inteira não coube no teto: corta na fronteira de palavras.
List<String> _fatiarPorPalavras(String frase, {required int limite}) {
  final pedacos = <String>[];
  var atual = StringBuffer();
  var bytesAtuais = 0;
  for (final palavra in frase.split(' ')) {
    final tamanho = utf8.encode(palavra).length;
    if (bytesAtuais > 0 && bytesAtuais + 1 + tamanho > limite) {
      pedacos.add(atual.toString());
      atual = StringBuffer();
      bytesAtuais = 0;
    }
    if (bytesAtuais > 0) atual.write(' ');
    atual.write(palavra);
    bytesAtuais += tamanho + (bytesAtuais == 0 ? 0 : 1);
  }
  if (bytesAtuais > 0) pedacos.add(atual.toString());
  return pedacos;
}

/// A chave da API de voz, vinda do build: quem toca de verdade usa a chave
/// TTS_API_KEY (em `lib/data/google.dart`); os testes injetam a que quiserem.
String _chaveUsada(String? chave) {
  final usada = chave ?? chaveTts;
  if (usada.isEmpty) {
    throw const VozException(
      'A voz de Spurgeon ainda não foi ligada: o build precisa da chave '
      'TTS_API_KEY.',
    );
  }
  return usada;
}

/// Pede o MP3 de [pedaco] à API de voz e devolve o áudio decodificado. É o
/// pedido de um pedaço, com o tratamento do fracasso e da resposta estranha.
Future<Uint8List> _pedirAudio(
  String pedaco, {
  required TipoConteudoAudio tipo,
  required http.Client cliente,
  required String chaveUsada,
}) async {
  final http.Response resposta;
  try {
    resposta = await cliente
        .post(
          Uri.parse(
            'https://texttospeech.googleapis.com/v1/text:synthesize'
            '?key=$chaveUsada',
          ),
          headers: await cabecalhosGoogle(),
          body: json.encode({
            'input': {'text': pedaco},
            'voice': {'languageCode': 'pt-BR', 'name': tipo.voiceName},
            'audioConfig': {
              'audioEncoding': 'MP3',
              'speakingRate': tipo.speakingRate,
            },
          }),
        )
        .timeout(const Duration(seconds: 90));
  } catch (_) {
    throw const VozException(
      'Não foi possível preparar a voz agora. Verifique a conexão e tente '
      'de novo.',
    );
  }

  if (resposta.statusCode != 200) {
    throw VozException(_mensagemDeErro(resposta));
  }

  final Map corpo;
  try {
    corpo = json.decode(utf8.decode(resposta.bodyBytes)) as Map;
  } catch (_) {
    // 200 com corpo ilegível (HTML de proxy, resposta truncada): a mesma
    // mensagem do serviço fora do ar, não uma exceção sem tratamento.
    throw const VozException('A voz não respondeu agora. Tente de novo em '
        'instantes.');
  }
  final audioDoPedaco = corpo['audioContent'];
  if (audioDoPedaco is! String || audioDoPedaco.isEmpty) {
    throw const VozException('O áudio veio vazio. Tente de novo.');
  }
  return base64.decode(audioDoPedaco);
}

/// Sintetiza [texto] na voz do tipo de conteúdo ([tipo]) e devolve o áudio
/// MP3 inteiro.
///
/// A API aceita no máximo [_limiteDeBytesDoTexto] bytes de texto por pedido;
/// um capítulo inteiro estoura isso, e o texto é fatiado em frases e pedido
/// por pedaço, com os áudios emendados na ordem.
///
/// [cliente] e [chave] existem só para os testes injetarem um HTTP falso e a
/// chave que quiserem; quem chama de verdade usa a chave TTS_API_KEY do build
/// (em `lib/data/google.dart`) e o cliente global do pacote `http`.
Future<Uint8List> sintetizar(
  String texto, {
  required TipoConteudoAudio tipo,
  http.Client? cliente,
  String? chave,
}) async {
  final chaveUsada = _chaveUsada(chave);
  final clienteUsado = cliente ?? _clientePadrao;
  final audio = BytesBuilder();
  for (final pedaco in _fatiar(texto)) {
    audio.add(
      await _pedirAudio(
        pedaco,
        tipo: tipo,
        cliente: clienteUsado,
        chaveUsada: chaveUsada,
      ),
    );
  }
  return audio.takeBytes();
}

/// Sintetiza [texto] pedaço a pedaço, chamando [aoChegar] com cada áudio na
/// ordem. Só o primeiro pedaço é esperado: ele chega em poucos segundos e a
/// leitura começa, e os demais — pedidos em paralelo, entregues na ordem —
/// vão chegando enquanto o primeiro toca. É como a leitura deixa de demorar
/// o texto inteiro: a espera do ouvinte vira a espera do primeiro pedaço.
///
/// Os pedaços são menores que o teto da API ([_limiteDeBytesDoPedaco] em vez
/// de [_limiteDeBytesDoTexto]): mais pedaços não custam mais na quota, e o
/// primeiro deles chega bem antes do áudio inteiro ficaria pronto.
Future<void> sintetizarEmPartes(
  String texto, {
  required TipoConteudoAudio tipo,
  required FutureOr<void> Function(Uint8List parte) aoChegar,
  http.Client? cliente,
  String? chave,
}) async {
  final chaveUsada = _chaveUsada(chave);
  final clienteUsado = cliente ?? _clientePadrao;
  final pedacos = _fatiar(texto, limite: _limiteDeBytesDoPedaco);
  await aoChegar(
    await _pedirAudio(
      pedacos.first,
      tipo: tipo,
      cliente: clienteUsado,
      chaveUsada: chaveUsada,
    ),
  );
  if (pedacos.length == 1) return;
  final restantes = await Future.wait([
    for (final pedaco in pedacos.skip(1))
      _pedirAudio(
        pedaco,
        tipo: tipo,
        cliente: clienteUsado,
        chaveUsada: chaveUsada,
      ),
  ]);
  for (final parte in restantes) {
    await aoChegar(parte);
  }
}

/// 403 é a chave sem a API ativada (configuração na nuvem): culpar o aparelho
  /// do leitor mandaria a um conserto que não existe — a mensagem fala do
  /// serviço e deixa o "Tentar de novo" agir. 400 é o pedido recusado; 429 é o
  /// teto do tier gratuito. Não se envia o corpo da API ao usuário: é inglês
  /// técnico que não ajuda ninguém, e a maioria dos leitores não tem o Cloud
  /// Console. O detalhe técnico vai para o log, onde quem mantém o app procura.
  String _mensagemDeErro(http.Response resposta) {
    if (resposta.statusCode == 403) {
      debugPrint(
        'Voz: a Text-to-Speech recusou (${resposta.statusCode}): '
        '${resposta.body}',
      );
      return 'O serviço de voz não está disponível agora. Tente de novo em '
          'instantes.';
    }
    if (resposta.statusCode == 400) {
      debugPrint(
        'Voz: a Text-to-Speech recusou (${resposta.statusCode}): '
        '${resposta.body}',
      );
      return 'A voz ainda não está pronta neste aparelho. Atualize o '
          'aplicativo e tente de novo.';
    }
    if (resposta.statusCode == 429) {
      return 'O limite gratuito da voz foi atingido. Espere um pouco e tente '
          'de novo.';
    }
    return 'O serviço de voz não respondeu agora. Tente de novo em instantes.';
  }

/// A voz do Spurgeon em uma sessão: sintetiza, toca e para.
///
/// É um ChangeNotifier de app inteiro, e não estado de tela, porque o botão de
/// ouvir existe em duas telas (a introdução e o leitor) e as duas precisam
/// refletir o mesmo áudio: tocar num lugar mostra o botão "Parar" no outro.
///
/// O áudio sintetizado fica na memória durante a sessão: ouvir o mesmo
/// capítulo de novo não gasta mais o tier gratuito, e o app nem pede a rede.
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

  /// Áudios prontos, guardados pela chave do que tocam ("introducao:joao",
  /// "capitulo:joao.3"). O valor é a lista de pedaços do áudio na ordem — o
  /// formato do streaming, e o que o player emenda numa playlist. A chave do
  /// cache é a mesma que o botão usa para saber o que está tocando agora.
  Map<String, List<Uint8List>> _cache = {};

  /// O que a memória segura de áudio de uma vez. Um capítulo inteiro em MP3
  /// pesa ~150 KB; 24 cabem folgados e cobrem o ir e vir das leituras do dia.
  static const _limiteDaCache = 24;

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

  /// A sessão pausada guarda como re-sintetizar o áudio se a cache a
  /// despejar: o retomar da barra não conhece o texto, e a sessão não pode
  /// morrer em silêncio.
  String? _textoDaSessao;
  TipoConteudoAudio? _tipoDaSessao;
  http.Client? _clienteDaSessao;
  String? _chaveTtsDaSessao;

  /// Há um áudio tocando agora (a leitura começou e não terminou).
  bool get tocando => _tocando;

  /// A voz ainda está preparando o áudio (baixando da Google).
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

  /// Toca [texto] na voz de [tipo] de conteúdo, ou para se ele já estiver
  /// tocando.
  ///
  /// [chave] identifica o que se ouve ("capitulo:joao.3"); tocar de novo a
  /// mesma chave para a leitura, e outra chave troca o áudio sem precisar de
  /// dois toques. [tipo] decide a voz e o ritmo da síntese ([TipoConteudoAudio]),
  /// e quem sabe o tipo é quem monta o botão, não o [Voz]. [cliente] e
  /// [chaveTts] existem só para os testes injetarem o HTTP falso e a chave de
  /// teste; o app usa os de verdade.
  ///
  /// Erros viram [VozException] para a tela avisar; o estado fica limpo nos
  /// dois casos (erro e sucesso).
  Future<void> alternar(
    String chave, {
    required String texto,
    required TipoConteudoAudio tipo,
    http.Client? cliente,
    String? chaveTts,
  }) async {
    // O debounce vem antes de tudo: o segundo toque logo após o "Parar" é o
    // gesto repetido, e recomeçar a leitura do zero aí seria trocar o que se
    // ouvia por engano.
    final relogio = _relogioDaParada;
    if (_ultimaChaveParada == chave &&
        relogio != null &&
        relogio.elapsed < _debounce) {
      return;
    }
    if (_carregando) {
      // Durante o preparo, o mesmo toque cancela: é o botão "Cancelar" do
      // botão e da barra, e não pode pedir o áudio de novo.
      if (_tocandoChave == chave) {
        await parar();
        return;
      }
      // Outra chave substitui a carga em voo: o toque novo já manda na
      // sessão, e o áudio antigo cai no descarte por versão (mas entra na
      // cache — a quota não se perde).
    } else if (_tocando && _tocandoChave == chave) {
      await parar();
      return;
    }
    // Pausada de fora com a mesma chave, o toque retoma de onde parou: do
    // áudio da memória, na posição da pausa — sem gastar a quota de novo.
    if (_pausado && _tocandoChave == chave) {
      final partes = _cache[chave];
      if (partes != null) {
        final de = _posicaoDaPausa;
        final versao = ++_versao;
        _pausado = false;
        _tocando = true;
        _carregando = false;
        notifyListeners();
        try {
          await _tocarTudo(partes, chave, versao: versao, de: de);
        } on VozException {
          rethrow;
        } catch (_) {
          throw const VozException(
            'Não foi possível tocar o áudio. Tente de novo em instantes.',
          );
        } finally {
          if (versao == _versao) {
            _carregando = false;
            if (!_tocando && !_pausado) _tocandoChave = null;
            notifyListeners();
          }
        }
        return;
      }
      // A cache despejou a sessão pausada: o toque recomeça a leitura do
      // zero, com os dados novos — nada de morrer em silêncio.
      _posicaoDaPausa = null;
    }

    final versao = ++_versao;
    _tocandoChave = chave;
    _carregando = true;
    _tocando = false;
    _pausado = false;
    _textoDaSessao = texto;
    _tipoDaSessao = tipo;
    _clienteDaSessao = cliente;
    _chaveTtsDaSessao = chaveTts;
    notifyListeners();
    // O áudio anterior (de outra chave) para sem mexer no estado da sessão
    // nova: o player é um só, e só ele precisa ser silenciado. Tocar em
    // "Preparando…" cancela com [parar], que zera esse estado.
    await _silenciar();
    try {
      final guardado = _cache[chave];
      if (guardado != null) {
        // O áudio inteiro já está na memória (ouviu antes nesta sessão): toca
        // direto, sem gastar a quota de novo.
        if (versao != _versao) return;
        // Janela escondida (aba oculta na web, tela bloqueada, ligação): o
        // áudio fica na cache esperando o primeiro plano — tocar agora seria
        // tocar para ninguém.
        if (!_appEmPrimeiroPlano()) return;
        _tocando = true;
        _carregando = false;
        notifyListeners();
        await _tocarTudo(guardado, chave, versao: versao, de: null);
      } else {
        // O áudio não existe ainda: sintetiza em streaming, com a primeira
        // parte tocando assim que chega e o resto emendado na leitura.
        await _tocarNovaSintese(
          chave,
          texto: texto,
          tipo: tipo,
          cliente: cliente,
          chaveTts: chaveTts,
          versao: versao,
        );
      }
    } on VozException {
      rethrow;
    } catch (_) {
      // Falha de plataforma ao tocar (codec, player): não há o que o usuário
      // consertar além de tentar de novo.
      throw const VozException(
        'Não foi possível tocar o áudio. Tente de novo em instantes.',
      );
    } finally {
      if (versao == _versao) {
        _carregando = false;
        if (!_tocando && !_pausado) _tocandoChave = null;
        notifyListeners();
      }
    }
  }

  /// Para a leitura, se houver uma; também cancela um carregamento no meio.
  ///
  /// Trocar de capítulo, fechar a tela da introdução e cobrir o leitor com
  /// outra tela chamam isto: não se deixa um áudio tocando sem o botão de
  /// parar à vista. Também é a chamada dos testes nas telas que desmontam com
  /// a voz instalada: sem plataforma de áudio ali, parar é só o estado, e é
  /// isso que importa.
  ///
  /// A pausa de fora sobrevive à troca de aba e de tela ([main.dart] só para
  /// quem não está pausado): encerrar uma sessão pausada é escolha explícita
  /// (o "Encerrar a leitura pausada" da pílula), não consequência da
  /// navegação.
  Future<void> parar() async {
    // O debounce marca a chave derrubada e onde a leitura estava: o toque
    // seguinte na mesma chave, dentro da janela, não recomeça do zero, e o
    // "Desfazer" do deslize devolve a leitura da posição exata.
    final chave = _tocandoChave;
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

  /// Retoma a leitura de [chave] que o "Desfazer" do deslize devolveu: o
  /// áudio da memória volta a tocar de [de] (onde a leitura parou). Sem o
  /// áudio na cache não há o que tocar — [de] nulo é o preparo sem pausa,
  /// que retoma do zero. Retomar é intenção explícita e não cai no debounce
  /// do toque repetido.
  Future<bool> retomar(String chave, {Duration? de}) async {
    final partes = _cache[chave];
    if (partes == null) return false;
    final versao = ++_versao;
    _tocandoChave = chave;
    _tocando = true;
    _carregando = false;
    _pausado = false;
    notifyListeners();
    // O áudio do capítulo antigo (se ainda houver um) para: o "Desfazer"
    // devolve a página e a leitura, e a sessão nova começa limpa.
    await _silenciar();
    try {
      await _tocarTudo(partes, chave, versao: versao, de: de);
    } on VozException {
      rethrow;
    } catch (_) {
      throw const VozException(
        'Não foi possível tocar o áudio. Tente de novo em instantes.',
      );
    } finally {
      if (versao == _versao) {
        _carregando = false;
        if (!_tocando && !_pausado) _tocandoChave = null;
        notifyListeners();
      }
    }
    return true;
  }

  /// Retoma a leitura pausada de fora: do áudio da memória, na posição da
  /// pausa. Se a cache despejou a sessão (24 capítulos novos), re-sintetiza
  /// com o texto da sessão em vez de morrer em silêncio. Devolve false se não
  /// havia sessão pausada.
  Future<bool> retomarDaPausa() async {
    if (!_pausado) return false;
    final chave = _tocandoChave!;
    final de = _posicaoDaPausa;
    final partes = _cache[chave];
    if (partes != null) {
      final versao = ++_versao;
      _pausado = false;
      _tocando = true;
      _carregando = false;
      notifyListeners();
      try {
        await _tocarTudo(partes, chave, versao: versao, de: de);
      } on VozException {
        rethrow;
      } catch (_) {
        throw const VozException(
          'Não foi possível tocar o áudio. Tente de novo em instantes.',
        );
      } finally {
        if (versao == _versao) {
          _carregando = false;
          if (!_tocando && !_pausado) _tocandoChave = null;
          notifyListeners();
        }
      }
      return true;
    }
    // A cache despejou a sessão: o retomar da barra não conhece o texto, mas
    // a sessão guardou como re-sintetizar — a leitura volta do zero.
    final texto = _textoDaSessao;
    final tipo = _tipoDaSessao;
    if (texto == null || tipo == null) return false;
    _posicaoDaPausa = null;
    _pausado = false;
    _carregando = false;
    _tocandoChave = null;
    await alternar(
      chave,
      texto: texto,
      tipo: tipo,
      cliente: _clienteDaSessao,
      chaveTts: _chaveTtsDaSessao,
    );
    return true;
  }

  /// Começa a tocar [partes] e devolve assim que a leitura começa (ou seja,
  /// quando o áudio está carregando no player de verdade, ou no instante do
  /// tocar no leitor de testes) — é [aoFim] quem recebe o fim da leitura, o
  /// play do player ou o tocar do leitor, para [_acompanharLeitura] esperar
  /// sem emaranhar as futures. [de] é a posição de onde a retomada continua.
  ///
  /// A fonte é sempre substituída, mesmo que o player já tenha uma: o player
  /// é de sessão, e tocar outro capítulo sem trocar a fonte tocaria o
  /// capítulo antigo de novo.
  Future<void> iniciarLeitura(
    List<Uint8List> partes, {
    required int versao,
    Duration? de,
    required void Function(Future<void> fim) aoFim,
  }) async {
    final leitor = _leitorDeAudio;
    if (leitor == null) {
      final player = _player ??= AudioPlayer();
      await player.setAudioSources([
        for (final parte in partes)
          AudioSource.uri(Uri.dataFromBytes(parte, mimeType: 'audio/mpeg')),
      ]);
      if (versao != _versao) {
        aoFim(Future<void>.value());
        return;
      }
      if (de != null) await player.seek(de);
      aoFim(player.play());
      return;
    }
    aoFim(
      versao == _versao
          ? leitor.tocar(_emendarPartes(partes), de: de)
          : Future<void>.value(),
    );
  }

  /// Acompanha a leitura até o fim e fecha o ciclo: o fim natural vira
  /// "Leitura concluída.", a pausa de fora vira a sessão "Pausado", e a
  /// interrupção limpa o estado. [fim] é o play do player ou o tocar do
  /// leitor de testes — completa quando a leitura para, pausa ou termina.
  /// [versao] descarta a chegada de uma sessão que já foi substituída
  /// (troca de chave, parada, deslize).
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
      // Pausada de fora (chamada, perda de foco), o play volta pausado, com a
      // posição e o áudio carregados: é a sessão "Pausado". O fim natural
      // volta completo.
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
      // Interrupção sem pausa: a leitura parou, mas não chegou ao fim — sem
      // "Leitura concluída." e sem sessão pausada esperando retomar.
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
    notifyListeners();
  }

  /// Toca [partes] do começo (ou de [de]) e acompanha a leitura até o fim:
  /// é o caminho do áudio inteiro já pronto — a cache, o retomar do
  /// "Desfazer" e o retomar da pausa.
  Future<void> _tocarTudo(
    List<Uint8List> partes,
    String chave, {
    required int versao,
    Duration? de,
  }) async {
    var fim = Future<void>.value();
    await iniciarLeitura(partes, versao: versao, de: de, aoFim: (f) => fim = f);
    if (versao != _versao) return;
    await _acompanharLeitura(fim, chave, versao: versao);
  }

  /// Sintetiza [texto] em streaming e toca: a primeira parte começa a tocar
  /// assim que chega — o ouvinte não espera o texto inteiro ser preparado — e
  /// as demais são emendadas na leitura enquanto ela acontece. O áudio
  /// completo entra na cache ao final: mesmo se a leitura for cancelada no
  /// meio do preparo (outra chave, deslize), a quota não se perde.
  Future<void> _tocarNovaSintese(
    String chave, {
    required String texto,
    required TipoConteudoAudio tipo,
    http.Client? cliente,
    String? chaveTts,
    required int versao,
  }) async {
    final partes = <Uint8List>[];
    var leituraComecou = false;
    final fimDaLeitura = Completer<void>();
    try {
      await sintetizarEmPartes(
        texto,
        tipo: tipo,
        cliente: cliente,
        chave: chaveTts,
        aoChegar: (parte) async {
          // A parte entra na cache antes do descarte por versão: um cancelar
          // no meio do preparo não joga fora o que a quota já pagou.
          partes.add(parte);
          if (versao != _versao) return;
          if (leituraComecou) {
            // O resto do áudio emenda na leitura que já toca (só o player de
            // verdade; o leitor de testes já recebeu o áudio inteiro).
            await _emendarNoPlayer(parte, versao: versao);
            return;
          }
          if (!_appEmPrimeiroPlano()) return;
          leituraComecou = true;
          _tocando = true;
          _carregando = false;
          notifyListeners();
          // A leitura corre em paralelo à síntese do resto: o primeiro
          // pedaço toca enquanto a fila se enche.
          await iniciarLeitura(
            partes,
            versao: versao,
            de: null,
            aoFim: (fim) {
              unawaited(
                _acompanharLeitura(fim, chave, versao: versao).whenComplete(
                  () {
                    if (!fimDaLeitura.isCompleted) fimDaLeitura.complete();
                  },
                ),
              );
            },
          );
        },
      );
    } catch (_) {
      // Um pedaço falhou depois de a leitura já ter começado: o que toca
      // deve parar — o erro volta para a tela, mas não deixa um áudio solto
      // tocando sem botão.
      if (leituraComecou) {
        _versao++;
        await _silenciar();
        _tocando = false;
        _tocandoChave = null;
        _carregando = false;
        notifyListeners();
      }
      rethrow;
    }
    _guardarNaCache(chave, partes);
    if (leituraComecou) await fimDaLeitura.future;
  }

  /// Emenda [parte] na playlist do player que já toca: é assim que o
  /// streaming enche a leitura enquanto o primeiro pedaço está no ar. No
  /// leitor de testes não há o que emendar — ele já recebeu o áudio inteiro.
  Future<void> _emendarNoPlayer(Uint8List parte, {required int versao}) async {
    if (versao != _versao) return;
    final player = _player;
    if (player == null) return;
    try {
      await player.addAudioSource(
        AudioSource.uri(Uri.dataFromBytes(parte, mimeType: 'audio/mpeg')),
      );
    } catch (_) {
      // Sem plataforma de áudio (teste, navegador sem suporte): o pedaço
      // fica na cache e a leitura segue com o que já toca.
    }
  }

  /// Silencia o que estiver tocando sem tocar no estado da sessão. Quem usa:
  /// [parar] (que antes zera o estado) e [alternar]/[retomar] (que precisam
  /// parar o áudio anterior sem apagar o estado novo).
  Future<void> _silenciar() async {
    final leitor = _leitorDeAudio;
    if (leitor != null) {
      // O leitor de testes completa o tocar pendente ao ser silenciado: é
      // assim que o [Voz] sabe que a leitura acabou (interrompida).
      await leitor.silenciar();
      return;
    }
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {
      // Sem plataforma de áudio (teste, navegador sem suporte): o estado
      // já é o final, não há o que consertar.
    }
  }

  void _guardarNaCache(String chave, List<Uint8List> partes) {
    _cache[chave] = partes;
    while (_cache.length > _limiteDaCache) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Emenda [partes] num áudio só: é o que o leitor de testes recebe. O
  /// player de verdade recebe a lista e a emenda sozinho, na playlist.
  Uint8List _emendarPartes(List<Uint8List> partes) {
    final emendado = BytesBuilder();
    for (final parte in partes) {
      emendado.add(parte);
    }
    return emendado.takeBytes();
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

  /// Interface para leitura de áudio em testes (implementada por
  /// [LeitorFalso] em [voz_estados_test.dart] e [_LeitorFalsoDoApp] em
  /// [app_test.dart]).
  LeitorDeAudio? _leitorDeAudio;

  /// Injeta um leitor de áudio falso para testes (sem plataforma real).
  /// Os testes usam isto para controlar quando o áudio termina, pausa, etc.,
  /// sem depender do just_audio.
  set injetarLeitor(LeitorDeAudio? leitor) {
    _leitorDeAudio = leitor;
    notifyListeners();
  }

  /// Lê o leitor injetado, ou cai de volta ao player real se não houver
  /// leitor falso definido. Usado internamente por [alternar], [parar], etc.
  LeitorDeAudio? get leitorDeAudio => _leitorDeAudio;

  /// Despeja o áudio da cache para testes: o próximo toque re-sintetiza em
  /// vez de vir da memória. É como 24 capítulos novos despejariam a sessão.
  void limparCacheParaTestes() {
    _cache = {};
    _versao++;
    notifyListeners();
  }

  /// Para testes: quando definido, decide sozinho se a janela está no
  /// primeiro plano ([_appEmPrimeiroPlano]) — os testes de aba escondida não
  /// têm uma janela de verdade para consultar.
  bool? primeiroPlanoParaTestes;
}

/// Mock leitor de áudio que os testes usam no lugar do just_audio.
///
/// Implementado inline nos arquivos de teste ([voz_estados_test.dart] e
/// [app_test.dart]) para evitar dependência de plataforma.
abstract class LeitorDeAudio {
  /// Toca o áudio fornecido. O parâmetro [de] é a posição (em segundos/Duration)
  /// de onde retomar caso houver uma retomada ("Desfazer" do deslize).
  Future<void> tocar(Uint8List bytes, {Duration? de});

  /// Para a leitura em andamento.
  Future<void> silenciar();

  /// Posição da reprodução atual, para o progresso.
  Stream<Duration> get posicao;

  /// Duração do áudio atual, para o progresso.
  Stream<Duration?> get duracao;

  /// Onde a leitura está agora: a retomada ("Desfazer") devolve a leitura
  /// daqui. Os leitores falsos guardam isto num campo que o teste ajusta.
  Duration? get posicaoAtual;

  /// A última reprodução terminou por uma pausa de fora (chamada, perda de
  /// foco de áudio)? O player de verdade completa o play() pausado, e é
  /// assim que a pausa é marcada — o fim natural e a parada manual não.
  bool get pausadoDeFora;

  /// A última reprodução terminou sozinha? O fim natural é o único caso que
  /// merece o "Leitura concluída."; interrupção e parada manual não.
  bool get concluida;
}