import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/telas/biblia.dart';
import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BKJ e NVT lado a lado (Item 2 do CONTINUAR.md): só em janela larga, uma
/// linha por versículo, sem duas listas de rolagem independentes.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('versiculosMesclados', () {
    test('capítulos idênticos dão a mesma lista de números, em ordem', () {
      const bkj = Capitulo(
        livro: 'genesis',
        numero: 1,
        titulo: '',
        versiculos: [(2, 'b'), (1, 'a')],
      );
      const nvt = Capitulo(
        livro: 'genesis',
        numero: 1,
        titulo: '',
        versiculos: [(1, 'x'), (2, 'y')],
      );
      expect(versiculosMesclados(bkj, nvt), [1, 2]);
    });

    test('um versículo extra de um lado entra na união, sem duplicar', () {
      // O caso real: 3 João 1:15 só existe na versificação da NVT.
      const bkj = Capitulo(
        livro: '3joao',
        numero: 1,
        titulo: '',
        versiculos: [(1, 'a'), (14, 'n')],
      );
      const nvt = Capitulo(
        livro: '3joao',
        numero: 1,
        titulo: '',
        versiculos: [(1, 'x'), (14, 'm'), (15, 'extra')],
      );
      expect(versiculosMesclados(bkj, nvt), [1, 14, 15]);
    });
  });

  group('coluna dupla no leitor', () {
    Future<void> aquecer(WidgetTester tester) => tester.runAsync(() async {
      final c = Conteudo.instancia;
      for (final v in Versao.values) {
        await c.capitulo(v, 'genesis', 1);
      }
      await c.introducao('genesis');
    });

    testWidgets(
      'abaixo do corte de 1100px, não aparece o alternador de coluna dupla',
      (tester) async {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await aquecer(tester);
        await tester.pumpWidget(
          EscopoDoEstado(
            estado: Estado(await SharedPreferences.getInstance()),
            child: const MaterialApp(home: TelaBiblia()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.view_column_outlined), findsNothing);
        expect(find.byType(BotaoDeVersao), findsOneWidget);
      },
    );

    testWidgets(
      'numa janela larga, ligar a coluna dupla mostra as duas traduções '
      'juntas, e desligar volta a uma coluna',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await aquecer(tester);
        final estado = Estado(await SharedPreferences.getInstance());
        await tester.pumpWidget(
          EscopoDoEstado(
            estado: estado,
            child: const MaterialApp(home: TelaBiblia()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().contains(
                  'Deus criou os céus e a terra',
                ),
          ),
          findsNothing,
          reason: 'ainda em uma coluna só, mostrando a BKJ',
        );

        await tester.tap(find.byIcon(Icons.view_column_outlined));
        await tester.pumpAndSettle();

        expect(estado.colunaDuplaAtiva, isTrue);
        // Sem alternador de versão única: as duas já aparecem juntas.
        expect(find.byType(BotaoDeVersao), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().contains(
                  'No princípio criou Deus o céu e a terra',
                ),
          ),
          findsOneWidget,
          reason: 'BKJ continua visível',
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText().contains(
                  'Deus criou os céus e a terra',
                ),
          ),
          findsOneWidget,
          reason: 'NVT aparece ao lado, na mesma tela',
        );

        await tester.tap(find.byIcon(Icons.view_agenda_outlined));
        await tester.pumpAndSettle();

        expect(estado.colunaDuplaAtiva, isFalse);
        expect(find.byType(BotaoDeVersao), findsOneWidget);
      },
    );
  });
}
