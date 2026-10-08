import 'dart:async';
import 'dart:typed_data';

import 'package:felipe_ambrozini/controladores/biblia_controlador.dart';
import 'package:felipe_ambrozini/dados/audio_offline.dart';
import 'package:felipe_ambrozini/dados/conteudo.dart';
import 'package:felipe_ambrozini/dados/estado.dart';
import 'package:felipe_ambrozini/dados/recursos.dart';
import 'package:felipe_ambrozini/dados/voz.dart';
import 'package:felipe_ambrozini/funcoes/aviso.dart';
import 'package:felipe_ambrozini/telas/biblia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Leitor falso que só termina quando o teste manda: igual ao de
/// `voz_estados_test.dart`, mas local para este arquivo não depender de
/// outro teste.
class LeitorFalsoDaSequencia implements LeitorDeAudio {
  Completer<void>? _fim;

  @override
  Duration? posicaoAtual;

  @override
  bool concluida = true;

  @override
  bool pausadoDeFora = false;

  @override
  Future<void> tocar(
    Uint8List bytes, {
    Duration? de,
    required void Function(Future<void> fim) aoFim,
  }) {
    pausadoDeFora = false;
    final fim = Completer<void>();
    _fim = fim;
    aoFim(fim.future);
    return Future<void>.value();
  }

  /// O áudio chega ao fim sozinho: é o que dispara a cadeia.
  void encerrar() {
    final fim = _fim;
    if (fim != null && !fim.isCompleted) fim.complete();
  }

  @override
  Future<void> silenciar() async {
    final fim = _fim;
    if (fim != null && !fim.isCompleted) fim.complete();
  }

  @override
  Future<void> pausar() async {}

  // Duração conhecida: com ela nula a barrinha de progresso da pílula fica
  // indeterminada (animação perpétua) e nenhum `pumpAndSettle` assentaria
  // com áudio tocando — mesmo padrão do falso do `app_test`.
  @override
  Stream<Duration> get posicao => Stream<Duration>.value(Duration.zero);

  @override
  Stream<Duration?> get duracao =>
      Stream<Duration?>.value(const Duration(minutes: 20));
}

