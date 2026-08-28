import 'dart:async';
import 'dart:typed_data';

import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/voz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Leitor falso sem plataforma de áudio: igual ao original, mas sem dependência
/// de cliente HTTP/TTS - agora a Voz só toca arquivo.
class LeitorFalso implements LeitorDeAudio {
  int toques = 0;
  Duration? ultimoDe;
  @override
  Duration? posicaoAtual;
  @override
  bool concluida = true;
  @override
  bool pausadoDeFora = false;
  Completer<void>? _fim;
  bool _encerramentoPendente = false;

  @override
  Future<void> tocar(
    Uint8List bytes, {
    Duration? de,
    required void Function(Future<void> fim) aoFim,
  }) {
    pausadoDeFora = false;
    toques++;
    ultimoDe = de;
    final fim = Completer<void>();
    _fim = fim;
    aoFim(fim.future);
    if (_encerramentoPendente) {
      _encerramentoPendente = false;
      fim.complete();
    }
    return Future<void>.value(); // Inicia imediatamente no mock
  }

  void encerrar() {
    final fim = _fim;
    if (fim != null && !fim.isCompleted) {
      fim.complete();
    } else {
      _encerramentoPendente = true;
    }
  }

  void pausarDeFora() {
    pausadoDeFora = true;
    encerrar();
  }

  @override
  Future<void> silenciar() async {
    final fim = _fim;
    if (fim != null && !fim.isCompleted) fim.complete();
  }

  @override
  Future<void> pausar() async => pausarDeFora();

  @override
  Stream<Duration> get posicao => const Stream.empty();

  @override
  Stream<Duration?> get duracao => const Stream.empty();
}

