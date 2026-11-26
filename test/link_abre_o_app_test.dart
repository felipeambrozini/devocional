import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/main.dart';
import 'package:devocional/telas/biblia.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O app fechado aberto por um link do site (App Link do Android): o motor
/// passa a URL inteira como rota inicial (`defaultRouteName`), que vence o
/// `initialLocation` do GoRouter. Arquivo próprio porque o GoRouter é do
/// módulo e só lê a rota inicial uma vez, ao nascer.
void main() {
  testWidgets('link de versículo abre o app fechado na Bíblia', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        'https://www.felipeambrozini.com.br/tabernaculo/?ler=joao.3.16';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.runAsync(() => Conteudo.instancia.plano());
    final estado = Estado(await SharedPreferences.getInstance());

    await tester.pumpWidget(AppTabernaculo(estado: estado));
    await tester.pump(const Duration(milliseconds: 500));

    final roteador = GoRouter.of(tester.element(find.byType(Scaffold).first));
    expect(
      roteador.routerDelegate.currentConfiguration.uri.toString(),
      '/ler/joao/3?versiculos=16',
    );
    expect(find.byType(TelaBiblia), findsOneWidget);
  });
}
