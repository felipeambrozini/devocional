import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> aquecerAssets(WidgetTester tester) async {
    await tester.runAsync(() async {
      final conteudo = Conteudo.instancia;
      await conteudo.plano();
      final agora = DateTime.now();
      for (final periodo in Periodo.values) {
        await conteudo.devocional(agora, periodo);
      }
      await conteudo.promessa(agora);
      for (final versao in Versao.values) {
        await conteudo.capitulo(versao, 'genesis', 1);
      }
      await conteudo.capitulo(Versao.bkj, 'salmos', 119);
      await conteudo.introducao('genesis');
    });
  }

  testWidgets('o cartão de ajuda aparece na primeira visita e some com Entendi', (
    tester,
  ) async {
    await aquecerAssets(tester);
    final estado = Estado(await SharedPreferences.getInstance());
    // O cartão cresceu com as linhas de ajuda e a Hoje abre com as duas
    // leituras do dia no topo: numa janela de 800x900 o cartão nasce além
    // da área que a lista constrói. Rola até ele, como o visitante faria,
    // antes de conferir e tocar.
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(AppDevocional(estado: estado));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Entendi'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Como usar'), findsOneWidget);
    expect(find.text('Entendi'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Como usar'), findsNothing);

    // E não volta: a escolha fica gravada no estado.
    await tester.pumpWidget(AppDevocional(estado: estado));
    await tester.pumpAndSettle();
    expect(find.text('Como usar'), findsNothing);
  });
}