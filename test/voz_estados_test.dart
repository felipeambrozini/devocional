import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/voz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Um leitor sem plataforma de áudio: o teste decide quando a leitura
/// termina ([encerrar]), se ela terminou sozinha ([concluida]) e se uma pausa
/// de fora a interrompeu ([pausarDeFora]) — é o que separa o fim natural da
/// interrupção (chamada, perda de foco de áudio).
class LeitorFalso implements LeitorDeAudio {
  /// Quantas vezes o áudio chegou a tocar de verdade.
  int toques = 0;

  /// A posição pedida no último [tocar] ([LeitorDeAudio.tocar] com [de]): é o
  /// que a retomada do "Desfazer" precisa entregar.
  Duration? ultimoDe;

  /// A posição da leitura, como o player de verdade reporta. O teste ajusta
  /// antes do deslize para o "Desfazer" retomar de onde o áudio estava.
  @override
  Duration? posicaoAtual;

  /// O que a [Voz] vê quando uma leitura termina: true é fim natural, false
  /// é interrupção. O teste ajusta antes de [encerrar].
  @override
  bool concluida = true;

  /// A última reprodução terminou por uma pausa de fora ([pausarDeFora]) em
  /// vez de por um fim natural ou por um [silenciar]? O player de verdade
  /// marca isto sozinho quando o play() volta pausado, sem fim natural.
  @override
  bool pausadoDeFora = false;

  Completer<void>? _fim;

  /// Um encerramento que chegou antes de haver um tocar pendente (o fluxo da
  /// [Voz] ainda estava no `await _silenciar`, por exemplo): o próximo tocar
  /// completa na hora. Sem isto os testes dependeriam do timing exato das
  /// microtarefas — em que await o fluxo está quando o teste chama
  /// [encerrar] — e o pedido morreria em silêncio.
  bool _encerramentoPendente = false;

  @override
  Future<void> tocar(Uint8List bytes, {Duration? de}) {
    pausadoDeFora = false;
    toques++;
    ultimoDe = de;
    final fim = Completer<void>();
    _fim = fim;
    if (_encerramentoPendente) {
      _encerramentoPendente = false;
      fim.complete();
    }
    return fim.future;
  }

  @override
  Future<void> silenciar() async {
    // O player de verdade completa o play() ao ser silenciado: é assim que
    // o Voz sabe que a leitura acabou (interrompida). Só o tocar em voo é
    // completado; silenciar um leitor em repouso não marca nada — senão o
    // preparo de uma chave nova completaria o play dela antes da hora.
    final fim = _fim;
    if (fim != null && !fim.isCompleted) fim.complete();
  }

  /// O áudio chegou ao fim: completa o tocar pendente, como o player de
  /// verdade ao terminar a reprodução. Se o fluxo ainda não chegou ao tocar,
  /// o fim é lembrado e o próximo tocar completa na hora — os testes não
  /// dependem do timing exato das microtarefas.
  void encerrar() {
    final fim = _fim;
    if (fim != null && !fim.isCompleted) {
      fim.complete();
    } else {
      _encerramentoPendente = true;
    }
  }

