import 'package:devocional/controladores/leitor_de_livro_controlador.dart';
import 'package:devocional/controladores/notas_controlador.dart';
import 'package:devocional/dados/biblioteca.dart';
import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/dia_da_leitura.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/leitura_de_livros.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/funcoes/convite_para_marcar.dart';
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

/// O cronograma anual e a leitura do dia aparecem sem conta, mas nada pessoal
/// com eles: marcar um dia pede conta, e o fim do capítulo só convida a entrar.

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

  /// O dia 1º de março de 2026 já marcado como lido no aparelho, de antes de
  /// a pessoa sair da conta.
  Future<Estado> abrirComMarcaAntiga() async {
    final estado = await abrir();
    await estado.alternarLido('2026-03-01');
    return estado;
  }

  /// O cronograma sai de um asset: a leitura de arquivo é real, e o relógio
  /// falso do teste não a espera.
  Future<void> carregarPlano(WidgetTester tester) => tester.runAsync(() async {
    await Conteudo.instancia.plano(bissexto: false);
    await Conteudo.instancia.diaDoPlano(DateTime(2026, 3, 1));
  });

  Future<void> montarCom(
    WidgetTester tester,
    Estado estado,
    Widget filho,
  ) async {
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: MaterialApp(home: Scaffold(body: filho)),
      ),
    );
    await tester.pump();
  }

  testWidgets('sem conta, a aba do cronograma mostra o calendário sem lidos', (
    tester,
  ) async {
    await carregarPlano(tester);
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrirComMarcaAntiga();

    await montarCom(
      tester,
      estado,
      TabernaculoAbaDoCronograma(hoje: DateTime(2026, 3, 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entre para ver o plano'), findsNothing);
    expect(find.byType(TabernaculoCartaoDeDia), findsWidgets);
    expect(find.text('0 de 31 dias concluídos em Março'), findsOneWidget);
    expect(find.text('Dia lido'), findsNothing);
  });

  testWidgets('com conta, a aba do cronograma mostra o dia lido', (
    tester,
  ) async {
    await carregarPlano(tester);
    Nuvem.instancia.logadoForcado = true;
    final estado = await abrirComMarcaAntiga();

    await montarCom(
      tester,
      estado,
      TabernaculoAbaDoCronograma(hoje: DateTime(2026, 3, 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 de 31 dias concluídos em Março'), findsOneWidget);
    expect(find.text('Dia lido'), findsOneWidget);
  });

  testWidgets('restaurando a conta, a aba do cronograma espera', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;
    Nuvem.instancia.carregandoContaForcado = true;

    await montar(
      tester,
      TabernaculoAbaDoCronograma(hoje: DateTime(2026, 3, 1)),
    );

    expect(find.byType(TabernaculoVerificandoConta), findsOneWidget);
    expect(find.byType(TabernaculoCartaoDeDia), findsNothing);
  });

  testWidgets('sem conta, tocar em marcar no cronograma abre o convite', (
    tester,
  ) async {
    await carregarPlano(tester);
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrir();
    await montarCom(
      tester,
      estado,
      TabernaculoAbaDoCronograma(hoje: DateTime(2026, 3, 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marcar como lido').first);
    await tester.pumpAndSettle();

    expect(find.text('Entre para marcar a leitura'), findsOneWidget);
    expect(
      find.text('Os dias lidos ficam guardados na sua conta Google.'),
      findsOneWidget,
    );
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(estado.diasLidosNoAno(2026), 0);
  });

  testWidgets('sem conta, a Hoje mostra a leitura, sem o progresso do ano', (
    tester,
  ) async {
    await carregarPlano(tester);
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrirComMarcaAntiga();

    await montarCom(
      tester,
      estado,
      TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
    expect(find.byType(TabernaculoCartaoLeituraProgresso), findsOneWidget);
    expect(find.text('Leitura de hoje'), findsOneWidget);
    expect(find.byType(TabernaculoBotaoDeFaixa), findsWidgets);
    expect(find.text('Progresso do ano'), findsNothing);
    expect(find.byType(TabernaculoProgressoFino), findsNothing);
    expect(find.byTooltip(RegExp('^Marcar .* como lido')), findsOneWidget);
  });

  testWidgets('com conta, a Hoje mantém o progresso do ano', (tester) async {
    await carregarPlano(tester);
    Nuvem.instancia.logadoForcado = true;

    await montar(tester, TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)));
    await tester.pumpAndSettle();

    expect(find.text('Progresso do ano'), findsOneWidget);
  });

  testWidgets('sem conta, tocar no círculo da Hoje abre o convite', (
    tester,
  ) async {
    await carregarPlano(tester);
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrir();
    await montarCom(
      tester,
      estado,
      TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TabernaculoBotaoDeLido));
    await tester.pumpAndSettle();

    expect(find.text('Entre para marcar a leitura'), findsOneWidget);
    expect(estado.diasLidosNoAno(2026), 0);
  });

  testWidgets('restaurando a conta, o círculo não abre o convite', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrir();
    late BuildContext contexto;
    await montarCom(
      tester,
      estado,
      Builder(
        builder: (context) {
          contexto = context;
          return const SizedBox();
        },
      ),
    );
    Nuvem.instancia.carregandoContaForcado = true;

    await alternarLidoOuConvidar(contexto, estado, '2026-03-01');
    await tester.pumpAndSettle();

    expect(find.text('Entre para marcar a leitura'), findsNothing);
    expect(estado.foiLido('2026-03-01'), isFalse);
  });

  testWidgets('login pelo convite fecha a folha e marca o dia', (tester) async {
    await carregarPlano(tester);
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrir();
    // Sem o diálogo de consentimento no caminho.
    await estado.registrarConsentimentoDaNuvem();
    await montarCom(
      tester,
      estado,
      TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TabernaculoBotaoDeLido));
    await tester.pumpAndSettle();

    // O Firebase não existe no teste: o login falha com aviso, e aqui a conta
    // chega como se ele tivesse completado.
    Nuvem.instancia.logadoForcado = true;
    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    expect(find.text('Entre para marcar a leitura'), findsNothing);
    expect(estado.foiLido('2026-03-01'), isTrue);
    expect(find.text('Dia marcado como lido'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('com conta, o círculo da Hoje marca direto, sem convite', (
    tester,
  ) async {
    await carregarPlano(tester);
    Nuvem.instancia.logadoForcado = true;
    final estado = await abrir();
    await montarCom(
      tester,
      estado,
      TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TabernaculoBotaoDeLido));
    await tester.pumpAndSettle();

    expect(find.text('Entre para marcar a leitura'), findsNothing);
    expect(estado.diasLidosNoAno(2026), 1);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('restaurando a conta, a Hoje não mostra o cartão', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;
    Nuvem.instancia.carregandoContaForcado = true;

    await montar(tester, TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)));

    expect(find.byType(TabernaculoCartaoLeituraProgresso), findsNothing);
    expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
  });

  group('fim da leitura do dia do cronograma', () {
    const chave = '2026-11-24';
    late BuildContext contexto;

    Future<Estado> montarFim(WidgetTester tester) async {
      final estado = await abrir();
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  contexto = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      return estado;
    }

    testWidgets('sem conta, não marca o dia e convida a entrar', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await montarFim(tester);

      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        const DiaDoCronograma(chave: chave, capitulos: ['joao.3']),
      );
      await tester.pump();

      expect(estado.foiLido(chave), isFalse);
      expect(find.text('Entre para guardar a leitura do dia'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('sem conta, o aviso sai uma vez por leitura terminada', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await montarFim(tester);
      const dia = DiaDoCronograma(
        chave: chave,
        capitulos: ['genesis.1', 'salmos.1'],
      );

      await registrarCapituloLidoDoDia(contexto, estado, dia, 'genesis', 1);
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);

      await registrarCapituloLidoDoDia(contexto, estado, dia, 'salmos', 1);
      await tester.pump();
      expect(find.text('Entre para guardar a leitura do dia'), findsOneWidget);
      expect(estado.foiLido(chave), isFalse);
      expect(estado.progressoDosDias.lidosDoDia(dia.chaveDoProgresso), isEmpty);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets(
      'sem conta, o Entrar do aviso marca o dia se o login completa',
      (tester) async {
        Nuvem.instancia.logadoForcado = false;
        final estado = await montarFim(tester);
        await estado.registrarConsentimentoDaNuvem();
        await marcarDiaDaLeituraAoTerminar(
          contexto,
          estado,
          const DiaDoCronograma(chave: chave, capitulos: ['joao.3']),
        );
        await tester.pumpAndSettle();

        // O Firebase não existe no teste: o login falha com aviso, e aqui a
        // conta chega como se ele tivesse completado.
        Nuvem.instancia.logadoForcado = true;
        await tester.tap(find.text('Entrar'));
        await tester.pumpAndSettle();

        expect(estado.foiLido(chave), isTrue);
        await tester.pump(const Duration(seconds: 9));
      },
    );
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
