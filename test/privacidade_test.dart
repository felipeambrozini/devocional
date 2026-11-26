import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/dados/recursos.dart';
import 'package:devocional/telas/privacidade.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A política de privacidade segue a regra da conta: ler é livre, guardar
/// exige conta, sair tira os dados do aparelho e apagar a conta apaga os da
/// nuvem e os do aparelho.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Nuvem.instancia.logadoForcado = false;
  });
  tearDown(() {
    Nuvem.instancia.logadoForcado = null;
    Recursos.conversasForcado = null;
  });

  /// O texto inteiro da página, de todos os blocos de texto.
  String textoDaPagina(WidgetTester tester) => [
    for (final paragrafo in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    ))
      paragrafo.text.toPlainText(),
  ].join('\n');

  for (final chat in [false, true]) {
    testWidgets('política sem promessas antigas (chat: $chat)', (tester) async {
      Recursos.conversasForcado = chat;
      tester.view.physicalSize = const Size(800, 12000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: TelaPrivacidade()));
      await tester.pump();
      final texto = textoDaPagina(tester);

      expect(texto, contains('Ler não exige conta'));
      expect(texto, contains('exige entrar com conta Google'));
      expect(texto, contains('saem do aparelho'));
      expect(texto, contains('da nuvem e do aparelho ou navegador'));
      expect(texto, isNot(contains('mesmo jeito')));
      expect(texto, isNot(contains('sem tocar no que está')));
      expect(texto, isNot(contains('Favoritos, anotações, progresso de')));
      expect(texto, isNot(contains('nem o horário em que lê')));
    });
  }
}
