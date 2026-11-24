import 'package:devocional/dados/audio_offline.dart';
import 'package:devocional/dados/canon.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/recursos.dart';
import 'package:devocional/dados/voz.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// O botão de baixar o áudio de um livro da Biblioteca e a folha com os 66
/// livros da Bíblia, nos dois temas, com as diretrizes de acessibilidade do
/// `flutter_test` (mesmo padrão de `acessibilidade_guidelines_test.dart`).

const _temas = {'claro': Brightness.light, 'escuro': Brightness.dark};

final _diretrizes = <String, AccessibilityGuideline>{
  'o alvo de toque de 48 dp': androidTapTargetGuideline,
  'o rótulo em todo alvo de toque': labeledTapTargetGuideline,
  'o contraste de texto': textContrastGuideline,
};

void _telaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Brightness brilho, Widget home) => MaterialApp(
  theme: construirTema(brilho: brilho),
  home: home,
);

void main() {
  setUp(() {
    Recursos.ouvirTextosForcado = true;
    AudioOffline.temOfflineParaTeste = (_) => false;
  });
  tearDown(() {
    Recursos.ouvirTextosForcado = null;
    Voz.baseUrlForTest = null;
    Voz.disponibilidadeRemotaParaTeste = null;
    AudioOffline.temOfflineParaTeste = null;
  });

  final livro = LivroParaBaixar.daBiblioteca(
    ObraDaBiblioteca(
      slug: 'livro_do_teste',
      titulo: 'Livro do teste',
      subtitulo: '',
      capa: '',
    ),
    3,
  );

  Future<void> montarBotao(WidgetTester tester, Brightness brilho) async {
    _telaDeCelular(tester);
    await tester.pumpWidget(
      _app(
        brilho,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: DevocionalBaixarLivro(livro: livro),
          ),
        ),
      ),
    );
    // A conferência no Storage é assíncrona.
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('DevocionalBaixarLivro', () {
    testWidgets('sem áudio no Storage, fica escondido', (tester) async {
      await montarBotao(tester, Brightness.light);
      expect(find.textContaining('Baixar o áudio'), findsNothing);
    });

    testWidgets('com o áudio no Storage mas sem nada no aparelho, fica '
        'escondido se o Storage diz que não existe', (tester) async {
      Voz.baseUrlForTest = 'https://test.audio';
      Voz.disponibilidadeRemotaParaTeste = false;
      await montarBotao(tester, Brightness.light);
      expect(find.textContaining('Baixar o áudio'), findsNothing);
    });

    testWidgets('com o Ouvir desligado no painel, fica escondido', (
      tester,
    ) async {
      Voz.baseUrlForTest = 'https://test.audio';
      Recursos.ouvirTextosForcado = false;
      await montarBotao(tester, Brightness.light);
      expect(find.textContaining('Baixar o áudio'), findsNothing);
    });

    testWidgets('com o áudio no Storage, mostra o botão de baixar', (
      tester,
    ) async {
      Voz.baseUrlForTest = 'https://test.audio';
      await montarBotao(tester, Brightness.light);
      expect(find.textContaining('Baixar o áudio'), findsOneWidget);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, com o botão visível, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          Voz.baseUrlForTest = 'https://test.audio';
          await montarBotao(tester, brilho);
          expect(find.textContaining('Baixar o áudio'), findsOneWidget);
          await expectLater(tester, meetsGuideline(diretriz));
          semantica.dispose();
        });
      }
    }
  });

  group('mostrarLivrosDaBibliaOffline', () {
    Future<void> abrir(WidgetTester tester, Brightness brilho) async {
      _telaDeCelular(tester);
      Voz.baseUrlForTest = 'https://test.audio';
      // Com `temOfflineParaTeste`, `contarLivro` notifica de forma síncrona;
      // chamada de dentro do build de uma linha, isso invalida as outras
      // linhas já montadas. No app real há um await antes do notify. Contar
      // antes de abrir a folha evita a chamada dentro do build.
      for (final livro in canon) {
        await AudioOffline.instancia.contarLivro(
          LivroParaBaixar.daBiblia(livro),
        );
      }
      await tester.pumpWidget(
        _app(
          brilho,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => mostrarLivrosDaBibliaOffline(context),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o título e o primeiro livro com o botão de baixar', (
      tester,
    ) async {
      await abrir(tester, Brightness.light);
      expect(find.text('Livros da Bíblia'), findsOneWidget);
      expect(find.text('Gênesis'), findsOneWidget);
      expect(find.byTooltip('Baixar Gênesis'), findsOneWidget);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, atende $nomeDaDiretriz', (
          tester,
        ) async {
          final semantica = tester.ensureSemantics();
          await abrir(tester, brilho);
          expect(find.text('Gênesis'), findsOneWidget);
          await expectLater(tester, meetsGuideline(diretriz));
          semantica.dispose();
        });
      }
    }
  });
}
