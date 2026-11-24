import 'package:devocional/dados/audio_offline.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/recursos.dart';
import 'package:devocional/dados/voz.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O botão de baixar o áudio na grade de capítulos do seletor da Bíblia, nos
/// dois temas, com as diretrizes de acessibilidade do `flutter_test`.

const _temas = {'claro': Brightness.light, 'escuro': Brightness.dark};

final _diretrizes = <String, AccessibilityGuideline>{
  'o alvo de toque de 48 dp': androidTapTargetGuideline,
  'o rótulo em todo alvo de toque': labeledTapTargetGuideline,
  'o contraste de texto': textContrastGuideline,
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Recursos.ouvirTextosForcado = true;
    AudioOffline.temOfflineParaTeste = (_) => false;
  });
  tearDown(() {
    Recursos.ouvirTextosForcado = null;
    Voz.baseUrlForTest = null;
    Voz.disponibilidadeRemotaParaTeste = null;
    AudioOffline.temOfflineParaTeste = null;
  });

  Future<void> montar(WidgetTester tester, Brightness brilho) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final estado = Estado(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: MaterialApp(
          theme: construirTema(brilho: brilho),
          home: const Scaffold(
            body: DevocionalSeletorDeLivro(
              livroAtual: 'joao',
              capituloAtual: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DevocionalSeletorDeLivro e o áudio do livro', () {
    testWidgets('com o áudio disponível, mostra "Baixar o áudio"', (
      tester,
    ) async {
      Voz.baseUrlForTest = 'https://test.audio';
      await montar(tester, Brightness.light);
      expect(find.textContaining('Baixar o áudio'), findsOneWidget);
    });

    testWidgets('sem áudio no Storage, não mostra o botão', (tester) async {
      await montar(tester, Brightness.light);
      expect(find.textContaining('Baixar o áudio'), findsNothing);
    });

    testWidgets('com o Ouvir desligado no painel, não mostra o botão', (
      tester,
    ) async {
      Voz.baseUrlForTest = 'https://test.audio';
      Recursos.ouvirTextosForcado = false;
      await montar(tester, Brightness.light);
      expect(find.textContaining('Baixar o áudio'), findsNothing);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, com o botão visível, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          Voz.baseUrlForTest = 'https://test.audio';
          await montar(tester, brilho);
          expect(find.textContaining('Baixar o áudio'), findsOneWidget);
          await expectLater(tester, meetsGuideline(diretriz));
          semantica.dispose();
        });
      }
    }
  });
}
