import 'package:devocional/dados/audio_offline.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/leitura_de_livros.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/personas.dart';
import 'package:devocional/dados/recursos.dart';
import 'package:devocional/dados/voz.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/funcoes/aviso.dart';
import 'package:devocional/telas/historico.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// As diretrizes de acessibilidade do `flutter_test` (alvo de 48 dp, rótulo em
/// todo alvo de toque e contraste de texto) nas superfícies que mudaram de
/// cor, de ação ou de rótulo, cada uma nos dois temas do app: o contraste que
/// passa no pergaminho pode não passar no couro, e vice-versa.
///
/// Um caso por superfície, tema e diretriz, para que um problema real numa
/// combinação vire um `skip:` com o motivo, sem esconder as outras.

const _temas = {'claro': Brightness.light, 'escuro': Brightness.dark};

final _diretrizes = <String, AccessibilityGuideline>{
  'o alvo de toque de 48 dp': androidTapTargetGuideline,
  'o rótulo em todo alvo de toque': labeledTapTargetGuideline,
  'o contraste de texto': textContrastGuideline,
};

/// Uma tela de celular comum, alta o bastante para o cartão inteiro caber sem
/// rolar: a diretriz só olha o que está pintado.
void _telaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Brightness brilho, Estado estado, Widget home) => EscopoDoEstado(
  estado: estado,
  child: MaterialApp(
    theme: construirTema(brilho: brilho),
    home: home,
  ),
);

