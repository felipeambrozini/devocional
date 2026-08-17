import 'package:felipe_ambrozini/data/voz.dart';
import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => Voz.instancia.parar());

  Widget montar({String chave = 'capitulo:joao.3'}) => MaterialApp(
    home: Scaffold(
      body: BotaoDeVoz(chave: chave, texto: 'No princípio.'),
    ),
  );

  group('BotaoDeVoz', () {
    testWidgets('em repouso mostra "Ouvir" e anuncia o rótulo completo', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(montar());

      expect(find.text('Ouvir'), findsOneWidget);
      // O rótulo de tela é curto; a frase inteira vive no Semantics (o nó
      // funde o texto visível ao rótulo, separado por quebra de linha).
      expect(
        find.bySemanticsLabel(RegExp('^Ouvir na voz de Spurgeon')),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets(
      'sem chave no build, o toque mostra o aviso de configuração',
      (tester) async {
        // Os testes rodam sem --dart-define: a chave TTS vem vazia, e o toque
        // deve virar o aviso de configuração, não um erro sem tratamento.
        await tester.pumpWidget(montar());
        await tester.tap(find.text('Ouvir'));
        await tester.pumpAndSettle();

        expect(find.textContaining('TTS_API_KEY'), findsOneWidget);
        // O botão volta ao repouso: o erro não deixa o estado preso.
        expect(find.text('Ouvir'), findsOneWidget);
      },
    );
  });
}
