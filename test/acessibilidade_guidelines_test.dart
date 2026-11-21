import 'package:devocional/dados/audio_offline.dart';
import 'package:devocional/dados/biblioteca.dart';
import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/leitura_de_livros.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/personas.dart';
import 'package:devocional/dados/planos.dart';
import 'package:devocional/dados/recursos.dart';
import 'package:devocional/dados/voz.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/funcoes/aviso.dart';
import 'package:devocional/telas/biblia.dart';
import 'package:devocional/telas/conversas.dart';
import 'package:devocional/telas/historico.dart';
import 'package:devocional/telas/leitor_de_livro.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
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

  _grupoDoCapituloDeLivro();

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

    testWidgets('Copiar na folha do texto copia e avisa "Texto copiado"', (
      tester,
    ) async {
      await montar(tester, Brightness.dark);
      // Handler próprio no canal de plataforma, como em app_test.dart: o
      // ambiente de teste nunca responde Clipboard.getData.
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (chamada) async {
          if (chamada.method == 'Clipboard.setData') {
            copiado = (chamada.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(find.text(texto));
      await tester.pumpAndSettle();
      expect(find.text('Texto copiado'), findsNothing);
      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();

      expect(copiado, texto);
      expect(find.text('Copiar'), findsNothing, reason: 'a folha fecha');
      expect(find.text('Texto copiado'), findsOneWidget);
      // O aviso arma o próprio timer; deixa fechar.
      await tester.pump(duracaoDeAviso);
      await tester.pumpAndSettle();
    });

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
            expect(find.text('2 livros removidos'), findsOneWidget);
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

  group('folha do versículo com o comentário no texto', () {
    setUp(() {
      Recursos.ouvirTextosForcado = true;
      Recursos.comentarioNoCapituloForcado = true;
      Voz.baseUrlForTest = 'https://test.audio';
      Voz.disponibilidadeRemotaParaTeste = true;
      AudioOffline.temOfflineParaTeste = (_) => false;
    });
    tearDown(() {
      Recursos.ouvirTextosForcado = null;
      Recursos.comentarioNoCapituloForcado = null;
      Voz.baseUrlForTest = null;
      Voz.disponibilidadeRemotaParaTeste = null;
      AudioOffline.temOfflineParaTeste = null;
    });

    Future<void> abrirFolha(WidgetTester tester, Brightness brilho) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirComentarioNoTexto(true);
      await tester.runAsync(() async {
        await Conteudo.instancia.capitulo('joao', 1);
        await Conteudo.instancia.introducao('joao');
        await Conteudo.instancia.comentariosDoCapitulo('joao', 1);
      });
      await tester.pumpWidget(
        _app(brilho, estado, const TelaBiblia(livroInicial: 'joao')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('No princípio era o Verbo'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ouvir o comentário'), findsOneWidget);
    }

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, atende $nomeDaDiretriz', (
          tester,
        ) async {
          final semantica = tester.ensureSemantics();
          await abrirFolha(tester, brilho);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });
      }
    }
  });

  group('DevocionalAbaDevocionais com os chips de leitura', () {
    const achados = [
      AchadoDevocional(
        leitura: 'manha',
        data: '01-01',
        titulo: 'A graça da manhã',
        texto: 'A graça de Deus é nova a cada manhã.',
      ),
      AchadoDevocional(
        leitura: 'noite',
        data: '02-01',
        titulo: 'A graça da noite',
        texto: 'Repouse na graça antes de dormir.',
      ),
      AchadoDevocional(
        leitura: 'promessas',
        data: '29-02',
        titulo: 'A graça prometida',
        texto: 'A minha graça te basta.',
      ),
    ];

    Future<void> montar(WidgetTester tester, Brightness brilho) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            body: DevocionalAbaDevocionais(
              termoBuscado: 'graça',
              achados: achados,
              buscando: false,
              erro: false,
              aoTentarDeNovo: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, com Todas escolhida, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });

        testWidgets('no tema $nomeDoTema, com Noite escolhida, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho);
          await tester.tap(find.widgetWithText(ChoiceChip, 'Noite'));
          await tester.pumpAndSettle();
          expect(find.text('1 resultado'), findsOneWidget);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });
      }
    }
  });

  group('DevocionalSeletorDeLivro aberto na grade', () {
    Future<void> montar(
      WidgetTester tester,
      Brightness brilho, {
      String livroAtual = 'rute',
      int? capituloAtual,
    }) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            body: DevocionalSeletorDeLivro(
              livroAtual: livroAtual,
              capituloAtual: capituloAtual,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a célula do capítulo atual se anuncia como "Capítulo N", '
        'selecionada, e só ela', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, Brightness.dark, capituloAtual: 3);
      final atual = find.bySemanticsLabel('Capítulo 3');
      expect(atual, findsOneWidget);
      expect(
        tester.getSemantics(atual),
        isSemantics(
          label: 'Capítulo 3',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      for (final outro in [1, 2, 4]) {
        final celula = find.bySemanticsLabel('Capítulo $outro');
        expect(celula, findsOneWidget, reason: 'Capítulo $outro');
        expect(
          tester.getSemantics(celula),
          isSemantics(label: 'Capítulo $outro', isSelected: false),
        );
      }
      semantica.dispose();
    });

    testWidgets('sem capítulo atual, nenhuma célula vem selecionada', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, Brightness.dark);
      for (final numero in [1, 2, 3, 4]) {
        expect(
          tester.getSemantics(find.bySemanticsLabel('Capítulo $numero')),
          isSemantics(isSelected: false),
        );
      }
      semantica.dispose();
    });

    testWidgets('abre na grade do livro atual, e Todos os livros volta à '
        'lista', (tester) async {
      await montar(tester, Brightness.dark);
      expect(find.text('Rute'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '4'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '5'), findsNothing);
      expect(find.text('Escolha o livro'), findsNothing);

      await tester.tap(find.text('Todos os livros'));
      await tester.pumpAndSettle();
      expect(find.text('Escolha o livro'), findsOneWidget);
      expect(find.text('Todos os livros'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('com um livro que não existe, abre na lista de livros', (
      tester,
    ) async {
      await montar(tester, Brightness.dark, livroAtual: 'livro-x');
      expect(find.text('Escolha o livro'), findsOneWidget);
      expect(find.text('Todos os livros'), findsNothing);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, na grade de Rute, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho);
          expect(find.text('Todos os livros'), findsOneWidget);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });

        testWidgets('no tema $nomeDoTema, com o capítulo atual marcado, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho, capituloAtual: 3);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });
      }
    }
  });

  group('DevocionalBarraDaSelecao', () {
    const capitulo = Capitulo(
      livro: 'joao',
      numero: 3,
      titulo: '',
      versiculos: [
        (16, 'Porque Deus amou o mundo de tal maneira.'),
        (17, 'Porque Deus enviou o seu Filho ao mundo.'),
      ],
    );

    Future<void> montar(
      WidgetTester tester,
      Brightness brilho,
      Set<int> selecionados,
    ) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: DevocionalBarraDaSelecao(
              capitulo: capitulo,
              selecionados: selecionados,
              aoFechar: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('conta um versículo no singular e dois no plural', (
      tester,
    ) async {
      await montar(tester, Brightness.dark, {16});
      expect(find.text('1 versículo'), findsOneWidget);
      await montar(tester, Brightness.dark, {16, 17});
      expect(find.text('2 versículos'), findsOneWidget);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets(
          'no tema $nomeDoTema, com dois versículos, atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho, {16, 17});
            await _conferir(tester, diretriz);
            semantica.dispose();
          },
        );

        testWidgets(
          'no tema $nomeDoTema, com um versículo só, atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho, {16});
            await _conferir(tester, diretriz);
            semantica.dispose();
          },
        );
      }
    }
  });

  group('botão Próximo no fim do capítulo', () {
    // Sem os comentários a lista fica curta e o botão chega em poucas
    // rolagens; o objeto aqui é o fim do texto.
    setUp(() => Recursos.comentarioNoCapituloForcado = false);
    tearDown(() => Recursos.comentarioNoCapituloForcado = null);

    Future<void> rolarAteOFim(WidgetTester tester, Brightness brilho) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.runAsync(() async {
        await Conteudo.instancia.capitulo('genesis', 1);
        await Conteudo.instancia.introducao('genesis');
      });
      await tester.pumpWidget(
        _app(brilho, estado, const TelaBiblia(livroInicial: 'genesis')),
      );
      await tester.pumpAndSettle();
      final botao = find.text('Próximo: Gênesis 2');
      await tester.scrollUntilVisible(
        botao,
        400,
        scrollable: find
            .ancestor(
              of: find.byType(DevocionalLinhaDeVersiculo).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(botao, findsOneWidget);
    }

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, em Gênesis 1 rolado até o fim, '
            'atende $nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await rolarAteOFim(tester, brilho);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });
      }
    }
  });

  group('DevocionalLinhaDeVersiculo selecionada', () {
    // O versículo inteiro como fala de Jesus: a letra vermelha sobre o fundo
    // de selecionado também passa pela diretriz de contraste.
    const texto =
        'Porque Deus amou o mundo de tal maneira que deu o seu Filho '
        'unigênito.';

    Future<void> montar(
      WidgetTester tester,
      Brightness brilho, {
      required bool selecionado,
    }) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DevocionalLinhaDeVersiculo(
                  livro: 'joao',
                  capituloNumero: 3,
                  referencia: 'João 3:16',
                  numero: 16,
                  texto: texto,
                  comentario: null,
                  falasDivinas: const [(0, texto.length)],
                  noRecorte: true,
                  selecionando: true,
                  selecionado: selecionado,
                  aoAlternarSelecao: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('selecionado, o leitor de tela anuncia o estado', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, Brightness.dark, selecionado: true);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Porque Deus amou'))),
        isSemantics(isSelected: true),
      );
      semantica.dispose();
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets(
          'no tema $nomeDoTema, selecionado, atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho, selecionado: true);
            await _conferir(tester, diretriz);
            semantica.dispose();
          },
        );

        testWidgets('no tema $nomeDoTema, selecionando sem estar selecionado, '
            'atende $nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho, selecionado: false);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });
      }
    }
  });

  group('TelaConversas', () {
    tearDown(() => Recursos.conversasForcado = null);

    Future<void> montar(
      WidgetTester tester,
      Brightness brilho, {
      required bool comAcesso,
    }) async {
      Recursos.conversasForcado = comAcesso;
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(_app(brilho, estado, const TelaConversas()));
      await tester.pumpAndSettle();
    }

    testWidgets('a barra de cima tem o botão de ajustes rotulado', (
      tester,
    ) async {
      await montar(tester, Brightness.dark, comAcesso: true);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Ajustes e ajuda'),
        ),
        findsOneWidget,
      );
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, com acesso às conversas, atende '
            '$nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho, comAcesso: true);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });

        testWidgets('no tema $nomeDoTema, sem acesso (pedir pelo WhatsApp), '
            'atende $nomeDaDiretriz', (tester) async {
          final semantica = tester.ensureSemantics();
          await montar(tester, brilho, comAcesso: false);
          await _conferir(tester, diretriz);
          semantica.dispose();
        });
      }
    }
  });

  group('DevocionalCartaoDeEntrar', () {
    Future<void> montar(WidgetTester tester, Brightness brilho) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        _app(brilho, estado, const Scaffold(body: DevocionalCartaoDeEntrar())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('o título é um cabeçalho só dele, sem a descrição junto', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, Brightness.dark);
      // Hoje o Semantics(header: true) do título não é container e funde
      // com a descrição: o leitor de tela anuncia o parágrafo inteiro
      // como cabeçalho, e o rótulo exato do título não existe sozinho.
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Este plano é compartilhado por link'),
        ),
        isSemantics(isHeader: true),
      );
      semantica.dispose();
    });

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
      }
    }
  });

  group('DevocionalCartaoDePlano', () {
    Future<void> montar(
      WidgetTester tester,
      Brightness brilho, {
      bool compartilhado = false,
    }) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      final plano = PlanoDoUsuario(
        id: 'plano-teste',
        titulo: 'Evangelhos em 30 dias',
        livros: const ['mateus', 'marcos', 'lucas', 'joao'],
        dias: 30,
        criadoEm: DateTime(2026, 1, 1),
        compartilhado: compartilhado,
      );
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [DevocionalCartaoDePlano(plano: plano)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o título, o progresso e a lixeira rotulada', (
      tester,
    ) async {
      await montar(tester, Brightness.dark);
      expect(find.text('Evangelhos em 30 dias'), findsOneWidget);
      expect(find.text('0 de 30 dias lidos'), findsOneWidget);
      expect(find.byTooltip('Excluir plano'), findsOneWidget);
    });

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

        testWidgets(
          'no tema $nomeDoTema, compartilhado, atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, brilho, compartilhado: true);
            await _conferir(tester, diretriz);
            semantica.dispose();
          },
        );
      }
    }
  });

  group('DevocionalCartaoDeDia', () {
    Future<void> montar(
      WidgetTester tester,
      Brightness brilho, {
      required bool lido,
      VoidCallback? aoAlternar,
    }) async {
      _telaDeCelular(tester);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        _app(
          brilho,
          estado,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DevocionalCartaoDeDia(
                  numero: 5,
                  rotulo: 'Gênesis 13 a 15',
                  itens: const [],
                  lido: lido,
                  aoAlternar: aoAlternar ?? () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('não lido, o botão diz "Marcar como lido" e alterna', (
      tester,
    ) async {
      var toques = 0;
      await montar(
        tester,
        Brightness.light,
        lido: false,
        aoAlternar: () => toques++,
      );
      expect(find.text('Marcar como lido'), findsOneWidget);
      expect(
        find.byTooltip('Marcar Gênesis 13 a 15 como lido'),
        findsOneWidget,
      );
      await tester.tap(find.text('Marcar como lido'));
      expect(toques, 1);
    });

    testWidgets('lido, o botão diz "Dia lido" e o tooltip oferece desmarcar', (
      tester,
    ) async {
      await montar(tester, Brightness.dark, lido: true);
      expect(find.text('Dia lido'), findsOneWidget);
      expect(find.text('Marcar como lido'), findsNothing);
      expect(find.byTooltip('Desmarcar Gênesis 13 a 15'), findsOneWidget);
    });

    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        for (final lido in [false, true]) {
          testWidgets(
            'no tema $nomeDoTema, ${lido ? 'lido' : 'não lido'}, atende '
            '$nomeDaDiretriz',
            (tester) async {
              final semantica = tester.ensureSemantics();
              await montar(tester, brilho, lido: lido);
              await _conferir(tester, diretriz);
              semantica.dispose();
            },
          );
        }
      }
    }
  });
}

void _grupoDoCapituloDeLivro() {
  group('capítulo de livro com o Ouvir', () {
    // Ler o asset é I/O de verdade: carregado aqui, o leitor acha o livro na
    // cache em vez de girar o "Carregando" até o pumpAndSettle desistir.
    setUpAll(() => Biblioteca.instancia.capitulos('somente_pela_graca'));

    setUp(() {
      Recursos.ouvirTextosForcado = true;
      Voz.baseUrlForTest = 'https://test.audio';
      AudioOffline.temOfflineParaTeste = (_) => false;
    });
    tearDown(() {
      Recursos.ouvirTextosForcado = null;
      Voz.baseUrlForTest = null;
      AudioOffline.temOfflineParaTeste = null;
    });

    Future<void> montar(WidgetTester tester, Brightness brilho) async {
      _telaDeCelular(tester);
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
                  builder: (context, state) => const TelaLeitorDeLivro(
                    slug: 'somente_pela_graca',
                    capitulo: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o Ouvir abaixo do título do capítulo', (tester) async {
      await montar(tester, Brightness.light);
      expect(find.text('Ouvir'), findsOneWidget);
    });

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
      }
    }
  });
}
