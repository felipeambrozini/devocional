import 'package:devocional/dados/biblioteca.dart';
import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/dia_da_leitura.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/telas/biblia.dart';
import 'package:devocional/telas/leitor_de_livro.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O capítulo da Biblioteca e a Bíblia marcando a leitura sozinhos ao chegar
/// ao fim, e o botão "Terminar a leitura" do sumário do livro.

const _slug = 'somente_pela_graca';
const _espera = Duration(milliseconds: 100);

final _obra = obrasDaBiblioteca.firstWhere((o) => o.slug == _slug);

const _temas = {'claro': Brightness.light, 'escuro': Brightness.dark};

GoRouter _roteador(String inicial) => GoRouter(
  initialLocation: inicial,
  routes: [
    GoRoute(
      path: '/biblioteca/:slug/:capitulo',
      builder: (context, state) => TelaLeitorDeLivro(
        slug: state.pathParameters['slug']!,
        capitulo: int.tryParse(state.pathParameters['capitulo']!) ?? 0,
      ),
    ),
  ],
);

void main() {
  late List<CapituloDoLivro> capitulos;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    capitulos = (await Biblioteca.instancia.capitulos(_slug))!;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // O ramo do cronograma só marca com conta.
    Nuvem.instancia.logadoForcado = true;
    TabernaculoVigiaDoFim.esperaSemRolagem = _espera;
  });
  tearDown(() {
    Nuvem.instancia.logadoForcado = null;
    TabernaculoVigiaDoFim.esperaSemRolagem = const Duration(seconds: 20);
  });

  Future<Estado> abrirEstado() async =>
      Estado(await SharedPreferences.getInstance());

  group('capítulo da Biblioteca', () {
    Future<Estado> abrir(WidgetTester tester, int capitulo) async {
      final estado = await abrirEstado();
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(
            routerConfig: _roteador('/biblioteca/$_slug/$capitulo'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return estado;
    }

    /// Rola com o dedo até não restar nada embaixo, como a pessoa lendo.
    Future<void> lerAteOFim(WidgetTester tester) async {
      final posicao = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      for (var i = 0; i < 40 && posicao.extentAfter > 1; i++) {
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -1500),
        );
        await tester.pumpAndSettle();
      }
      expect(posicao.extentAfter, lessThanOrEqualTo(1));
    }

    testWidgets('rolar até o fim marca o capítulo como lido', (tester) async {
      final estado = await abrir(tester, 1);
      expect(estado.leituraDeLivros.foiLido(_slug, 0), isFalse);

      await lerAteOFim(tester);

      expect(estado.leituraDeLivros.foiLido(_slug, 0), isTrue);
      expect(estado.leituraDeLivros.quantosLidos(_slug), 1);
    });

    testWidgets('rolar só até o meio não marca', (tester) async {
      final estado = await abrir(tester, 1);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(estado.leituraDeLivros.foiLido(_slug, 0), isFalse);
    });

    testWidgets('um capítulo já marcado continua marcado, sem desmarcar', (
      tester,
    ) async {
      final estado = await abrir(tester, 1);
      await estado.leituraDeLivros.alternarLido(_slug, 0);
      await tester.pumpAndSettle();
      expect(find.text('Capítulo lido'), findsOneWidget);

      await lerAteOFim(tester);

      expect(estado.leituraDeLivros.foiLido(_slug, 0), isTrue);
      expect(find.text('Capítulo lido'), findsOneWidget);
    });

    testWidgets('abrir um capítulo com a posição salva no fim não marca', (
      tester,
    ) async {
      // A Biblioteca volta ao ponto em que se parou com um jumpTo: isso não
      // é ter lido.
      SharedPreferences.setMockInitialValues({});
      final previo = await abrirEstado();
      await previo.leituraDeLivros.registrarPosicao(_slug, 0, 1);

      final estado = await abrirEstado();
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(
            routerConfig: _roteador('/biblioteca/$_slug/1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(_espera * 3);

      expect(estado.leituraDeLivros.foiLido(_slug, 0), isFalse);
    });

    testWidgets('a barra tem favoritos e notas, e o corpo o nome do livro', (
      tester,
    ) async {
      await abrir(tester, 3);
      expect(find.byType(TabernaculoBotaoDeNotas), findsOneWidget);

      final corpo = find.byType(SingleChildScrollView).first;
      expect(
        find.descendant(of: corpo, matching: find.text(_obra.titulo)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: corpo,
          matching: find.text('Capítulo 3 de ${capitulos.length}'),
        ),
        findsOneWidget,
      );
    });
  });

  group('sumário do livro e Terminar a leitura', () {
    Future<Estado> montar(
      WidgetTester tester, {
      Brightness brilho = Brightness.light,
      Future<void> Function(Estado estado)? preparar,
    }) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final estado = await abrirEstado();
      await preparar?.call(estado);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            theme: construirTema(brilho: brilho),
            home: Scaffold(
              body: TabernaculoSumarioDoLivro(
                obra: _obra,
                capitulos: capitulos,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return estado;
    }

    testWidgets('sem leitura nenhuma, o botão não aparece', (tester) async {
      await montar(tester);
      expect(find.text('Começar a ler'), findsOneWidget);
      expect(find.text('Terminar a leitura'), findsNothing);
    });

    testWidgets('com a posição registrada, o botão aparece', (tester) async {
      await montar(
        tester,
        preparar: (e) => e.leituraDeLivros.registrarPosicao(_slug, 2, 0.3),
      );
      expect(find.text('Continuar de onde parei'), findsOneWidget);
      expect(find.text('Terminar a leitura'), findsOneWidget);
    });

    testWidgets('só com um capítulo marcado, o botão aparece', (tester) async {
      await montar(
        tester,
        preparar: (e) => e.leituraDeLivros.alternarLido(_slug, 4),
      );
      expect(find.text('Começar a ler'), findsOneWidget);
      expect(find.text('Terminar a leitura'), findsOneWidget);
    });

    testWidgets('o botão some depois de terminar', (tester) async {
      await montar(
        tester,
        preparar: (e) => e.leituraDeLivros.registrarPosicao(_slug, 2, 0),
      );
      await tester.tap(find.text('Terminar a leitura'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(find.text('Terminar a leitura'), findsNothing);
      expect(find.text('Começar a ler'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('cancelar a confirmação não muda nada', (tester) async {
      final estado = await montar(
        tester,
        preparar: (e) async {
          await e.leituraDeLivros.registrarPosicao(_slug, 2, 0.3);
          await e.leituraDeLivros.alternarLido(_slug, 1);
        },
      );
      await tester.tap(find.text('Terminar a leitura'));
      await tester.pumpAndSettle();
      expect(find.text('Terminar a leitura?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(estado.leituraDeLivros.posicaoDe(_slug)!.capitulo, 2);
      expect(estado.leituraDeLivros.quantosLidos(_slug), 1);
      expect(estado.leituraDeLivros.vezesConcluido(_slug), 0);
    });

    testWidgets('confirmar zera a posição e soma uma conclusão', (
      tester,
    ) async {
      final estado = await montar(
        tester,
        preparar: (e) async {
          await e.leituraDeLivros.registrarPosicao(_slug, 2, 0.3);
          await e.leituraDeLivros.alternarLido(_slug, 1);
          await e.leituraDeLivros.definirNota(_slug, 1, 0, 'guardar');
        },
      );
      await tester.tap(find.text('Terminar a leitura'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(estado.leituraDeLivros.posicaoDe(_slug), isNull);
      expect(estado.leituraDeLivros.quantosLidos(_slug), 0);
      expect(estado.leituraDeLivros.vezesConcluido(_slug), 1);
      expect(estado.leituraDeLivros.destaquesDe(_slug, 1)[0]!.nota, 'guardar');
      expect(find.textContaining('Você terminou'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    for (final MapEntry(key: nome, value: brilho) in _temas.entries) {
      testWidgets('com o botão à vista, cumpre as diretrizes no tema $nome', (
        tester,
      ) async {
        final semantica = tester.ensureSemantics();
        await montar(
          tester,
          brilho: brilho,
          preparar: (e) => e.leituraDeLivros.registrarPosicao(_slug, 2, 0.3),
        );
        expect(find.text('Terminar a leitura'), findsOneWidget);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantica.dispose();
      });
    }
  });

  group('TelaBiblia com o dia da leitura', () {
    const chave = '2026-11-24';
    const umCapitulo = DiaDoCronograma(chave: chave, capitulos: ['3joao.1']);
    const duasCartas = DiaDoCronograma(
      chave: chave,
      capitulos: ['2joao.1', '3joao.1'],
    );

    Future<void> montarTela(
      WidgetTester tester,
      Estado estado,
      String livro,
      DiaDaLeitura? dia,
    ) async {
      // Alta, para 2 e 3 João (capítulos curtos) caberem sem rolar.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => Conteudo.instancia.capitulo(livro, 1));
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            // A chave nova faz uma TelaBiblia nova a cada leitura, como abrir
            // outro link /ler.
            home: TelaBiblia(
              key: UniqueKey(),
              livroInicial: livro,
              capituloInicial: 1,
              dia: dia,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<Estado> abrir(
      WidgetTester tester,
      DiaDaLeitura? dia, {
      String livro = '3joao',
    }) async {
      final estado = await abrirEstado();
      await montarTela(tester, estado, livro, dia);
      return estado;
    }

    Future<void> esperar(WidgetTester tester) async {
      await tester.pump(_espera * 3);
      await tester.pumpAndSettle();
    }

    testWidgets('o único capítulo do dia, lido até o fim, marca o dia', (
      tester,
    ) async {
      final estado = await abrir(tester, umCapitulo);

      await esperar(tester);

      expect(estado.foiLido(chave), isTrue);
      expect(find.text('Leitura do dia marcada como lida'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('um capítulo que não é do dia não marca', (tester) async {
      final estado = await abrir(
        tester,
        const DiaDoCronograma(chave: chave, capitulos: ['joao.3']),
      );
      await esperar(tester);
      expect(estado.foiLido(chave), isFalse);
      expect(find.text('Leitura do dia marcada como lida'), findsNothing);
      expect(estado.progressoDosDias.lidosDoDia('cronograma:$chave'), isEmpty);
    });

    testWidgets('num dia de dois capítulos, o primeiro sozinho não marca', (
      tester,
    ) async {
      final estado = await abrir(tester, duasCartas, livro: '2joao');

      await esperar(tester);

      expect(estado.foiLido(chave), isFalse);
      expect(find.text('Leitura do dia marcada como lida'), findsNothing);
      expect(estado.progressoDosDias.lidosDoDia('cronograma:$chave'), {
        '2joao.1',
      });
    });

    testWidgets('abrir o outro capítulo depois completa o dia e marca', (
      tester,
    ) async {
      final estado = await abrir(tester, duasCartas, livro: '2joao');
      await esperar(tester);
      expect(estado.foiLido(chave), isFalse);

      await montarTela(tester, estado, '3joao', duasCartas);
      await esperar(tester);

      expect(estado.foiLido(chave), isTrue);
      expect(find.text('Leitura do dia marcada como lida'), findsOneWidget);
      expect(estado.progressoDosDias.lidosDoDia('cronograma:$chave'), isEmpty);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('sem dia, ler não marca nada', (tester) async {
      final estado = await abrir(tester, null);
      await esperar(tester);
      expect(estado.foiLido(chave), isFalse);
      expect(find.byType(SnackBar), findsNothing);
      expect(estado.progressoDosDias.lidosDoDia('cronograma:$chave'), isEmpty);
    });

    testWidgets('o dia de um plano local marca o dia do plano', (tester) async {
      final estado = await abrirEstado();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['3joao'],
        dias: 1,
      );

      await montarTela(
        tester,
        estado,
        '3joao',
        DiaDePlano(planoId: plano.id, numero: 1, capitulos: const ['3joao.1']),
      );
      await esperar(tester);

      expect(estado.foiLidoNoPlano(plano.id, 1), isTrue);
      // O plano tem um dia só: marcá-lo conclui o plano, e o aviso diz isso
      // em vez do número do dia (ver conclusao_do_plano.dart).
      expect(find.text('Você concluiu o plano Cartas'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });
  });
}
