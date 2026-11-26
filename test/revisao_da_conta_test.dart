import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/telas/notas.dart';
import 'package:devocional/telas/perfil.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Correções da revisão de acessibilidade da conta obrigatória: foto do
/// cabeçalho, dica dos parágrafos, espera da conta, cartão de entrar da Hoje,
/// cartão de dia só leitura e a contagem de favoritos e notas do perfil.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    Nuvem.instancia.logadoForcado = null;
    Nuvem.instancia.carregandoContaForcado = null;
    Nuvem.instancia.nomeForcado = null;
  });

  const temas = {'claro': Brightness.light, 'escuro': Brightness.dark};
  final diretrizes = <String, AccessibilityGuideline>{
    'o alvo de toque': androidTapTargetGuideline,
    'o rótulo do alvo': labeledTapTargetGuideline,
    'o contraste': textContrastGuideline,
  };

  Future<Estado> abrir() async => Estado(await SharedPreferences.getInstance());

  Future<void> montar(
    WidgetTester tester,
    Widget filho, {
    Brightness brilho = Brightness.light,
  }) async {
    final estado = await abrir();
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: MaterialApp(
          theme: construirTema(brilho: brilho),
          home: Scaffold(body: filho),
        ),
      ),
    );
    await tester.pump();
  }

  group('foto do cabeçalho', () {
    testWidgets('o toque pinta por cima do avatar, não por baixo', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = true;
      Nuvem.instancia.nomeForcado = 'Maria';
      await montar(
        tester,
        TabernaculoCabecalhoDaHoje(data: DateTime(2026, 11, 25, 9)),
      );

      final stack = tester.widget<Stack>(
        find.ancestor(
          of: find.byType(CircleAvatar),
          matching: find.byType(Stack),
        ),
      );
      final avatar = stack.children.indexWhere(
        (w) => w is ExcludeSemantics && w.child is CircleAvatar,
      );
      final toque = stack.children.indexWhere((w) => w is Positioned);
      expect(avatar, isNonNegative);
      expect(toque, greaterThan(avatar));
    });
  });

  group('dica do parágrafo', () {
    String? dica(WidgetTester tester) =>
        tester.getSemantics(find.text('Texto')).hint;

    testWidgets('sem conta o livro só promete copiar', (tester) async {
      final semantica = tester.ensureSemantics();
      Nuvem.instancia.logadoForcado = false;
      await montar(
        tester,
        TabernaculoParagrafoDeLivro(
          texto: 'Texto',
          destaque: null,
          aoTocar: () {},
        ),
      );
      expect(dica(tester), 'Toque para copiar');
      semantica.dispose();
    });

    testWidgets('sem conta o devocional promete copiar ou compartilhar', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      Nuvem.instancia.logadoForcado = false;
      await montar(
        tester,
        TabernaculoParagrafoDeLivro(
          texto: 'Texto',
          destaque: null,
          aoTocar: () {},
          outrasAcoes: 'anotar, copiar ou compartilhar',
          outrasAcoesSemConta: 'copiar ou compartilhar',
        ),
      );
      expect(dica(tester), 'Toque para copiar ou compartilhar');
      semantica.dispose();
    });

    testWidgets('com conta a dica continua falando de favoritar', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      Nuvem.instancia.logadoForcado = true;
      await montar(
        tester,
        TabernaculoParagrafoDeLivro(
          texto: 'Texto',
          destaque: null,
          aoTocar: () {},
        ),
      );
      expect(dica(tester), 'Toque para favoritar, anotar ou copiar');
      semantica.dispose();
    });
  });

  group('espera da conta', () {
    setUp(() {
      Nuvem.instancia.logadoForcado = false;
      Nuvem.instancia.carregandoContaForcado = true;
    });

    testWidgets('o perfil avisa que está verificando', (tester) async {
      await montar(tester, const TelaPerfil());
      expect(find.text('Verificando sua conta'), findsOneWidget);
      expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
    });

    testWidgets('as notas avisam que estão verificando', (tester) async {
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: await abrir(),
          child: const MaterialApp(home: TelaNotas()),
        ),
      );
      await tester.pump();
      expect(find.text('Verificando sua conta'), findsOneWidget);
      expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
    });

    testWidgets('o cronograma avisa que está verificando', (tester) async {
      await montar(
        tester,
        TabernaculoAbaDoCronograma(hoje: DateTime(2026, 3, 1)),
      );
      expect(find.text('Verificando sua conta'), findsOneWidget);
      expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
    });

    testWidgets('o aviso é região viva e legível', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const TabernaculoVerificandoConta());
      final no = tester.getSemantics(find.text('Verificando sua conta'));
      expect(no.flagsCollection.isLiveRegion, isTrue);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  });

  group('cartão de entrar embutido', () {
    Widget hoje() =>
        ListView(children: [const TabernaculoCartaoDeEntrar(embutido: true)]);

    testWidgets('embutido não cria rolagem nem margem de página inteira', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      await montar(tester, hoje());

      final cartao = tester.widget<TabernaculoCartaoDeEntrar>(
        find.byType(TabernaculoCartaoDeEntrar),
      );
      expect(cartao.embutido, isTrue);
      expect(find.byType(Scrollable), findsOneWidget);
    });

    for (final MapEntry(key: nome, value: brilho) in temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in diretrizes.entries) {
        testWidgets('embutido no tema $nome atende $nomeDaDiretriz', (
          tester,
        ) async {
          final semantica = tester.ensureSemantics();
          Nuvem.instancia.logadoForcado = false;
          await montar(tester, hoje(), brilho: brilho);
          await expectLater(tester, meetsGuideline(diretriz));
          semantica.dispose();
        });
      }
    }
  });

  group('cartão de dia só leitura', () {
    Widget cartao({required bool lido}) => TabernaculoCartaoDeDia(
      numero: 5,
      rotulo: 'Gênesis 13 a 15',
      itens: const <ItemDoDia>[],
      lido: lido,
      aoAlternar: () {},
      somenteLeitura: true,
    );

    testWidgets('lido ou não, o cartão tem a mesma altura', (tester) async {
      await montar(tester, cartao(lido: true));
      final lido = tester.getSize(find.byType(TabernaculoCartaoDeDia)).height;
      await montar(tester, cartao(lido: false));
      final naoLido = tester
          .getSize(find.byType(TabernaculoCartaoDeDia))
          .height;
      expect(naoLido, lido);
    });

    testWidgets('o leitor de tela ouve o dia num nó só', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, cartao(lido: true));
      expect(
        find.bySemanticsLabel('Dia 5, Gênesis 13 a 15, lido'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Gênesis 13 a 15'), findsNothing);
      await montar(tester, cartao(lido: false));
      expect(
        find.bySemanticsLabel('Dia 5, Gênesis 13 a 15, não lido'),
        findsOneWidget,
      );
      semantica.dispose();
    });

    for (final MapEntry(key: nome, value: brilho) in temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in diretrizes.entries) {
        for (final lido in [false, true]) {
          testWidgets('no tema $nome, ${lido ? 'lido' : 'não lido'}, atende '
              '$nomeDaDiretriz', (tester) async {
            final semantica = tester.ensureSemantics();
            await montar(tester, cartao(lido: lido), brilho: brilho);
            await expectLater(tester, meetsGuideline(diretriz));
            semantica.dispose();
          });
        }
      }
    }
  });

  group('contagem do perfil', () {
    Future<void> perfil(WidgetTester tester, Estado estado) async {
      Nuvem.instancia.logadoForcado = true;
      tester.view.physicalSize = const Size(500, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      TelaPerfil(hoje: DateTime(2026, 11, 25)),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no singular, um favorito e nenhuma nota', (tester) async {
      final semantica = tester.ensureSemantics();
      final estado = await abrir();
      await estado.alternarFavorito('joao', 3, 16);
      await perfil(tester, estado);
      expect(find.text('Favoritos 1 · Notas 0'), findsOneWidget);
      expect(find.bySemanticsLabel('1 favorito, 0 notas'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('no plural, favoritos e notas', (tester) async {
      final semantica = tester.ensureSemantics();
      final estado = await abrir();
      await estado.alternarFavorito('joao', 3, 16);
      await estado.alternarFavorito('joao', 3, 17);
      await estado.definirNota('joao', 3, 16, 'a');
      await estado.definirNota('joao', 3, 17, 'b');
      await perfil(tester, estado);
      expect(find.bySemanticsLabel('2 favoritos, 2 notas'), findsOneWidget);
      semantica.dispose();
    });
  });
}
