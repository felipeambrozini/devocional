import 'package:felipe_ambrozini/data/audio_offline.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/voz.dart';
import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Voz.instancia.parar();
    Voz.baseUrlForTest = 'https://test.audio';
    // Evita bater no path_provider de verdade: sem plugin registrado em
    // teste de widget, a checagem de disponibilidade nunca resolveria.
    AudioOffline.temOfflineParaTeste = (_) => false;
  });
  tearDown(() {
    Voz.baseUrlForTest = null;
    AudioOffline.temOfflineParaTeste = null;
  });

  Widget montar({String chave = 'capitulo:joao.3'}) => MaterialApp(
    home: Scaffold(
      body: BotaoDeVoz(
        chave: chave,
        texto: 'No princípio.',
        tipo: TipoConteudoAudio.biblia,
      ),
    ),
  );

  group('BotaoDeVoz', () {
    testWidgets('em repouso mostra "Ouvir" e anuncia o rótulo completo', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(montar());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ouvir'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ouvir na voz de Spurgeon'),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('sem base de áudio configurada, o botão não aparece', (
      tester,
    ) async {
      Voz.baseUrlForTest = '';
      await tester.pumpWidget(montar());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ouvir'), findsNothing);
    });

    testWidgets(
      'com base configurada mas o arquivo ainda não gerado (fora do '
      'manifesto), o botão não aparece',
      (tester) async {
        Voz.manifestoParaTeste = {};
        addTearDown(() => Voz.manifestoParaTeste = null);
        await tester.pumpWidget(montar());
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Ouvir'), findsNothing);
      },
    );

    testWidgets('o erro de leitura oferece "Tentar de novo"', (tester) async {
      // Disponível na checagem (manifesto default de teste = tudo
      // disponível), mas sem base real pra tocar de fato — simula o
      // arquivo ter sumido do Storage entre a checagem e o toque.
      await tester.pumpWidget(montar());
      await tester.pump(const Duration(milliseconds: 500));
      Voz.baseUrlForTest = '';
      await tester.tap(find.text('Ouvir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('não disponível'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      await tester.pump(duracaoDeErro);
      await tester.pumpAndSettle();
    });
  });
}
