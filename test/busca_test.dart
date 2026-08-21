import 'dart:async';

import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/telas/busca.dart';
import 'package:felipe_ambrozini/telas/biblia.dart';
import 'package:felipe_ambrozini/telas/devocional.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('mecanismo do onError na busca', () {
    test(
      'um erro dentro de async* chega como erro do stream, e o stream fecha',
      () async {
        // Prova o mecanismo do Dart em que o conserto de busca.dart se apoia:
        // Conteudo.buscar não precisa de try/catch, porque um erro não
        // capturado dentro de um gerador async* já chega como evento de erro
        // para quem escuta, e o stream termina (chama onDone) sozinho.
        Stream<int> gera() async* {
          yield 1;
          throw Exception('falhou lendo um asset');
        }

        final vistos = <int>[];
        Object? erro;
        var terminou = false;
        final concluido = Completer<void>();

        gera().listen(
          vistos.add,
          onError: (Object e) => erro = e,
          onDone: () {
            terminou = true;
            concluido.complete();
          },
        );

        await concluido.future;
        expect(vistos, [1]);
        expect(erro, isNotNull);
        expect(terminou, isTrue);
      },
    );
  });

  group('TelaBusca', () {
    // A busca varre o canon inteiro em Conteudo.buscar; sem aquecer todos os
    // 66 livros de antemão, o toque no botão dispara leitura real de asset
    // fora do tester.runAsync, e pumpAndSettle nunca vê o stream terminar.
    Future<void> aquecer(WidgetTester tester) => tester.runAsync(() async {
      final c = Conteudo.instancia;
      for (final livro in canon) {
        await c.capitulo(Versao.bkj, livro.slug, 1);
      }
      await c.buscarDevocionais('promessa');
    });

    Future<void> abrir(WidgetTester tester) async {
      await aquecer(tester);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: Estado(await SharedPreferences.getInstance()),
          child: const MaterialApp(home: TelaBusca()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('digitar uma referência mostra o cartão de ir direto', (
      tester,
    ) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'João 3:16');
      await tester.tap(find.byIcon(Icons.arrow_forward).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ir para João 3:16'), findsOneWidget);

      await tester.tap(find.textContaining('Ir para João 3:16'));
      await tester.pumpAndSettle();

      expect(find.byType(TelaBiblia), findsOneWidget);
      expect(find.text('João 3'), findsWidgets);
    });

    testWidgets('um termo que não é referência não mostra o cartão', (
      tester,
    ) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'amor');
      await tester.tap(find.byIcon(Icons.arrow_forward).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ir para'), findsNothing);
    });

    testWidgets(
      'digitar sozinho já busca, sem precisar tocar no botão',
      (tester) async {
        await abrir(tester);

        await tester.enterText(find.byType(TextField), 'amor');
        // Sem tap no botão: só o atraso do debounce deve disparar a busca.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.textContaining('resultado'), findsOneWidget);
      },
    );

    testWidgets(
      'a aba Devocionais acha um termo só de Manhã/Noite ou Promessas',
      (tester) async {
        await abrir(tester);

        // Único nos dois corpora: verificado contra os assets antes de
        // escrever o teste, mesmo termo do grupo buscarDevocionais em
        // conteudo_test.dart.
        await tester.enterText(
          find.byType(TextField),
          'primeira promessa ao homem caído',
        );
        await tester.tap(find.byIcon(Icons.arrow_forward).first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Devocionais'));
        await tester.pumpAndSettle();

        expect(find.text('1 resultado'), findsOneWidget);

        await tester.tap(find.textContaining('Promessas de Deus'));
        await tester.pumpAndSettle();

       expect(find.byType(TelaDevocional), findsOneWidget);
      },
    );
  });

  group('destacar', () {
    test('destaca o termo ignorando acento e caixa', () {
      final tema = ThemeData.light().textTheme;
      final cor = ThemeData.light().colorScheme;

      final resultado = destacar(
        'Porque Deus amou ao mundo',
        'DEUS',
        tema,
        cor,
      );

      final children = (resultado).children!;
      expect(children, isNotEmpty);

      final textos =
          children.map((span) => (span as TextSpan).text).join();
      expect(textos, contains('Deus'));
    });

    test('preserva o resto do texto ao redor do termo', () {
      final tema = ThemeData.light().textTheme;
      final cor = ThemeData.light().colorScheme;

      final resultado = destacar(
        'amor',
        'amor',
        tema,
        cor,
      );

      final textos =
          ((resultado).children!).map((span) => (span as TextSpan).text).join();
      expect(textos, 'amor');
    });

    test('não destaca o termo dentro de outra palavra', () {
      final tema = ThemeData.light().textTheme;
      final cor = ThemeData.light().colorScheme;

      final resultado = destacar(
        'os amorreus habitavam a terra, mas Deus é amor',
        'amor',
        tema,
        cor,
      );

      final destacados = resultado.children!
          .cast<TextSpan>()
          .where((span) => span.style?.fontWeight == FontWeight.w700)
          .map((span) => span.text)
          .toList();
      expect(destacados, ['amor']);
    });

    test('retorna todos os caracteres quando o termo não aparece', () {
      final tema = ThemeData.light().textTheme;
      final cor = ThemeData.light().colorScheme;

      final resultado = destacar(
        'texto sem o termo buscado',
        'xyz',
        tema,
        cor,
      );

      final textos =
          ((resultado).children!).map((span) => (span as TextSpan).text).join();
      expect(textos, 'texto sem o termo buscado');
    });
  });
}
