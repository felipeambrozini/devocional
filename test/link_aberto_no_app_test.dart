import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/main.dart';
import 'package:devocional/telas/biblia.dart';
import 'package:devocional/telas/devocional.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um link do site aberto pelo App Link do Android com o app já aberto: o
/// motor entrega a URL inteira (`https://www.../tabernaculo/...`) como
/// `pushRouteInformation`, o mesmo caminho do `onNewIntent` da Activity
/// `singleTop`. A abertura do zero está em `link_abre_o_app_test.dart`.
Future<void> abrirLinkDoSite(WidgetTester tester, String caminho) async {
  final url = 'https://www.felipeambrozini.com.br$caminho';
  const codec = JSONMethodCodec();
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    codec.encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': url, 'state': null}),
    ),
    (_) {},
  );
  // Sem pumpAndSettle: o devocional anima enquanto o conteúdo carrega.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

String rotaAtual(WidgetTester tester) => GoRouter.of(
  tester.element(find.byType(Scaffold).first),
).routerDelegate.currentConfiguration.uri.toString();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('link do devocional com data cai na leitura e no dia', (
    tester,
  ) async {
    await tester.runAsync(() => Conteudo.instancia.plano());
    final estado = Estado(await SharedPreferences.getInstance());
    await tester.pumpWidget(AppTabernaculo(estado: estado));
    // O GoRouter é do módulo: o teste anterior pode tê-lo deixado no
    // devocional, que anima enquanto carrega.
    await tester.pump(const Duration(milliseconds: 500));

    await abrirLinkDoSite(
      tester,
      '/tabernaculo/devocional/noite?data=2026-11-26',
    );

    expect(rotaAtual(tester), '/devocional/noite?data=2026-11-26');
    expect(find.byType(TelaDevocional), findsOneWidget);
  });

  testWidgets('link de versículo abre a Bíblia no capítulo', (tester) async {
    await tester.runAsync(() => Conteudo.instancia.plano());
    final estado = Estado(await SharedPreferences.getInstance());
    await tester.pumpWidget(AppTabernaculo(estado: estado));
    // O GoRouter é do módulo: o teste anterior pode tê-lo deixado no
    // devocional, que anima enquanto carrega.
    await tester.pump(const Duration(milliseconds: 500));

    await abrirLinkDoSite(tester, '/tabernaculo/?ler=joao.3.16');

    expect(rotaAtual(tester), '/ler/joao/3?versiculos=16');
    expect(find.byType(TelaBiblia), findsOneWidget);
  });
}