void main() {
  late LeitorFalso leitor;

  setUp(() async {
    await Voz.instancia.parar();
    leitor = LeitorFalso();
    Voz.instancia.injetarLeitor = leitor;
    Voz.baseUrlForTest = 'https://test.audio';
  });

  tearDown(() {
    Voz.baseUrlForTest = null;
  });

  Future<void> esperarAvisos() async {
    await pumpEventQueue();
  }

  group('máquina de estados da voz', () {
    test('dois toques rápidos na mesma chave pedem o áudio uma vez só', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);
      final primeiro = Voz.instancia.alternar(
        'capitulo:a.1',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await Voz.instancia.alternar(
        'capitulo:a.1',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await primeiro;
      await esperarAvisos();

      expect(leitor.toques, 0, reason: 'o segundo toque cancelou antes de o áudio tocar');
      expect(recebidas, isEmpty, reason: 'o toque cancelou o preparo');
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
      await sub.cancel();
    });

    test('tocar noutra chave no meio do preparo substitui a carga em voo', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);
      final primeira = Voz.instancia.alternar(
        'capitulo:b.2',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      final segunda = Voz.instancia.alternar(
        'capitulo:c.3',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      expect(Voz.instancia.carregando, isTrue);
      expect(Voz.instancia.tocandoChave, 'capitulo:c.3');

      leitor.encerrar();
      await primeira;
      await segunda;
      await esperarAvisos();

      expect(recebidas, ['capitulo:c.3'], reason: 'só a chave que ficou no ar merece o fim');
      await sub.cancel();
    });

    test('cancelar durante o preparo limpa o estado sem avisar fim', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);
      final pendente = Voz.instancia.alternar(
        'capitulo:d.4',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await Voz.instancia.parar();
      await pendente;
      await esperarAvisos();

      expect(recebidas, isEmpty);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
      await sub.cancel();
    });

    test('só o fim natural avisa "concluída": interrupção e parada manual não', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);

      final natural = Voz.instancia.alternar(
        'capitulo:e.5',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await natural;

      final interrompida = Voz.instancia.alternar(
        'capitulo:f.6',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.concluida = false;
      leitor.encerrar();
      await interrompida;

      final manual = Voz.instancia.alternar(
        'capitulo:g.7',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await Voz.instancia.parar();
      await manual;
      await esperarAvisos();

      expect(recebidas, ['capitulo:e.5']);
      await sub.cancel();
    });

    test('tocar de novo na chave recém-parada dentro do debounce não reinicia', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);

      final primeira = Voz.instancia.alternar(
        'capitulo:h.8',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await primeira;

      final segunda = Voz.instancia.alternar(
        'capitulo:h.8',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await pumpEventQueue();
      await Voz.instancia.parar();
      await segunda;

      final terceira = Voz.instancia.alternar(
        'capitulo:h.8',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await terceira;
      await esperarAvisos();

      expect(leitor.toques, 2, reason: 'a terceira chamada morreu no debounce, sem recomeçar');
      expect(recebidas, ['capitulo:h.8']);
      await sub.cancel();
    });

    test('retomar devolve a leitura da cache, da posição em que parou e sem cair no debounce', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);

      final primeira = Voz.instancia.alternar(
        'capitulo:i.9',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await primeira;
      await Voz.instancia.parar();

      leitor.posicaoAtual = const Duration(minutes: 3);
      final retomou = Voz.instancia.retomar(
        'capitulo:i.9',
        de: const Duration(minutes: 3),
      );
      leitor.encerrar();
      final retomadaComSucesso = await retomou;
      await esperarAvisos();

      expect(retomadaComSucesso, isTrue);
      expect(leitor.toques, 2, reason: 'a retomada toca de novo, apesar do debounce da parada');
      expect(leitor.ultimoDe, const Duration(minutes: 3));
      expect(recebidas, ['capitulo:i.9', 'capitulo:i.9']);
      await sub.cancel();
    });

    test('retomar sem o áudio na cache não toca nada', () async {
      final retomou = await Voz.instancia.retomar('capitulo:sem-cache.1');
      expect(retomou, isFalse);
      expect(leitor.toques, 0);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
    });

    test('alternar com posição pula o áudio para onde a leitura parou', () async {
      final leitura = Voz.instancia.alternar(
        'capitulo:k.11',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      expect(Voz.instancia.tocando, isTrue);

      leitor.posicaoAtual = const Duration(minutes: 5);
      leitor.pausarDeFora();
      await esperarAvisos();
      expect(Voz.instancia.pausado, isTrue);

      final retomada = Voz.instancia.alternar(
        'capitulo:k.11',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await retomada;
      await leitura;
      await esperarAvisos();

      expect(leitor.ultimoDe, const Duration(minutes: 5), reason: 'a retomada começa de onde a leitura parou, não do zero');
      expect(leitor.toques, 2);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
    });

    test('uma pausa de fora vira "Pausado", e tocar de novo retoma de onde parou', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);

      final leitura = Voz.instancia.alternar(
        'capitulo:l.12',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      expect(Voz.instancia.tocando, isTrue);

      leitor.posicaoAtual = const Duration(minutes: 5);
      leitor.pausarDeFora();
      await esperarAvisos();

      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.pausado, isTrue, reason: 'uma pausa de fora vira o estado "Pausado"');
      expect(Voz.instancia.tocandoChave, 'capitulo:l.12', reason: 'a sessão pausada continua viva, esperando retomar');
      expect(Voz.instancia.carregando, isFalse);
      expect(recebidas, isEmpty, reason: 'uma pausa de fora não é um fim: não há "Leitura concluída."');

      final retomada = Voz.instancia.alternar(
        'capitulo:l.12',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();

      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocando, isTrue, reason: 'o toque na sessão pausada retoma a leitura');
      expect(leitor.toques, 2);
      expect(leitor.ultimoDe, const Duration(minutes: 5), reason: 'o retomar começa de onde a leitura parou, não do zero');

      leitor.encerrar();
      await esperarAvisos();
      expect(recebidas, ['capitulo:l.12']);
      await retomada;
      await leitura;
      await sub.cancel();
    });

    test('o botão de pausa manual pausa a leitura, e o toque seguinte retoma de onde parou', () async {
      final leitura = Voz.instancia.alternar(
        'capitulo:l.13',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      expect(Voz.instancia.tocando, isTrue);

      leitor.posicaoAtual = const Duration(minutes: 2);
      await Voz.instancia.pausar();
      await esperarAvisos();

      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.pausado, isTrue, reason: 'a pausa manual vira o mesmo estado "Pausado"');
      expect(Voz.instancia.tocandoChave, 'capitulo:l.13', reason: 'a sessão pausada continua viva, esperando retomar');

      final retomada = Voz.instancia.alternar(
        'capitulo:l.13',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();

      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocando, isTrue);
      expect(leitor.ultimoDe, const Duration(minutes: 2), reason: 'a retomada volta de onde a pausa manual parou, não do zero');

      leitor.encerrar();
      await esperarAvisos();
      await retomada;
      await leitura;
    });

    test('parar() encerra uma sessão pausada de vez', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);

      final leitura = Voz.instancia.alternar(
        'capitulo:m.13',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      leitor.pausarDeFora();
      await esperarAvisos();
      expect(Voz.instancia.pausado, isTrue);

      await Voz.instancia.parar();
      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
      expect(recebidas, isEmpty);
      await leitura;
      await sub.cancel();
    });

    test('o áudio que fica pronto com a janela escondida não começa sozinho', () async {
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);
      Voz.instancia.primeiroPlanoParaTestes = false;
      addTearDown(() => Voz.instancia.primeiroPlanoParaTestes = null);

      final leitura = Voz.instancia.alternar(
        'capitulo:n.14',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();

      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
      expect(leitor.toques, 0, reason: 'tocar com a janela escondida seria tocar para ninguém');
      expect(recebidas, isEmpty, reason: 'não tocou, não há fim: nada de "Leitura concluída."');
      await leitura;

      Voz.instancia.primeiroPlanoParaTestes = true;
      final segunda = Voz.instancia.alternar(
        'capitulo:n.14',
        texto: 'Texto.',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await segunda;
      await esperarAvisos();

      expect(leitor.toques, 1);
      expect(recebidas, ['capitulo:n.14']);
      await sub.cancel();
    });

    test('trocar de chave durante a leitura: o preparo novo não herda "tocando", e o retry não vira parar', () async {
      final primeira = Voz.instancia.alternar(
        'capitulo:o.15',
        texto: 'A.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      expect(Voz.instancia.tocando, isTrue);

      // Simula troca rápida: segunda chave assume
      final segunda = Voz.instancia.alternar(
        'capitulo:p.16',
        texto: 'B.',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();

      expect(Voz.instancia.tocando, isFalse, reason: 'o "tocando" da sessão antiga morre na troca');
      expect(Voz.instancia.carregando, isTrue);
      expect(Voz.instancia.tocandoChave, 'capitulo:p.16');
      await primeira;

      // Segunda ainda carregando, encerra como falha de rede simulada:
      // força parar para limpar estado
      await Voz.instancia.parar();
      await segunda;
      await esperarAvisos();
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull, reason: 'o estado mentiroso não fica preso após o erro');

      final retry = Voz.instancia.alternar(
        'capitulo:p.16',
        texto: 'B.',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await retry;
      await esperarAvisos();

      expect(leitor.toques, 2);
      expect(Voz.instancia.tocando, isFalse);
    });
  });
}