  /// Uma chamada ou a perda de foco de áudio pausou a leitura: o player de
  /// verdade completa o play() pausado, e é assim que a pausa é marcada. A
  /// posição onde a leitura parou fica no [posicaoAtual], que o teste ajusta
  /// antes.
  void pausarDeFora() {
    pausadoDeFora = true;
    encerrar();
  }

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
  });

  /// Um cliente que conta quantas vezes a síntese foi pedida: é a quota do
  /// tier gratuito, e é o que o guard de toques duplicados protege.
  MockClient clienteQueConta(List<int> pedidos) => MockClient((request) async {
    pedidos.add(1);
    return http.Response(
      json.encode({'audioContent': base64.encode([1, 2, 3])}),
      200,
    );
  });

  Future<void> esperarAvisos() async {
    // As conclusões chegam por stream (microtarefa): espera a fila esvaziar
    // antes de conferir quem recebeu aviso.
    await pumpEventQueue();
  }

  group('máquina de estados da voz', () {
    test(
      'dois toques rápidos na mesma chave pedem o áudio uma vez só',
      () async {
        final pedidos = <int>[];
        final recebidas = <String>[];
        final sub = Voz.instancia.conclusoes.listen(recebidas.add);
        final primeiro = Voz.instancia.alternar(
          'capitulo:a.1',
          texto: 'Texto.',
          cliente: clienteQueConta(pedidos),
          chaveTts: 'teste',
          tipo: TipoConteudoAudio.biblia,
        );
        // O segundo toque chega no meio do preparo: é o botão cancelando, e
        // não pode pedir o áudio de novo.
        await Voz.instancia.alternar(
          'capitulo:a.1',
          texto: 'Texto.',
          cliente: clienteQueConta(pedidos),
          chaveTts: 'teste',
          tipo: TipoConteudoAudio.biblia,
        );
        await primeiro;
        await esperarAvisos();

        expect(pedidos, hasLength(1));
        expect(leitor.toques, 0,
            reason: 'o segundo toque cancelou antes de o áudio tocar');
        expect(recebidas, isEmpty, reason: 'o toque cancelou o preparo');
        expect(Voz.instancia.tocando, isFalse);
        expect(Voz.instancia.carregando, isFalse);
        expect(Voz.instancia.tocandoChave, isNull);
        await sub.cancel();
      },
    );

    test('tocar noutra chave no meio do preparo substitui a carga em voo', () async {
      final pedidos = <int>[];
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);
      final primeira = Voz.instancia.alternar(
        'capitulo:b.2',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      final segunda = Voz.instancia.alternar(
        'capitulo:c.3',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      // A nova chave já manda na sessão: o toque não morreu em silêncio.
      expect(Voz.instancia.carregando, isTrue);
      expect(Voz.instancia.tocandoChave, 'capitulo:c.3');

      leitor.encerrar();
      await primeira;
      await segunda;
      await esperarAvisos();

      expect(pedidos, hasLength(2));
      expect(recebidas, ['capitulo:c.3'],
          reason: 'só a chave que ficou no ar merece o fim');
      await sub.cancel();
    });

    test('cancelar durante o preparo limpa o estado sem avisar fim', () async {
      final pedidos = <int>[];
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);
      final pendente = Voz.instancia.alternar(
        'capitulo:d.4',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await Voz.instancia.parar();
      await pendente;
      await esperarAvisos();

      expect(pedidos, hasLength(1));
      expect(recebidas, isEmpty);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
      await sub.cancel();
    });

    test(
      'só o fim natural avisa "concluída": interrupção e parada manual não',
      () async {
        final pedidos = <int>[];
        final recebidas = <String>[];
        final sub = Voz.instancia.conclusoes.listen(recebidas.add);
        final cliente = clienteQueConta(pedidos);

        // Fim natural: o áudio terminou sozinho, e o ciclo fecha com o aviso.
        final natural = Voz.instancia.alternar(
          'capitulo:e.5',
          texto: 'Texto.',
          cliente: cliente,
          chaveTts: 'teste',
          tipo: TipoConteudoAudio.biblia,
        );
        leitor.encerrar();
        await natural;

        // Interrupção (chamada, perda de foco): a leitura parou, mas não
        // chegou ao fim — o gate é o estado do leitor, não o retorno do play.
        final interrompida = Voz.instancia.alternar(
          'capitulo:f.6',
          texto: 'Texto.',
          cliente: cliente,
          chaveTts: 'teste',
          tipo: TipoConteudoAudio.biblia,
        );
        leitor.concluida = false;
        leitor.encerrar();
        await interrompida;

        // Parada manual: o próprio botão, sem fim algum.
        final manual = Voz.instancia.alternar(
          'capitulo:g.7',
          texto: 'Texto.',
          cliente: cliente,
          chaveTts: 'teste',
          tipo: TipoConteudoAudio.biblia,
        );
        await Voz.instancia.parar();
        await manual;
        await esperarAvisos();

        expect(pedidos, hasLength(3));
        expect(recebidas, ['capitulo:e.5']);
        await sub.cancel();
      },
    );

    test('tocar de novo na chave recém-parada dentro do debounce não reinicia',
        () async {
      final pedidos = <int>[];
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);
      final cliente = clienteQueConta(pedidos);

      final primeira = Voz.instancia.alternar(
        'capitulo:h.8',
        texto: 'Texto.',
        cliente: cliente,
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await primeira;

      // Toca de novo, e para: o segundo toque de "Parar" é o gesto repetido.
      // A segunda chamada não re-sintetiza (o áudio já está na cache), mas
      // recomeça a reprodução — é esse reinício que o debounce precisa parar.
      final segunda = Voz.instancia.alternar(
        'capitulo:h.8',
        texto: 'Texto.',
        cliente: cliente,
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      // Deixa a segunda leitura começar a tocar: o parar() abaixo tem de
      // interromper uma reprodução em andamento — parar um preparo cancelaria
      // a leitura antes do tocar, e o teste do debounce não chegaria ao caso.
      await pumpEventQueue();
      await Voz.instancia.parar();
      await segunda;

      // E o toque seguinte, ainda dentro da janela, não recomeça a leitura.
      final terceira = Voz.instancia.alternar(
        'capitulo:h.8',
        texto: 'Texto.',
        cliente: cliente,
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await terceira;
      await esperarAvisos();

      expect(pedidos, hasLength(1),
          reason: 'a cache cobre o segundo toque: uma síntese só');
      expect(leitor.toques, 2,
          reason: 'a terceira chamada morreu no debounce, sem recomeçar');
      expect(recebidas, ['capitulo:h.8']);
      await sub.cancel();
    });

    test(
      'retomar devolve a leitura da cache, da posição em que parou e sem '
      'cair no debounce',
      () async {
        final pedidos = <int>[];
        final recebidas = <String>[];
        final sub = Voz.instancia.conclusoes.listen(recebidas.add);

        // A leitura toca e termina sozinha, e o usuário para.
        final primeira = Voz.instancia.alternar(
          'capitulo:i.9',
          texto: 'Texto.',
          cliente: clienteQueConta(pedidos),
          chaveTts: 'teste',
          tipo: TipoConteudoAudio.biblia,
        );
        leitor.encerrar();
        await primeira;
        await Voz.instancia.parar();

        // O "Desfazer" do deslize guardou a posição antes da parada: a
        // retomada vem da memória (a quota não é gasta de novo) e começa de
        // onde estava — mesmo dentro da janela do debounce, porque retomar
        // é intenção explícita, não o segundo toque de "Parar".
        leitor.posicaoAtual = const Duration(minutes: 3);
        final retomou = Voz.instancia.retomar(
          'capitulo:i.9',
          de: const Duration(minutes: 3),
        );
        leitor.encerrar();
        final retomadaComSucesso = await retomou;
        await esperarAvisos();

        expect(retomadaComSucesso, isTrue);
        expect(pedidos, hasLength(1),
            reason: 'a cache cobre o retorno: nenhuma síntese nova');
        expect(leitor.toques, 2,
            reason: 'a retomada toca de novo, apesar do debounce da parada');
        expect(leitor.ultimoDe, const Duration(minutes: 3));
        // A primeira leitura terminou sozinha, e a retomada também: cada fim
        // natural merece a confirmação — a retomada não é uma parada disfarçada.
        expect(recebidas, ['capitulo:i.9', 'capitulo:i.9']);
        await sub.cancel();
      },
    );

    test('retomar sem o áudio na cache não toca nada', () async {
      // O deslize derrubou um preparo que ainda não tinha terminado: não há
      // áudio guardado, e o "Desfazer" não tem o que devolver.
      final retomou = await Voz.instancia.retomar('capitulo:sem-cache.1');

      expect(retomou, isFalse);
      expect(leitor.toques, 0);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
    });

    test('alternar com posição pula o áudio para onde a leitura parou',
        () async {
      final pedidos = <int>[];
      final leitura = Voz.instancia.alternar(
        'capitulo:k.11',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      expect(Voz.instancia.tocando, isTrue);

      // A chamada chega no meio da leitura: a sessão fica pausada no 5:00.
      leitor.posicaoAtual = const Duration(minutes: 5);
      leitor.pausarDeFora();
      await esperarAvisos();
      expect(Voz.instancia.pausado, isTrue);

      // O toque na mesma chave retoma de onde a leitura parou, do áudio da
      // memória: a posição da pausa é o de do próximo tocar.
      final retomada = Voz.instancia.alternar(
        'capitulo:k.11',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await retomada;
      await leitura;
      await esperarAvisos();

      expect(leitor.ultimoDe, const Duration(minutes: 5),
          reason: 'a retomada começa de onde a leitura parou, não do zero');
      expect(leitor.toques, 2);
      expect(pedidos, hasLength(1),
          reason: 'a retomada usa o áudio da cache: a quota não é gasta de novo');
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
    });

    test('uma pausa de fora vira "Pausado", e tocar de novo retoma de onde '
        'parou', () async {
      final pedidos = <int>[];
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);

      final leitura = Voz.instancia.alternar(
        'capitulo:l.12',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      expect(Voz.instancia.tocando, isTrue);

      // A chamada chega no meio da leitura: o player pausa sozinho, no ponto
      // em que estava. A sessão não pode morrer nem mentir — fica "Pausado".
      leitor.posicaoAtual = const Duration(minutes: 5);
      leitor.pausarDeFora();
      await esperarAvisos();

      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.pausado, isTrue,
          reason: 'uma pausa de fora vira o estado "Pausado"');
      expect(Voz.instancia.tocandoChave, 'capitulo:l.12',
          reason: 'a sessão pausada continua viva, esperando retomar');
      expect(Voz.instancia.carregando, isFalse);
      expect(recebidas, isEmpty,
          reason: 'uma pausa de fora não é um fim: não há "Leitura concluída."');

      // O toque no botão da mesma chave retoma do áudio que já está na
      // memória, no ponto em que parou — sem pedir a síntese de novo.
      final retomada = Voz.instancia.alternar(
        'capitulo:l.12',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();

      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocando, isTrue,
          reason: 'o toque na sessão pausada retoma a leitura');
      expect(leitor.toques, 2);
      expect(leitor.ultimoDe, const Duration(minutes: 5),
          reason: 'o retomar começa de onde a leitura parou, não do zero');
      expect(pedidos, hasLength(1),
          reason: 'o retomar usa o áudio da cache: a quota não é gasta de novo');

      // E o fim natural da retomada conclui a leitura como qualquer outra.
      leitor.encerrar();
      await esperarAvisos();
      expect(recebidas, ['capitulo:l.12']);
      await retomada;
      await leitura;
      await sub.cancel();
    });

    test('parar() encerra uma sessão pausada de vez', () async {
      final pedidos = <int>[];
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);

      final leitura = Voz.instancia.alternar(
        'capitulo:m.13',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      leitor.pausarDeFora();
      await esperarAvisos();
      expect(Voz.instancia.pausado, isTrue);

      // O usuário desistiu da leitura pausada: o parar (do indicador da
      // barra, por exemplo) encerra a sessão inteira, sem retomar fantasma.
      await Voz.instancia.parar();
      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
      expect(recebidas, isEmpty);
      await leitura;
      await sub.cancel();
    });

    test('o áudio que fica pronto com a janela escondida não começa sozinho',
        () async {
      final pedidos = <int>[];
      final recebidas = <String>[];
      final sub = Voz.instancia.conclusoes.listen(recebidas.add);
      Voz.instancia.primeiroPlanoParaTestes = false;
      addTearDown(() => Voz.instancia.primeiroPlanoParaTestes = null);

      final leitura = Voz.instancia.alternar(
        'capitulo:n.14',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();

      // A síntese terminou, mas a janela está escondida (aba oculta na web,
      // tela bloqueada, ligação): nada toca e nada conclui — o áudio fica na
      // cache esperando o primeiro plano.
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
      expect(leitor.toques, 0,
          reason: 'tocar com a janela escondida seria tocar para ninguém');
      expect(recebidas, isEmpty,
          reason: 'não tocou, não há fim: nada de "Leitura concluída."');
      await leitura;

      // De volta ao primeiro plano, o mesmo toque toca na hora, da memória.
      Voz.instancia.primeiroPlanoParaTestes = true;
      final segunda = Voz.instancia.alternar(
        'capitulo:n.14',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await segunda;
      await esperarAvisos();

      expect(leitor.toques, 1);
      expect(pedidos, hasLength(1),
          reason: 'a cache guardou o áudio do pedido escondido');
      expect(recebidas, ['capitulo:n.14']);
      await sub.cancel();
    });

    test('trocar de chave durante a leitura: o preparo novo não herda '
        '"tocando", e o retry não vira parar', () async {
      final pedidos = <int>[];
      final primeira = Voz.instancia.alternar(
        'capitulo:o.15',
        texto: 'A.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      expect(Voz.instancia.tocando, isTrue);

      // A troca para outra chave segura o pedido (cliente que só responde
      // quando o teste deixa): enquanto a síntese nova espera, o estado tem
      // de dizer "preparando", não "lendo".
      final resposta = Completer<http.Response>();
      final cliente = MockClient((_) => resposta.future);
      final troca = Voz.instancia.alternar(
        'capitulo:p.16',
        texto: 'B.',
        cliente: cliente,
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();

      expect(Voz.instancia.tocando, isFalse,
          reason: 'o "tocando" da sessão antiga morre na troca');
      expect(Voz.instancia.carregando, isTrue);
      expect(Voz.instancia.tocandoChave, 'capitulo:p.16');
      await primeira;

      // A síntese falha: o estado volta ao repouso, e o "Tentar de novo" do
      // aviso pode tentar de verdade — não vira um parar disfarçado.
      resposta.complete(http.Response('erro', 500));
      await expectLater(troca, throwsA(isA<VozException>()));
      await esperarAvisos();
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.carregando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull,
          reason: 'o estado mentiroso não fica preso após o erro');

      // E o retry da mesma chave toca de verdade — o guard de "chave tocando"
      // não o engole como se fosse o segundo toque de um parar.
      final retry = Voz.instancia.alternar(
        'capitulo:p.16',
        texto: 'B.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await retry;
      await esperarAvisos();

      expect(leitor.toques, 2);
      expect(Voz.instancia.tocando, isFalse);
      expect(pedidos, hasLength(2));
    });

    test('pausada, a pílula com a cache despejada recomeça em vez de morrer '
        'em silêncio', () async {
      final pedidos = <int>[];
      final leitura = Voz.instancia.alternar(
        'capitulo:q.17',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      leitor.posicaoAtual = const Duration(minutes: 5);
      leitor.pausarDeFora();
      await esperarAvisos();
      expect(Voz.instancia.pausado, isTrue);

      // 24 capítulos novos despejaram o áudio da sessão pausada: o retomar
      // não tem o que tocar. O toque na pílula não pode ficar mudo — a
      // sessão pausada vira um toque comum, que sintetiza de novo.
      Voz.instancia.limparCacheParaTestes();
      final toque = Voz.instancia.alternar(
        'capitulo:q.17',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      leitor.encerrar();
      await toque;
      await esperarAvisos();

      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocando, isFalse);
      expect(leitor.toques, 2,
          reason: 'o toque recomeçou a leitura em vez de morrer em silêncio');
      expect(pedidos, hasLength(2),
          reason: 'a síntese nova substitui o áudio despejado');
      await leitura;
    });

    test('a barra retoma a pausa cuja cache despejou, re-sintetizando em vez '
        'de morrer em silêncio', () async {
      final pedidos = <int>[];
      final leitura = Voz.instancia.alternar(
        'capitulo:r.18',
        texto: 'Texto.',
        cliente: clienteQueConta(pedidos),
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await esperarAvisos();
      leitor.posicaoAtual = const Duration(minutes: 2);
      leitor.pausarDeFora();
      await esperarAvisos();
      expect(Voz.instancia.pausado, isTrue);

      // A barra não conhece o texto: o retomar dele (cache vazia) teria nada
      // a tocar. Em vez de morrer mudo, a Voz re-sintetiza — o áudio volta.
      Voz.instancia.limparCacheParaTestes();
      final retomada = Voz.instancia.retomarDaPausa();
      leitor.encerrar();
      await retomada;
      await leitura;
      await esperarAvisos();

      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
      expect(pedidos, hasLength(2),
          reason: 'a síntese do retomar substituiu o áudio despejado');
    });
  });
}