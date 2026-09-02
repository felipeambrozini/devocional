import 'package:felipe_ambrozini/data/audio_offline.dart';
import 'package:felipe_ambrozini/data/voz.dart';
import 'package:felipe_ambrozini/funcoes/aviso.dart';
import 'package:felipe_ambrozini/widgets/widgets.dart';
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
      'com base configurada mas o arquivo ainda não gerado (HEAD não '
      'encontra), o botão não aparece',
      (tester) async {
        Voz.disponibilidadeRemotaParaTeste = false;
        addTearDown(() => Voz.disponibilidadeRemotaParaTeste = null);
        await tester.pumpWidget(montar());
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Ouvir'), findsNothing);
      },
    );

    testWidgets(
      'sem rede para checar (não sem áudio), o botão aparece desabilitado '
      'em vez de sumir',
      (tester) async {
        Voz.semRedeParaTeste = true;
        addTearDown(() => Voz.semRedeParaTeste = false);
        await tester.pumpWidget(montar());
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Sem conexão'), findsOneWidget);
        expect(find.text('Ouvir'), findsNothing);
      },
    );

    testWidgets('o erro de leitura oferece "Tentar de novo"', (tester) async {
      // Disponível na checagem (default de teste = tudo disponível), mas
      // sem base real pra tocar de fato — simula o arquivo ter sumido do
      // Storage entre a checagem e o toque.
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