void main() {
  late LeitorFalsoDaSequencia leitor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Voz.instancia.parar();
    leitor = LeitorFalsoDaSequencia();
    Voz.instancia.injetarLeitor = leitor;
    Voz.baseUrlForTest = 'https://test.audio';
    // Evita bater no path_provider de verdade: sem plugin registrado em
    // teste de widget, a checagem de disponibilidade nunca resolveria.
    AudioOffline.temOfflineParaTeste = (_) => false;
    Recursos.ouvirTextosForcado = true;
  });

  tearDown(() async {
    await Voz.instancia.parar();
    Voz.instancia.injetarLeitor = null;
    Voz.baseUrlForTest = null;
    Voz.disponibilidadeRemotaParaTeste = null;
    AudioOffline.temOfflineParaTeste = null;
    Recursos.ouvirTextosForcado = null;
  });

  group('proximoCapitulo', () {
    test('avança dentro do livro', () {
      final c = BibliaControlador(livroInicial: 'genesis', capituloInicial: 1);
      expect(c.proximoCapitulo(1), ('genesis', 2));
      c.dispose();
    });

    test('atravessa para o livro vizinho', () {
      final c = BibliaControlador(livroInicial: 'genesis', capituloInicial: 50);
      expect(c.proximoCapitulo(1), ('exodo', 1));
      c.dispose();
    });

    test('null nos extremos do canon', () {
      final ultimo = BibliaControlador(
        livroInicial: 'apocalipse',
        capituloInicial: 22,
      );
      expect(ultimo.proximoCapitulo(1), isNull);
      ultimo.dispose();

      final primeiro = BibliaControlador(
        livroInicial: 'genesis',
        capituloInicial: 1,
      );
      expect(primeiro.proximoCapitulo(-1), isNull);
      primeiro.dispose();
    });
  });

  group('preferência', () {
    test('desligada por padrão e persiste', () async {
      final estado = Estado(await SharedPreferences.getInstance());
      expect(estado.reproducaoContinua, isFalse);

      await estado.definirReproducaoContinua(true);
      expect(estado.reproducaoContinua, isTrue);
      final reaberto = Estado(await SharedPreferences.getInstance());
      expect(reaberto.reproducaoContinua, isTrue);
    });
  });

  group('cadeia no leitor', () {
    Future<void> aquecer(
      WidgetTester tester, {
      required String livro,
      required List<int> capitulos,
    }) =>
        tester.runAsync(() async {
          for (final n in capitulos) {
            await Conteudo.instancia.capitulo(livro, n);
          }
        });

    Future<void> montar(
      WidgetTester tester,
      Estado estado, {
      String? livro,
      int? capitulo,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: estado,
            child: TelaBiblia(
              livroInicial: livro,
              capituloInicial: capitulo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // O título do capítulo aparece duas vezes (barra e corpo): o recorte
    // pela AppBar diz onde o leitor está.
    Finder tituloNaBarra(String texto) => find.descendant(
      of: find.byType(AppBar),
      matching: find.text(texto),
    );

    // O `alternar` só retorna no fim do áudio, e o preparo mostra um giro
    // indeterminado (animação perpétua): um `pumpAndSettle` ali travaria.
    // Um `pump` mostra o preparo, o encerrar termina a leitura; a conclusão
    // mostra o aviso de 3s ("Leitura concluída"), então avança o relógio
    // para não deixar o timer pendente — mesmo padrão do `app_test`.
    Future<void> tocarAteOFim(WidgetTester tester, String chave) async {
      final tocando = Voz.instancia.alternar(chave);
      await tester.pump();
      leitor.encerrar();
      await tocando;
      await tester.pump(duracaoDeAviso);
      await tester.pumpAndSettle();
    }

    testWidgets('ligada, o próximo capítulo começa sozinho', (tester) async {
      await aquecer(tester, livro: 'genesis', capitulos: [1, 2]);
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirReproducaoContinua(true);
      await montar(tester, estado);
      expect(tituloNaBarra('Gênesis 1'), findsOneWidget);

      await tocarAteOFim(tester, 'capitulo:genesis.1');

      expect(tituloNaBarra('Gênesis 2'), findsOneWidget);
      expect(Voz.instancia.tocandoChave, 'capitulo:genesis.2');
      expect(estado.ultimaLeitura, ('genesis', 2));
    });

    testWidgets('desligada, o capítulo termina em silêncio', (tester) async {
      await aquecer(tester, livro: 'genesis', capitulos: [1, 2]);
      final estado = Estado(await SharedPreferences.getInstance());
      await montar(tester, estado);

      await tocarAteOFim(tester, 'capitulo:genesis.1');

      expect(tituloNaBarra('Gênesis 1'), findsOneWidget);
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.tocandoChave, isNull);
    });

    testWidgets('com o Ouvir desligado no painel, não encadeia', (
      tester,
    ) async {
      Recursos.ouvirTextosForcado = false;
      await aquecer(tester, livro: 'genesis', capitulos: [1, 2]);
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirReproducaoContinua(true);
      await montar(tester, estado);

      await tocarAteOFim(tester, 'capitulo:genesis.1');

      expect(tituloNaBarra('Gênesis 1'), findsOneWidget);
      expect(Voz.instancia.tocando, isFalse);
    });

    testWidgets('sem áudio para o próximo, o leitor não vira a página', (
      tester,
    ) async {
      Voz.disponibilidadeRemotaParaTeste = false;
      await aquecer(tester, livro: 'genesis', capitulos: [1, 2]);
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirReproducaoContinua(true);
      await montar(tester, estado);

      await tocarAteOFim(tester, 'capitulo:genesis.1');

      expect(tituloNaBarra('Gênesis 1'), findsOneWidget);
      expect(Voz.instancia.tocando, isFalse);
    });

    testWidgets('no último capítulo do canon, termina como hoje', (
      tester,
    ) async {
      await aquecer(tester, livro: 'apocalipse', capitulos: [22]);
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirReproducaoContinua(true);
      await montar(tester, estado, livro: 'apocalipse', capitulo: 22);

      await tocarAteOFim(tester, 'capitulo:apocalipse.22');

      expect(tituloNaBarra('Apocalipse 22'), findsOneWidget);
      expect(Voz.instancia.tocando, isFalse);
    });
  });
}