Future<void> _conferir(
  WidgetTester tester,
  AccessibilityGuideline diretriz,
) async {
  await expectLater(tester, meetsGuideline(diretriz));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DevocionalCartaoDeLeitura', () {
    setUp(() {
      // O botão de ouvir aparece de verdade (sem rede nem path_provider),
      // para a pílula também passar pelas diretrizes.
      Recursos.ouvirTextosForcado = true;
      Voz.baseUrlForTest = 'https://test.audio';
      AudioOffline.temOfflineParaTeste = (_) => false;
    });
    tearDown(() {
      Recursos.ouvirTextosForcado = null;
      Voz.baseUrlForTest = null;
      AudioOffline.temOfflineParaTeste = null;
    });

    const comVersiculo = Devocional(
      referencia: 'João 3:16',
      versiculo:
          'Porque Deus amou o mundo de tal maneira que deu o seu Filho '
          'unigênito',
      texto: '',
    );
    const semVersiculo = Devocional(referencia: '', texto: '');
    const texto =
        'Aqui está o evangelho num versículo. Que a alma o leia devagar e '
        'repouse nele, como quem encontra água fresca no deserto.';

    Future<void> montar(
      WidgetTester tester,
      Brightness brilho, {
      Devocional dev = comVersiculo,
      bool favoritado = false,
    }) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      if (favoritado) {
        await estado.leituraDeLivros.alternarDestaque(
          slugDoDevocional('manha'),
          1,
          paragrafoDoDevocional,
        );
      }
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DevocionalCartaoDeLeitura(
                  titulo: 'Manhã',
                  dev: dev,
                  texto: texto,
                  vozChave: 'devocional:manha:1/1',
                  vozReferencia: 'Manhã, 1 de janeiro',
                  link: 'https://exemplo.test/manha/01-01',
                  slugDeNota: slugDoDevocional('manha'),
                  diaDeNota: 1,
                ),
              ],
            ),
          ),
        ),
      );
      // A checagem de disponibilidade da voz é assíncrona.
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('monta o parágrafo tocável, a referência e o Ouvir', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, Brightness.dark);
      expect(find.text(texto), findsOneWidget);
      expect(find.text('JOÃO 3:16'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Abrir João 3:16')), findsWidgets);
      expect(find.text('Ouvir'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets(
      'a referência é um botão próprio, separado do texto da citação',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await montar(tester, Brightness.dark);
        // Rótulo exato: com o botão fundido no parágrafo, o rótulo levaria
        // junto a citação e a referência repetida. Em caixa normal, para o
        // sintetizador não soletrar "JOÃO" como sigla.
        final referencia = find.bySemanticsLabel('Abrir João 3:16 na Bíblia');
        expect(referencia, findsOneWidget);
        // Botão com toque e com foco: o foco é o que põe a referência na
        // ordem de Tab de quem usa leitor de tela com teclado (e no tabindex
        // da web).
        expect(
          tester.getSemantics(referencia),
          isSemantics(
            isButton: true,
            hasTapAction: true,
            isFocusable: true,
            hasFocusAction: true,
          ),
        );
        // A citação em si deixou de ser um botão.
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(RegExp('Porque Deus amou')),
          ),
          isSemantics(isButton: false, hasTapAction: false),
        );
        semantica.dispose();
      },
    );

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, atende $nomeDaDiretriz', (
          tester,
        ) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });

        testWidgets('no tema $nomeDoTema, favoritado (fundo de grifo), atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho, favoritado: true);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });

        testWidgets('no tema $nomeDoTema, sem versículo nem referência, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho, dev: semVersiculo);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });
      }
    }
  });

  group('TelaHistorico', () {
    Future<void> montar(
      WidgetTester tester,
      Brightness brilho, {
      List<String> titulos = const ['Como vencer a ansiedade?'],
    }) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      for (final titulo in titulos) {
        await estado.novaConversa(personaSpurgeon.id, titulo: titulo);
      }
      await tester.pumpWidget(
        _app(brilho, estado, const TelaHistorico(persona: personaSpurgeon)),
      );
      await tester.pump();
    }

    testWidgets('com uma conversa, mostra a lixeira e a vassoura rotuladas', (
      tester,
    ) async {
      await montar(tester, Brightness.dark);
      expect(
        find.byTooltip('Apagar conversa: Como vencer a ansiedade?'),
        findsOneWidget,
      );
      expect(find.byTooltip('Apagar todas as conversas'), findsOneWidget);
    });

    testWidgets('conversa sem título ainda tem lixeira com rótulo', (
      tester,
    ) async {
      await montar(tester, Brightness.dark, titulos: const ['']);
      expect(find.byTooltip('Apagar conversa'), findsOneWidget);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets(
          'no tema $nomeDoTema, com uma conversa, atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho);
            await _conferir(tester, diretriz);
            semantica.dispose();
          },
        );

        testWidgets('no tema $nomeDoTema, com conversa sem título, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho, titulos: const ['', 'Segunda']);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });
      }
    }
  });

  group('DevocionalLivrosEscolhidos', () {
    const seteLivros = [
      'genesis',
      'exodo',
      'levitico',
      'numeros',
      'deuteronomio',
      'josue',
      'juizes',
    ];

    Future<void> montar(
      WidgetTester tester,
      Brightness brilho,
      List<String> livros,
    ) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setState) => DevocionalLivrosEscolhidos(
                  livros: livros,
                  aoRemover: (slug) => setState(() => livros.remove(slug)),
                  aoRestaurar: (slugs, indice) =>
                      setState(() => livros.insertAll(indice, slugs)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('com dois livros, mostra os chips com remover e o Limpar', (
      tester,
    ) async {
      await montar(tester, Brightness.dark, ['genesis', 'exodo']);
      expect(find.text('1 · Gênesis'), findsOneWidget);
      expect(find.text('Limpar'), findsOneWidget);
    });

    testWidgets('com um livro só, não oferece Limpar', (tester) async {
      await montar(tester, Brightness.dark, ['genesis']);
      expect(find.text('Gênesis'), findsOneWidget);
      expect(find.text('Limpar'), findsNothing);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets(
          'no tema $nomeDoTema, com dois livros, atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho, ['genesis', 'exodo']);
            await _conferir(tester, diretriz);
            semantica.dispose();
          },
        );

        testWidgets(
          'no tema $nomeDoTema, com um livro só, atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho, ['genesis']);
            await _conferir(tester, diretriz);
            semantica.dispose();
          },
        );

        testWidgets('no tema $nomeDoTema, com sete livros no resumo, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho, [...seteLivros]);
          expect(find.text('Ver todos (7)'), findsOneWidget);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });

        testWidgets(
          'no tema $nomeDoTema, com o aviso do Limpar e o Desfazer, atende '
          '$nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho, ['genesis', 'exodo']);
            await tester.tap(find.text('Limpar'));
            await tester.pumpAndSettle();
            expect(find.text('2 livros removidos.'), findsOneWidget);
            await _conferir(tester, diretriz);
            semantica.dispose();
            // O aviso sai por `mostrarAviso`, que arma o próprio timer.
            await tester.pump(duracaoDeAviso);
            await tester.pumpAndSettle();
          },
        );
      }
    }
  });

  group('DevocionalAppBar', () {
    Future<void> montar(
      WidgetTester tester,
      Brightness brilho, {
      String? voltarPara,
    }) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      // Sozinha na pilha, como a `/ler` aberta por F5 ou por um link.
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            appBar: DevocionalAppBar(
              title: const Text('Leitura'),
              voltarPara: voltarPara,
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );
    }

    final voltar = find.byIcon(FontAwesomeIcons.arrowLeft.data);

    testWidgets('com voltarPara e sem tela embaixo, mostra o voltar', (
      tester,
    ) async {
      await montar(tester, Brightness.dark, voltarPara: '/hoje');
      expect(voltar, findsOneWidget);
      final botao = find.ancestor(
        of: voltar,
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(botao).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(botao).height, greaterThanOrEqualTo(48));
    });

    testWidgets('sem voltarPara e sem tela embaixo, não há voltar', (
      tester,
    ) async {
      await montar(tester, Brightness.dark);
      expect(voltar, findsNothing);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets(
          'no tema $nomeDoTema, com voltarPara, atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho, voltarPara: '/hoje');
            await _conferir(tester, diretriz);
            semantica.dispose();
          },
        );
      }
    }
  });
}
