import 'dart:convert';
import 'dart:io';

import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Os App Links do Android (links do site abrem o app instalado) dependem de
/// três peças que precisam concordar: o intent-filter do manifest, o
/// `assetlinks.json` publicado na raiz do site e as rotas do go_router.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// O intent-filter com `autoVerify`, o único que declara o site.
  final filtro = RegExp(
    r'<intent-filter android:autoVerify="true">.*?</intent-filter>',
    dotAll: true,
  ).firstMatch(manifest)?.group(0);

  Iterable<String> atributos(String nome) => RegExp(
    'android:$nome="([^"]*)"',
  ).allMatches(filtro ?? '').map((m) => m.group(1)!);

  test('o manifest declara o site num intent-filter verificado', () {
    expect(filtro, isNotNull);
    expect(filtro, contains('android.intent.action.VIEW'));
    expect(filtro, contains('android.intent.category.BROWSABLE'));
    expect(atributos('scheme'), ['https']);
    expect(atributos('host'), ['www.felipeambrozini.com.br']);
    expect(atributos('path'), containsAll(['/tabernaculo', '/tabernaculo/']));
    expect(manifest, contains('flutter_deeplinking_enabled'));
  });

  test('o painel admin, só da web, continua abrindo no navegador', () {
    for (final prefixo in atributos('pathPrefix')) {
      expect(
        '/tabernaculo/admin'.startsWith(prefixo),
        isFalse,
        reason: '$prefixo pegaria /tabernaculo/admin',
      );
    }
  });

  testWidgets('toda rota de topo do app, menos admin, abre no app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => Conteudo.instancia.plano());
    final estado = Estado(await SharedPreferences.getInstance());
    await tester.pumpWidget(AppTabernaculo(estado: estado));
    await tester.pump(const Duration(milliseconds: 500));

    final roteador = GoRouter.of(tester.element(find.byType(Scaffold).first));
    final topo = <String>{};
    void coletar(List<RouteBase> rotas) {
      for (final rota in rotas) {
        if (rota is GoRoute) {
          topo.add(rota.path.split('/').where((p) => p.isNotEmpty).first);
        } else if (rota is ShellRouteBase) {
          coletar(rota.routes);
        }
      }
    }

    coletar(roteador.configuration.routes);
    topo.remove('admin');

    final prefixos = atributos('pathPrefix').toSet();
    for (final segmento in topo) {
      expect(
        prefixos,
        contains('/tabernaculo/$segmento'),
        reason: 'link do site para /$segmento abriria no navegador',
      );
    }
  });

  test('o assetlinks.json autoriza o app com a chave de distribuição', () {
    final declaracoes =
        jsonDecode(
              File('hospedagem/.well-known/assetlinks.json').readAsStringSync(),
            )
            as List<Object?>;
    final doApp = declaracoes.cast<Map<String, Object?>>().firstWhere(
      (d) =>
          (d['target']! as Map)['package_name'] ==
          'com.felipeambrozini.tabernaculo',
    );
    expect(doApp['relation'], ['delegate_permission/common.handle_all_urls']);
    expect(
      (doApp['target']! as Map)['sha256_cert_fingerprints'],
      contains(
        '47:A8:4C:D6:03:D6:07:E1:77:AE:BB:17:A0:8F:33:2A:'
        '41:C6:66:D5:1E:F7:A9:B9:70:F4:F9:37:53:BA:D7:FB',
      ),
    );
  });
}
