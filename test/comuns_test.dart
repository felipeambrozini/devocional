import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LarguraDeLeitura', () {
    testWidgets('numa janela larga, centraliza e limita a largura do conteúdo',
        (tester) async {
      // Simula uma janela de desktop bem mais larga que o limite de leitura.
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const chave = Key('conteudo');
      await tester.pumpWidget(const MaterialApp(
        home: LarguraDeLeitura(
          maxWidth: 720,
          child: ColoredBox(key: chave, color: Colors.red, child: SizedBox.expand()),
        ),
      ));

      expect(tester.getSize(find.byKey(chave)).width, 720);
      // Centralizado: a mesma folga (240) sobra de cada lado dos 1200 disponíveis.
      expect(tester.getTopLeft(find.byKey(chave)).dx, 240);
    });

    testWidgets('numa janela estreita, como no celular, não encolhe o conteúdo',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const chave = Key('conteudo');
      await tester.pumpWidget(const MaterialApp(
        home: LarguraDeLeitura(
          maxWidth: 720,
          child: ColoredBox(key: chave, color: Colors.red, child: SizedBox.expand()),
        ),
      ));

      expect(tester.getSize(find.byKey(chave)).width, 400);
      expect(tester.getTopLeft(find.byKey(chave)).dx, 0);
    });
  });
}
