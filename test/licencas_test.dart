import 'dart:io';

import 'package:devocional/dados/audio_offline.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/licencas.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/telas/sobre.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A página de licenças: a OFL das fontes empacotadas (que o pub não registra
/// sozinho) e o caminho até ela em Sobre, nos dois temas.

const _temas = {'claro': Brightness.light, 'escuro': Brightness.dark};

final _diretrizes = <String, AccessibilityGuideline>{
  'o alvo de toque de 48 dp': androidTapTargetGuideline,
  'o rótulo em todo alvo de toque': labeledTapTargetGuideline,
  'o contraste de texto': textContrastGuideline,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registrarLicencasDasFontes);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Tabernáculo',
      packageName: 'com.felipeambrozini.tabernaculo',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  test('cada fonte empacotada leva o copyright e a OFL', () async {
    final entradas = await LicenseRegistry.licenses.toList();
    for (final MapEntry(key: fonte, value: copyright) in fontesComOfl.entries) {
      final daFonte = entradas.where((e) => e.packages.contains(fonte));
      expect(daFonte, hasLength(1), reason: fonte);
      final texto = daFonte.single.paragraphs.map((p) => p.text).join('\n');
      expect(texto, contains(copyright));
      expect(texto, contains('SIL OPEN FONT LICENSE Version 1.1'));
    }
  });

  test('toda família de fonte do pubspec tem a licença registrada', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final familias = RegExp(
      r'^\s*-\s*family:\s*(\S+)',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m.group(1)).toSet();
    expect(familias, fontesComOfl.keys.toSet());
  });

  group('Sobre → Licenças de código aberto', () {
    // O trecho de "A voz de Spurgeon" procura áudio baixado no disco, que
    // não existe no teste (sem path_provider).
    setUp(() => AudioOffline.temOfflineParaTeste = (_) => false);
    tearDown(() => AudioOffline.temOfflineParaTeste = null);

    Future<void> montar(WidgetTester tester, Brightness brilho) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(
            theme: construirTema(brilho: brilho),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const TelaSobre(),
                ),
                // Espelho da rota de lib/main.dart (o app_test confere a
                // real).
                GoRoute(
                  path: '/licencas',
                  builder: (context, state) =>
                      const LicensePage(applicationName: 'Tabernáculo'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Licenças de código aberto'));
      await tester.pumpAndSettle();
    }

    testWidgets('abre a página de licenças com as fontes', (tester) async {
      await montar(tester, Brightness.light);
      await tester.tap(find.text('Licenças de código aberto'));
      // Sem pumpAndSettle: a página gira um indicador enquanto junta as
      // licenças, num isolate de verdade, e nunca assenta antes disso.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LicensePage), findsOneWidget);
      for (var i = 0; i < 20 && find.text('Cinzel').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Cinzel'), findsWidgets);
      expect(find.text('Montserrat'), findsWidgets);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, o item atende $nomeDaDiretriz', (
          tester,
        ) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho);
          await expectLater(tester, meetsGuideline(diretriz));
          semantica.dispose();
        });
      }
    }
  });
}
