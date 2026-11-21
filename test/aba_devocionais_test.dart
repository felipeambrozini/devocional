import 'package:devocional/dados/modelos.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// O filtro de leitura da aba Devocionais da busca: uma fileira de chips
/// ("Todas" e um por leitura) que recorta a lista e o contador junto.
void main() {
  const achados = [
    AchadoDevocional(
      leitura: 'manha',
      data: '01-01',
      titulo: 'A graça da manhã',
      texto: 'A graça de Deus é nova a cada manhã.',
    ),
    AchadoDevocional(
      leitura: 'manha',
      data: '03-01',
      titulo: 'Outra graça da manhã',
      texto: 'Graça sobre graça.',
    ),
    AchadoDevocional(
      leitura: 'noite',
      data: '02-01',
      titulo: 'A graça da noite',
      texto: 'Repouse na graça antes de dormir.',
    ),
    AchadoDevocional(
      leitura: 'promessas',
      data: '29-02',
      titulo: 'A graça prometida',
      texto: 'A minha graça te basta.',
    ),
  ];

  Future<void> montar(
    WidgetTester tester, {
    List<AchadoDevocional> achados = achados,
    bool buscando = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DevocionalAbaDevocionais(
            termoBuscado: 'graça',
            achados: achados,
            buscando: buscando,
            erro: false,
            aoTentarDeNovo: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder chip(String rotulo) => find.widgetWithText(ChoiceChip, rotulo);

  bool escolhido(WidgetTester tester, String rotulo) =>
      tester.widget<ChoiceChip>(chip(rotulo)).selected;

  group('DevocionalAbaDevocionais, filtro de leitura', () {
    testWidgets('mostra Todas e um chip por leitura, com Todas escolhida', (
      tester,
    ) async {
      await montar(tester);
      for (final rotulo in ['Todas', 'Manhã', 'Promessas de Deus', 'Noite']) {
        expect(chip(rotulo), findsOneWidget, reason: rotulo);
      }
      expect(escolhido(tester, 'Todas'), isTrue);
      expect(find.text('4 resultados'), findsOneWidget);
      expect(find.bySemanticsLabel('Filtrar por leitura'), findsOneWidget);
    });

    testWidgets('tocar num chip recorta a lista e o contador acompanha', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(chip('Manhã'));
      await tester.pump();
      expect(escolhido(tester, 'Manhã'), isTrue);
      expect(escolhido(tester, 'Todas'), isFalse);
      expect(find.text('2 resultados'), findsOneWidget);
      expect(find.text('A graça da manhã'), findsOneWidget);
      expect(find.text('Outra graça da manhã'), findsOneWidget);
      expect(find.text('A graça da noite'), findsNothing);
      expect(find.text('A graça prometida'), findsNothing);

      // Uma leitura com um achado só: o contador vai para o singular.
      await tester.tap(chip('Noite'));
      await tester.pump();
      expect(find.text('1 resultado'), findsOneWidget);
      expect(find.text('A graça da noite'), findsOneWidget);
      expect(find.text('A graça da manhã'), findsNothing);
    });

    testWidgets('Todas devolve a lista inteira', (tester) async {
      await montar(tester);
      await tester.tap(chip('Promessas de Deus'));
      await tester.pump();
      expect(find.text('1 resultado'), findsOneWidget);

      await tester.tap(chip('Todas'));
      await tester.pump();
      expect(escolhido(tester, 'Todas'), isTrue);
      expect(find.text('4 resultados'), findsOneWidget);
      for (final achado in achados) {
        expect(find.text(achado.titulo), findsOneWidget, reason: achado.titulo);
      }
    });

    testWidgets('o filtro de leitura se soma ao de data', (tester) async {
      await montar(tester);
      await tester.enterText(find.byType(TextField), '01-01');
      await tester.pump();
      expect(find.text('1 resultado'), findsOneWidget);
      expect(find.text('A graça da manhã'), findsOneWidget);

      await tester.tap(chip('Manhã'));
      await tester.pump();
      expect(find.text('1 resultado'), findsOneWidget);
    });

    testWidgets('lista vazia ainda buscando mostra os chips, não "Nada '
        'encontrado"', (tester) async {
      await montar(tester, achados: const [], buscando: true);
      expect(find.text('Nada encontrado'), findsNothing);
      expect(find.text('0 resultados'), findsOneWidget);
      expect(chip('Todas'), findsOneWidget);
    });

    testWidgets('termo vazio não mostra filtro nenhum', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DevocionalAbaDevocionais(
              termoBuscado: '',
              achados: achados,
              buscando: false,
              erro: false,
              aoTentarDeNovo: () {},
            ),
          ),
        ),
      );
      expect(find.text('Busque nos devocionais'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets(
      'um chip sem achado nenhum deixa os chips na tela para voltar a Todas',
      (tester) async {
        await montar(tester, achados: achados.take(3).toList());
        await tester.tap(chip('Promessas de Deus'));
        await tester.pump();
        // O "Nada encontrado" fica abaixo dos filtros, dentro da rolagem:
        // antes ele trocava a aba inteira e levava os chips junto, sem jeito
        // de voltar a Todas.
        expect(find.text('Nada encontrado'), findsOneWidget);
        expect(chip('Todas'), findsOneWidget);
        await tester.tap(chip('Todas'));
        await tester.pump();
        expect(find.text('Nada encontrado'), findsNothing);
      },
    );
  });
}
