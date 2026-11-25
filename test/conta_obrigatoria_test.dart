import 'package:devocional/controladores/leitor_de_livro_controlador.dart';
import 'package:devocional/controladores/notas_controlador.dart';
import 'package:devocional/dados/biblioteca.dart';
import 'package:devocional/dados/dia_da_leitura.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/leitura_de_livros.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/funcoes/marcar_dia_da_leitura.dart';
import 'package:devocional/telas/hoje.dart';
import 'package:devocional/telas/leitor_de_livro.dart';
import 'package:devocional/telas/notas.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O cronograma anual e a leitura do dia só existem com conta: sem ela, o
/// lugar deles é um convite para entrar, e o fim do capítulo não marca nada.

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    Nuvem.instancia.logadoForcado = null;
    Nuvem.instancia.carregandoContaForcado = null;
  });

  Future<Estado> abrir() async => Estado(await SharedPreferences.getInstance());

  Future<void> montar(WidgetTester tester, Widget filho) async {
    final estado = await abrir();
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: MaterialApp(home: Scaffold(body: filho)),
      ),
    );
    await tester.pump();
  }

  testWidgets('sem conta, a aba do cronograma pede login', (tester) async {
    Nuvem.instancia.logadoForcado = false;

    await montar(
      tester,
      TabernaculoAbaDoCronograma(hoje: DateTime(2026, 3, 1)),
    );

    expect(find.text('Entre para ver o plano'), findsOneWidget);
    expect(find.byType(TabernaculoCartaoDeDia), findsNothing);
  });

  testWidgets('sem conta, a Hoje mostra o convite no lugar da leitura do dia', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;

    await montar(tester, TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)));

    expect(find.byType(TabernaculoCartaoDeEntrar), findsOneWidget);
    expect(find.byType(TabernaculoCartaoLeituraProgresso), findsNothing);
  });

  testWidgets('restaurando a conta, a Hoje não mostra o convite', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;
    Nuvem.instancia.carregandoContaForcado = true;

    await montar(tester, TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)));

    expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
  });

  testWidgets('sem conta, chegar ao fim do capítulo não marca o dia', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrir();
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              contexto = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    const chave = '2026-11-24';

    await marcarDiaDaLeituraAoTerminar(
      contexto,
      estado,
      const DiaDoCronograma(chave: chave, capitulos: ['joao.3']),
    );
    await tester.pump();

    expect(estado.foiLido(chave), isFalse);
  });

  group('progresso dos livros', () {
    const slug = 'somente_pela_graca';
    final obra = obrasDaBiblioteca.firstWhere((o) => o.slug == slug);

    Future<List<CapituloDoLivro>> capitulos() async =>
        (await Biblioteca.instancia.capitulos(slug))!;

    Future<void> montarLivro(WidgetTester tester, Estado estado) async {
      final lista = (await tester.runAsync(capitulos))!;
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Scaffold(
              body: TabernaculoSumarioDoLivro(obra: obra, capitulos: lista),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sem conta, abrir um capítulo não grava a posição', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      final controlador = LeitorDeLivroControlador(
        estado: estado,
        slug: slug,
        capitulo: 2,
      );
      addTearDown(controlador.dispose);

      controlador.iniciar();
      controlador.guardarPosicao();

      expect(estado.leituraDeLivros.posicaoDe(slug), isNull);
    });

    testWidgets(
      'sem conta, o sumário mostra Começar a ler e não mostra Terminar a leitura',
      (tester) async {
        Nuvem.instancia.logadoForcado = false;
        final estado = await abrir();
        await estado.leituraDeLivros.registrarPosicao(slug, 2, 0.3);

        await montarLivro(tester, estado);

        expect(find.text('Começar a ler'), findsOneWidget);
        expect(find.text('Continuar de onde parei'), findsNothing);
        expect(find.text('Terminar a leitura'), findsNothing);
      },
    );

    testWidgets('sem conta, o cartão da obra não mostra progresso', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      await estado.leituraDeLivros.registrarPosicao(slug, 2, 0.3);
      await estado.leituraDeLivros.alternarLido(slug, 0);
      final total = (await tester.runAsync(capitulos))!.length;

      await montar(tester, TabernaculoCartaoDaObra(obra: obra, aoAbrir: null));
      await tester.pumpAndSettle();

      expect(find.text('$total capítulos'), findsOneWidget);
      expect(find.text('Leitura começada'), findsNothing);
      expect(find.textContaining('lidos'), findsNothing);
    });

    testWidgets('sem conta, a Hoje não mostra livros em leitura', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      await estado.leituraDeLivros.registrarPosicao(slug, 2, 0.3);
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(estado: estado, child: const TelaHoje()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(find.byType(TabernaculoLivrosEmLeitura), findsNothing);
      expect(find.byType(TabernaculoCartaoDaObra), findsNothing);
    });

    testWidgets('com conta, o sumário mostra Continuar de onde parei', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = true;
      final estado = await abrir();
      await estado.leituraDeLivros.registrarPosicao(slug, 2, 0.3);

      await montarLivro(tester, estado);

      expect(find.text('Continuar de onde parei'), findsOneWidget);
      expect(find.text('Terminar a leitura'), findsOneWidget);
    });
  });

  group('favoritos e notas', () {
    const texto =
        'Porque Deus amou o mundo de tal maneira que deu o seu Filho '
        'unigênito.';

    Finder iconeDe(FaIconData icone) =>
        find.byWidgetPredicate((w) => w is FaIcon && w.icon == icone.data);

    Future<Estado> montarVersiculo(
      WidgetTester tester, [
      Estado? previo,
    ]) async {
      final estado = previo ?? await abrir();
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  TabernaculoLinhaDeVersiculo(
                    livro: 'joao',
                    capituloNumero: 3,
                    referencia: 'João 3',
                    numero: 16,
                    texto: texto,
                    comentario: null,
                    falasDivinas: const [],
                    noRecorte: true,
                    selecionando: false,
                    selecionado: false,
                    aoAlternarSelecao: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return estado;
    }

    testWidgets(
      'sem conta, a folha do versículo tem só Copiar e Compartilhar',
      (tester) async {
        Nuvem.instancia.logadoForcado = false;
        await montarVersiculo(tester);

        await tester.tap(find.textContaining('Porque Deus amou'));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Copiar'), findsOneWidget);
        expect(find.text('Compartilhar'), findsOneWidget);
        expect(find.text('Anotar'), findsNothing);
        expect(find.text('Favoritar'), findsNothing);
      },
    );

    testWidgets('com conta, a folha do versículo mantém Anotar e Favoritar', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = true;
      await montarVersiculo(tester);

      await tester.tap(find.textContaining('Porque Deus amou'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Compartilhar'), findsOneWidget);
      expect(find.text('Anotar'), findsOneWidget);
      expect(find.text('Favoritar'), findsOneWidget);
    });

    testWidgets(
      'sem conta, um versículo favoritado antes não aparece destacado',
      (tester) async {
        Nuvem.instancia.logadoForcado = false;
        final estado = await abrir();
        await estado.alternarFavorito('joao', 3, 16);
        await estado.definirNota('joao', 3, 16, 'minha nota');
        await montarVersiculo(tester, estado);

        expect(iconeDe(FontAwesomeIcons.solidBookmark), findsNothing);
        expect(find.text('minha nota'), findsNothing);
      },
    );

    testWidgets('com conta, o versículo favoritado aparece destacado', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = true;
      final estado = await abrir();
      await estado.alternarFavorito('joao', 3, 16);
      await montarVersiculo(tester, estado);

      expect(iconeDe(FontAwesomeIcons.solidBookmark), findsOneWidget);
    });

    testWidgets('sem conta, a barra de cima não tem o ícone de marcador', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;

      await montar(
        tester,
        const TabernaculoBotaoDeNotas(origem: OrigemDasNotas.biblia),
      );

      expect(iconeDe(FontAwesomeIcons.bookmark), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('com conta, a barra de cima tem o ícone de marcador', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = true;

      await montar(
        tester,
        const TabernaculoBotaoDeNotas(origem: OrigemDasNotas.biblia),
      );

      expect(iconeDe(FontAwesomeIcons.bookmark), findsOneWidget);
    });

    Future<void> montarDevocional(WidgetTester tester, Estado estado) async {
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  TabernaculoCartaoDeLeitura(
                    titulo: 'Manhã',
                    nomeDaLeitura: 'Devocional da manhã',
                    data: DateTime(2026, 1, 1),
                    dev: const Devocional(referencia: '', texto: ''),
                    texto: 'Aqui está o evangelho num versículo.',
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
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'sem conta, a folha do devocional tem só Copiar e Compartilhar',
      (tester) async {
        Nuvem.instancia.logadoForcado = false;
        await montarDevocional(tester, await abrir());

        await tester.tap(find.byType(TabernaculoParagrafoDeLivro));
        await tester.pumpAndSettle();

        expect(find.text('Copiar'), findsOneWidget);
        expect(find.text('Compartilhar'), findsOneWidget);
        expect(find.text('Anotar'), findsNothing);
        expect(find.text('Favoritar'), findsNothing);
      },
    );

    testWidgets('com conta, a folha do devocional mantém Anotar e Favoritar', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = true;
      await montarDevocional(tester, await abrir());

      await tester.tap(find.byType(TabernaculoParagrafoDeLivro));
      await tester.pumpAndSettle();

      expect(find.text('Anotar'), findsOneWidget);
      expect(find.text('Favoritar'), findsOneWidget);
    });

    testWidgets(
      'sem conta, o devocional favoritado antes não aparece grifado',
      (tester) async {
        Nuvem.instancia.logadoForcado = false;
        final estado = await abrir();
        await estado.leituraDeLivros.alternarDestaque(
          slugDoDevocional('manha'),
          1,
          paragrafoDoDevocional,
        );
        await montarDevocional(tester, estado);

        final paragrafo = tester.widget<TabernaculoParagrafoDeLivro>(
          find.byType(TabernaculoParagrafoDeLivro),
        );
        expect(paragrafo.destaque, isNull);
      },
    );
  });

  group('capítulo aberto', () {
    const slug = 'somente_pela_graca';

    /// [numero] 0 abre o último capítulo.
    Future<Estado> abrirCapitulo(WidgetTester tester, int numero) async {
      final total = (await tester.runAsync(
        () => Biblioteca.instancia.capitulos(slug),
      ))!.length;
      final estado = await abrir();
      final roteador = GoRouter(
        initialLocation: '/biblioteca/$slug/${numero == 0 ? total : numero}',
        routes: [
          GoRoute(
            path: '/biblioteca/:slug',
            builder: (context, state) =>
                const Scaffold(body: Text('SUMARIO DO LIVRO')),
            routes: [
              GoRoute(
                path: ':n',
                builder: (context, state) => TelaLeitorDeLivro(
                  slug: slug,
                  capitulo: int.parse(state.pathParameters['n']!),
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(routerConfig: roteador),
        ),
      );
      await tester.pumpAndSettle();
      return estado;
    }

    testWidgets('sem conta, a folha do parágrafo tem só Copiar', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      await abrirCapitulo(tester, 1);

      await tester.tap(find.byType(TabernaculoParagrafoDeLivro).first);
      await tester.pumpAndSettle();

      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Anotar'), findsNothing);
      expect(find.text('Favoritar'), findsNothing);
    });

    testWidgets('com conta, a folha do parágrafo mantém Anotar e Favoritar', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = true;
      await abrirCapitulo(tester, 1);

      await tester.tap(find.byType(TabernaculoParagrafoDeLivro).first);
      await tester.pumpAndSettle();

      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Anotar'), findsOneWidget);
      expect(find.text('Favoritar'), findsOneWidget);
    });

    testWidgets('sem conta, o capítulo não tem Marcar como lido nem Terminar', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrirCapitulo(tester, 0);

      // Rola até o fim, como quem lê: não marca nada.
      for (var i = 0; i < 40; i++) {
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -1500),
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Marcar como lido'), findsNothing);
      expect(find.text('Capítulo lido'), findsNothing);
      expect(find.text('Terminar a leitura'), findsNothing);
      expect(estado.leituraDeLivros.quantosLidos(slug), 0);
    });

    testWidgets(
      'sem conta, avançar depois do último capítulo volta ao sumário',
      (tester) async {
        Nuvem.instancia.logadoForcado = false;
        final estado = await abrirCapitulo(tester, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        expect(find.text('SUMARIO DO LIVRO'), findsOneWidget);
        expect(estado.leituraDeLivros.quantosLidos(slug), 0);
        expect(estado.leituraDeLivros.posicaoDe(slug), isNull);
      },
    );
  });

  group('tela de notas', () {
    Future<void> montarNotas(WidgetTester tester, Estado estado) async {
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: const MaterialApp(home: TelaNotas()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sem conta, /notas pede login e não mostra a faixa de perda', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      await estado.alternarFavorito('joao', 3, 16);

      await montarNotas(tester, estado);

      expect(find.text('Entre para ver favoritos e notas'), findsOneWidget);
      expect(find.byType(TabernaculoAvisoDePerda), findsNothing);
      expect(find.textContaining('Favoritos ('), findsNothing);
    });

    testWidgets('com conta, /notas mostra os favoritos', (tester) async {
      Nuvem.instancia.logadoForcado = true;
      final estado = await abrir();
      await estado.alternarFavorito('joao', 3, 16);

      await montarNotas(tester, estado);

      expect(find.text('Favoritos (1)'), findsOneWidget);
      expect(find.text('Entre para ver favoritos e notas'), findsNothing);
    });
  });
}
