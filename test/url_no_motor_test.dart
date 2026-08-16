import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Investiga o caminho framework→motor da URL: intercepta o canal
/// flutter/navigation e registra cada chamada a routeInformationUpdated
/// (o que o motor web transforma em history.pushState/replaceState). Sem
/// navegador, é a prova mais próxima de "a barra de endereço vai mudar?".
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Estado> estadoLimpo() async =>
      Estado(await SharedPreferences.getInstance());

  testWidgets('abrir o chat pede routeInformationUpdated para o motor', (
    tester,
  ) async {
    await tester.runAsync(() => Conteudo.instancia.plano());

    final chamadas = <(String, bool)>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          chamadas.add((
            call.arguments['uri'] as String,
            call.arguments['replace'] as bool,
          ));
        }
        return null;
      },
    );

    await tester.pumpWidget(AppDevocional(estado: await estadoLimpo()));
    await tester.pumpAndSettle();

    expect(
      GoRouter.optionURLReflectsImperativeAPIs,
      isTrue,
      reason: 'o push do chat só chega ao motor com a opção ligada',
    );

    chamadas.clear();

    await tester.tap(find.byTooltip('Conversar com Charles Spurgeon'));
    await tester.pumpAndSettle();

    expect(
      chamadas,
      contains(('/charles-spurgeon', false)),
      reason: 'abrir a conversa tem de pedir um pushState ao motor',
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(
      chamadas,
      contains(('/hoje', false)),
      reason: 'fechar a conversa tem de devolver a URL ao motor',
    );
  });
}