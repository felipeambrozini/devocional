import 'dart:async';
import 'dart:convert';

import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/leitura_de_livros.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/telas/cronograma_do_ano.dart';
import 'package:devocional/telas/perfil.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tela de perfil: cabeçalho da conta, cronograma de anos anteriores,
/// planos concluídos, favoritos e notas, e a conta (Sair, Apagar).
void main() {
  final hoje = DateTime(2026, 11, 25);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Nuvem.instancia.logadoForcado = true;
  });
  tearDown(() {
    Nuvem.instancia.logadoForcado = null;
    Nuvem.instancia.nomeForcado = null;
    Nuvem.instancia.emailForcado = null;
    Nuvem.instancia.sairForcado = null;
  });

  Future<Estado> abrir() async => Estado(await SharedPreferences.getInstance());

  /// Deixa o aviso do Sair (snackbar) terminar, para não sobrar timer.
  Future<void> esgotarAvisos(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  /// O calendário carrega o cronograma do disco: I/O de verdade, fora do
  /// tempo falso do teste.
  Future<void> esperarCronograma(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Uma tela alta, para todas as seções caberem sem rolar.
  void telaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// O perfil empilhado sobre uma Hoje de mentira, como no app: o voltar e o
  /// `go('/hoje')` do Sair têm para onde ir.
  Future<GoRouter> montar(
    WidgetTester tester,
    Estado estado, {
    Brightness brilho = Brightness.light,
  }) async {
    final router = GoRouter(
      initialLocation: '/hoje',
      routes: [
        GoRoute(
          path: '/hoje',
          builder: (context, state) =>
              const Scaffold(body: Text('Tela da Hoje')),
        ),
        GoRoute(
          path: '/perfil',
          builder: (context, state) => TelaPerfil(hoje: hoje),
          routes: [
            GoRoute(
              path: 'cronograma/:ano',
              builder: (context, state) => TelaCronogramaDoAno(
                ano: int.parse(state.pathParameters['ano']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/notas',
          builder: (context, state) =>
              Scaffold(body: Text('Notas ${state.uri}')),
        ),
        GoRoute(
          path: '/plano/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Plano ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: MaterialApp.router(
          theme: construirTema(brilho: brilho),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/perfil'));
    await tester.pumpAndSettle();
    return router;
  }

  /// As chaves de leitura (`AAAA-MM-DD`) de [quantos] dias de [ano], de 1º de
  /// janeiro em diante.
  List<String> diasDe(int ano, int quantos) => [
    for (var i = 0; i < quantos; i++)
      () {
        final d = DateTime(ano, 1, 1 + i);
        return '$ano-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }(),
  ];

  testWidgets('perfil mostra nome e e-mail', (tester) async {
    Nuvem.instancia.nomeForcado = 'Maria Clara Souza';
    Nuvem.instancia.emailForcado = 'maria@exemplo.com';
    await montar(tester, await abrir());

    expect(find.text('Maria Clara Souza'), findsOneWidget);
    expect(find.text('maria@exemplo.com'), findsOneWidget);
  });

  testWidgets('perfil lista anos anteriores com dias lidos', (tester) async {
    telaAlta(tester);
    SharedPreferences.setMockInitialValues({
      'dias_lidos': [...diasDe(2024, 98), ...diasDe(2025, 312), '2026-01-01'],
    });
    await montar(tester, await abrir());

    final de2025 = find.text('2025 · 312 de 365 dias');
    final de2024 = find.text('2024 · 98 de 366 dias');
    expect(find.text('Cronograma'), findsOneWidget);
    expect(de2025, findsOneWidget);
    expect(de2024, findsOneWidget);
    expect(find.textContaining('2026 ·'), findsNothing);
    expect(
      tester.getTopLeft(de2025).dy,
      lessThan(tester.getTopLeft(de2024).dy),
      reason: 'do mais recente ao mais antigo',
    );

    // Sem anos anteriores, a seção some.
    SharedPreferences.setMockInitialValues({
      'dias_lidos': ['2026-01-01'],
    });
    await montar(tester, await abrir());
    expect(find.text('Cronograma'), findsNothing);
  });

  testWidgets('tocar num ano abre o cronograma daquele ano', (tester) async {
    telaAlta(tester);
    SharedPreferences.setMockInitialValues({'dias_lidos': diasDe(2025, 3)});
    await tester.runAsync(() => Conteudo.instancia.plano(bissexto: false));
    final router = await montar(tester, await abrir());

    await tester.tap(find.text('2025 · 3 de 365 dias'));
    await tester.pumpAndSettle();
    await esperarCronograma(tester);

    expect(router.state.uri.path, '/perfil/cronograma/2025');
    expect(find.byType(TelaCronogramaDoAno), findsOneWidget);
    expect(find.text('Cronograma de 2025'), findsOneWidget);
    expect(find.text('3 de 31 dias concluídos em Janeiro'), findsOneWidget);
  });

  testWidgets(
    'perfil lista planos concluídos com a data, do mais recente ao mais antigo',
    (tester) async {
      telaAlta(tester);
      final antes = await abrir();
      final cartas = await antes.criarPlano(
        titulo: 'Cartas de João',
        livros: ['2joao'],
        dias: 1,
      );
      final judas = await antes.criarPlano(
        titulo: 'Carta de Judas',
        livros: ['judas'],
        dias: 1,
      );
      await antes.criarPlano(
        titulo: 'Gênesis aberto',
        livros: ['genesis'],
        dias: 30,
      );
      await antes.alternarLidoNoPlano(cartas.id, 1);
      await antes.alternarLidoNoPlano(judas.id, 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'planos_concluidos',
        json.encode({
          cartas.id: DateTime(2026, 3, 10).millisecondsSinceEpoch,
          judas.id: DateTime(2026, 9, 2).millisecondsSinceEpoch,
        }),
      );
      await montar(tester, await abrir());

      expect(find.text('Planos concluídos'), findsOneWidget);
      expect(find.text('Concluído em 02/09/2026'), findsOneWidget);
      expect(find.text('Concluído em 10/03/2026'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Carta de Judas')).dy,
        lessThan(tester.getTopLeft(find.text('Cartas de João')).dy),
      );
      // Plano não concluído fica em Meus planos, não aqui.
      expect(find.text('Gênesis aberto'), findsNothing);
      expect(find.text('A Vida de Jesus em 30 dias'), findsNothing);
    },
  );

  testWidgets('Fazer de novo no perfil tira o plano dos concluídos', (
    tester,
  ) async {
    telaAlta(tester);
    final estado = await abrir();
    final plano = await estado.criarPlano(
      titulo: 'Cartas de João',
      livros: ['2joao'],
      dias: 1,
    );
    await estado.alternarLidoNoPlano(plano.id, 1);
    await montar(tester, estado);

    await tester.tap(find.text('Fazer de novo'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Fazer de novo'),
      ),
    );
    await tester.pumpAndSettle();

    expect(estado.diasLidosDoPlano(plano.id), 0);
    expect(find.text('Planos concluídos'), findsNothing);
  });

  testWidgets('perfil sem planos concluídos esconde a seção', (tester) async {
    await montar(tester, await abrir());
    expect(find.text('Planos concluídos'), findsNothing);
  });

  testWidgets(
    'perfil soma favoritos e notas das três origens e Ver favoritos e notas abre '
    '/notas?aba=todas',
    (tester) async {
      telaAlta(tester);
      final estado = await abrir();
      await estado.alternarFavorito('joao', 3, 16);
      await estado.leituraDeLivros.alternarDestaque(
        slugDoDevocional('manha'),
        diaDoDevocional(DateTime(2025, 11, 17)),
        paragrafoDoDevocional,
      );
      await estado.leituraDeLivros.definirNota(
        'respigas_entre_os_feixes',
        0,
        0,
        'ilustração boa',
      );
      final router = await montar(tester, estado);

      // Os mesmos números das abas de /notas?aba=todas (notas_todas_test).
      expect(find.text('Favoritos 3 · Notas 1'), findsOneWidget);

      await tester.tap(find.text('Ver favoritos e notas'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/notas?aba=todas');
    },
  );

  testWidgets('perfil sem marcações mostra o estado vazio', (tester) async {
    telaAlta(tester);
    await montar(tester, await abrir());

    expect(find.text('Favoritos e notas'), findsOneWidget);
    expect(find.text('Nenhum favorito nem nota ainda'), findsOneWidget);
    expect(find.text('Ver favoritos e notas'), findsNothing);
  });

  Future<void> tocarEmSair(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ListTile, 'Sair'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sair'),
      ),
    );
  }

  testWidgets('sair pelo perfil volta para a Hoje', (tester) async {
    telaAlta(tester);
    Nuvem.instancia.sairForcado = () async {
      Nuvem.instancia.logadoForcado = false;
    };
    final router = await montar(tester, await abrir());

    await tocarEmSair(tester);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/hoje');
    expect(find.text('Tela da Hoje'), findsOneWidget);
    expect(find.text('Você saiu da conta'), findsOneWidget);
    await esgotarAvisos(tester);
  });

  testWidgets('sair com falha continua no perfil com o erro', (tester) async {
    telaAlta(tester);
    Nuvem.instancia.sairForcado = () async =>
        throw SairDaContaFalhou(StateError('sem rede'));
    final router = await montar(tester, await abrir());

    await tocarEmSair(tester);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/perfil');
    expect(find.byType(TelaPerfil), findsOneWidget);
    expect(
      find.text(
        'Não foi possível guardar tudo na sua conta. Verifique a conexão e '
        'tente de novo',
      ),
      findsOneWidget,
    );
    // O Sair volta a aceitar toque.
    final sair = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Sair'));
    expect(sair.onTap, isNotNull);
    await esgotarAvisos(tester);
  });

  testWidgets('enquanto sai, o Sair espera e não aceita outro toque', (
    tester,
  ) async {
    telaAlta(tester);
    final saida = Completer<void>();
    var chamadas = 0;
    Nuvem.instancia.sairForcado = () {
      chamadas++;
      return saida.future;
    };
    final router = await montar(tester, await abrir());

    await tocarEmSair(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Salvando na conta antes de sair'), findsOneWidget);
    // O toque continua ligado (o foco do teclado não cai) e é ignorado; o
    // leitor de tela ouve o botão como desligado.
    final sair = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Sair'));
    expect(sair.onTap, isNotNull);
    final semantica = tester.ensureSemantics();
    final no = tester.getSemantics(find.widgetWithText(ListTile, 'Sair'));
    expect(no.flagsCollection.isEnabled.name, 'isFalse');
    expect(no.flagsCollection.isButton, isTrue);
    expect(no.label, contains('salvando na conta'));
    semantica.dispose();
    await tester.tap(find.widgetWithText(ListTile, 'Sair'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    // O Apagar também espera: o toque é ignorado enquanto o Sair anda.
    await tester.tap(find.text('Apagar conta e dados'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(chamadas, 1);

    Nuvem.instancia.logadoForcado = false;
    saida.complete();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/hoje');
    await esgotarAvisos(tester);
  });

  testWidgets('perfil tem Apagar conta na seção Conta', (tester) async {
    telaAlta(tester);
    await montar(tester, await abrir());

    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Apagar conta e dados'), findsOneWidget);
    expect(find.text('Apagar conta e dados da nuvem'), findsNothing);
  });

  testWidgets('Apagar conta avisa que a cópia do aparelho também sai', (
    tester,
  ) async {
    telaAlta(tester);
    await montar(tester, await abrir());

    expect(find.textContaining('não é tocado'), findsNothing);
    expect(
      find.text(
        'Apaga sua conta no app e tudo o que ela guarda, na nuvem e '
        'neste aparelho.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Apagar conta e dados'));
    await tester.pumpAndSettle();
    final dialogo = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialogo, matching: find.textContaining('intacto')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: dialogo,
        matching: find.textContaining('na nuvem e neste aparelho'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('sem conta, /perfil pede login', (tester) async {
    Nuvem.instancia.logadoForcado = false;
    await montar(tester, await abrir());

    expect(find.byType(TabernaculoCartaoDeEntrar), findsOneWidget);
    expect(find.text('Entre para ver seu perfil'), findsOneWidget);
    expect(find.text('Sair'), findsNothing);
  });

  group('acessibilidade', () {
    const temas = {'claro': Brightness.light, 'escuro': Brightness.dark};
    final diretrizes = <String, AccessibilityGuideline>{
      'o alvo de toque de 48 dp': androidTapTargetGuideline,
      'o rótulo em todo alvo de toque': labeledTapTargetGuideline,
      'o contraste de texto': textContrastGuideline,
    };

    /// Um pouco de tudo, para todas as seções aparecerem.
    Future<Estado> estadoCheio() async {
      SharedPreferences.setMockInitialValues({'dias_lidos': diasDe(2025, 40)});
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas de João',
        livros: ['2joao'],
        dias: 1,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.alternarFavorito('joao', 3, 16);
      return estado;
    }

    for (final MapEntry(key: nomeDoTema, value: brilho) in temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in diretrizes.entries) {
        testWidgets('perfil no tema $nomeDoTema atende $nomeDaDiretriz', (
          tester,
        ) async {
          final semantica = tester.ensureSemantics();
          telaAlta(tester);
          Nuvem.instancia.nomeForcado = 'Maria Clara Souza';
          Nuvem.instancia.emailForcado = 'maria@exemplo.com';
          await montar(tester, await estadoCheio(), brilho: brilho);
          await expectLater(tester, meetsGuideline(diretriz));
          semantica.dispose();
        });

        testWidgets('cabeçalho da Hoje logado no tema $nomeDoTema atende '
            '$nomeDaDiretriz', (tester) async {
          // A foto virou alvo de toque: abre o perfil.
          final semantica = tester.ensureSemantics();
          Nuvem.instancia.nomeForcado = 'Maria Clara Souza';
          final estado = await abrir();
          await tester.pumpWidget(
            EscopoDoEstado(
              estado: estado,
              child: MaterialApp(
                theme: construirTema(brilho: brilho),
                home: Scaffold(
                  body: TabernaculoCabecalhoDaHoje(
                    data: DateTime(2026, 11, 25, 9),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Abrir perfil'), findsOneWidget);
          await expectLater(tester, meetsGuideline(diretriz));
          semantica.dispose();
        });

        testWidgets(
          'cronograma do ano no tema $nomeDoTema atende $nomeDaDiretriz',
          (tester) async {
            final semantica = tester.ensureSemantics();
            telaAlta(tester);
            await tester.runAsync(
              () => Conteudo.instancia.plano(bissexto: false),
            );
            final router = await montar(
              tester,
              await estadoCheio(),
              brilho: brilho,
            );
            unawaited(router.push('/perfil/cronograma/2025'));
            await tester.pumpAndSettle();
            await esperarCronograma(tester);
            expect(
              find.text('31 de 31 dias concluídos em Janeiro'),
              findsOneWidget,
            );
            expect(find.byType(TelaCronogramaDoAno), findsOneWidget);
            await expectLater(tester, meetsGuideline(diretriz));
            semantica.dispose();
          },
        );
      }
    }
  });
}
