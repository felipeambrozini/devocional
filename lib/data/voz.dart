import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
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
/// Para trocar de voz ou de interpretação, basta editar as constantes abaixo e
/// audicionar em https://cloud.google.com/text-to-speech (sem chave). As vozes
/// masculinas de pt-BR são: Neural2-B, Wavenet-B, Wavenet-E e Standard-B/E.
const _voz = 'pt-BR-Neural2-B';

/// Ritmo mais lento que o natural: a leitura cadenciada que a gravidade do
/// texto pede. 1.0 é o ritmo padrão da voz.
const _ritmo = 0.92;

/// Tom dois semitons abaixo do natural, para o barítono encorpado. Em st
/// (semitons): -2 é grave sem virar artificial.
const _tom = -2.0;

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

/// Cliente compartilhado do app. Os testes injetam o próprio cliente falso.
final _clientePadrao = http.Client();

/// Sintetiza [texto] na voz de Spurgeon e devolve o áudio MP3.
///
/// [cliente] e [chave] existem só para os testes injetarem um HTTP falso e a
/// chave que quiserem; quem chama de verdade usa a chave TTS_API_KEY do build
/// (em `lib/data/google.dart`) e o cliente global do pacote `http`.
Future<Uint8List> sintetizar(
  String texto, {
  http.Client? cliente,
  String? chave,
}) async {
  final chaveUsada = chave ?? chaveTts;
  if (chaveUsada.isEmpty) {
    throw const VozException(
      'A voz de Spurgeon ainda não foi ligada: o build precisa da chave '
      'TTS_API_KEY.',
    );
  }

  final http.Response resposta;
  try {
    resposta = await (cliente ?? _clientePadrao)
        .post(
          Uri.parse(
            'https://texttospeech.googleapis.com/v1/text:synthesize'
            '?key=$chaveUsada',
          ),
          headers: await cabecalhosGoogle(),
          body: json.encode({
            'input': {'text': texto},
            'voice': {'languageCode': 'pt-BR', 'name': _voz},
            'audioConfig': {
              'audioEncoding': 'MP3',
              'speakingRate': _ritmo,
              'pitch': _tom,
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
  final audio = corpo['audioContent'];
  if (audio is! String || audio.isEmpty) {
    throw const VozException('O áudio veio vazio. Tente de novo.');
  }
  return base64.decode(audio);
}

/// 400 e 403 são a chave sem a API ativada ou sem a restrição certa; 429 é o
/// teto do tier gratuito. Não se envia o corpo da API ao usuário: é inglês
/// técnico que não ajuda ninguém, e a maioria dos leitores não tem o Cloud
/// Console. O detalhe técnico vai para o log, onde quem mantém o app procura.
String _mensagemDeErro(http.Response resposta) {
  if (resposta.statusCode == 400 || resposta.statusCode == 403) {
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
  /// "capitulo:joao.3"). A chave do cache é a mesma que o botão usa para
  /// saber o que está tocando agora.
  final Map<String, Uint8List> _cache = {};

  /// O que a memória segura de áudio de uma vez. Um capítulo inteiro em MP3
  /// pesa ~150 KB; 24 cabem folgados e cobrem o ir e vir das leituras do dia.
  static const _limiteDaCache = 24;

  /// Contador de pedidos: trocar de capítulo ou fechar a tela no meio do
  /// carregamento não pode tocar um áudio que ninguém quer mais.
  int _versao = 0;

  bool _tocando = false;
  bool _carregando = false;
  String? _tocandoChave;

  /// Há um áudio tocando agora (a leitura começou e não terminou).
  bool get tocando => _tocando;

  /// A voz ainda está preparando o áudio (baixando da Google).
  bool get carregando => _carregando;

  /// O que está tocando ou carregando: o botão com a mesma chave mostra
  /// "Parar", e os outros ficam em "Ouvir".
  String? get tocandoChave => _tocandoChave;

  /// A posição da leitura atual, para a linha fina de progresso do botão. Sem
  /// player (nos testes não há plataforma de áudio) a stream fica vazia e
  /// nada é desenhado.
  Stream<Duration> get posicao => _player?.positionStream ?? Stream<Duration>.empty();

  /// A duração total do áudio carregado, que junto com [posicao] vira o
  /// progresso. É nula até o player conhecer o áudio.
  Stream<Duration?> get duracao =>
      _player?.durationStream ?? Stream<Duration?>.empty();

  /// Avisa quando uma leitura chega ao fim sozinha, com a chave do que
  /// terminou ("capitulo:joao.3"). O botão dessa chave mostra a confirmação
  /// "Leitura concluída." — parar no meio, pelo usuário ou pela navegação,
  /// não emite nada.
  Stream<String> get conclusoes => _conclusoes.stream;

  final StreamController<String> _conclusoes = StreamController.broadcast();

  /// Toca [texto] na voz de Spurgeon, ou para se ele já estiver tocando.
  ///
  /// [chave] identifica o que se ouve ("capitulo:joao.3"); tocar de novo a
  /// mesma chave para a leitura, e outra chave troca o áudio sem precisar de
  /// dois toques.
  ///
  /// Erros viram [VozException] para a tela avisar; o estado fica limpo nos
  /// dois casos (erro e sucesso).
  Future<void> alternar(String chave, String texto) async {
    // O guard é síncrono e vem antes de tudo: a quota é por caractere, e dois
    // toques rápidos não podem atravessar o primeiro await e pedir o mesmo
    // áudio duas vezes.
    if (_carregando) return;
    if (_tocando && _tocandoChave == chave) {
      await parar();
      return;
    }

    final versao = ++_versao;
    _tocandoChave = chave;
    _carregando = true;
    notifyListeners();
    // O áudio anterior (de outra chave) para sem mexer no estado da sessão
    // nova: o player é um só, e só ele precisa ser silenciado. Tocar em
    // "Preparando…" cancela com [parar], que zera esse estado.
    await _silenciar();
    try {
      final bytes = await _obterAudio(chave, texto);
      if (versao != _versao) return;
      final player = _player ??= AudioPlayer();
      await player.setAudioSource(
        AudioSource.uri(Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg')),
      );
      if (versao != _versao) return;
      _tocando = true;
      try {
        // Completa quando a leitura para, pausa ou chega ao fim: o botão
        // volta a "Ouvir" sem ninguém precisar avisar.
        await player.play();
      } finally {
        if (versao == _versao && _tocando) {
          _tocando = false;
          _tocandoChave = null;
          // Chegou ao fim sozinho (parar e trocar de chave incrementam
          // _versao e caem fora deste if): é o momento de fechar o ciclo com
          // o "Leitura concluída.".
          _conclusoes.add(chave);
          notifyListeners();
        }
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
        if (!_tocando) _tocandoChave = null;
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
  Future<void> parar() async {
    _versao++;
    _tocando = false;
    _carregando = false;
    _tocandoChave = null;
    await _silenciar();
    notifyListeners();
  }

  /// Silencia o player sem tocar no estado da sessão. Quem usa: [parar]
  /// (que antes zera o estado) e [alternar] (que precisa parar o áudio
  /// anterior sem apagar o estado novo).
  Future<void> _silenciar() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {
      // Sem plataforma de áudio (teste, navegador sem suporte): o estado
      // já é o final, não há o que consertar.
    }
  }

  void _guardarNaCache(String chave, Uint8List bytes) {
    _cache[chave] = bytes;
    while (_cache.length > _limiteDaCache) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// O áudio de [chave], da memória se já foi sintetizado nesta sessão, ou
  /// recém-baixado da Google. A cache só guarda áudio pronto: um erro de
  /// síntese não deixa um buraco que faria o próximo toque falhar do mesmo
  /// jeito.
  Future<Uint8List> _obterAudio(String chave, String texto) async {
    final guardado = _cache[chave];
    if (guardado != null) return guardado;
    final novo = await sintetizar(texto);
    _guardarNaCache(chave, novo);
    return novo;
  }
}
