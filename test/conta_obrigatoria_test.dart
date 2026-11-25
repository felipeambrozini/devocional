import 'package:devocional/controladores/leitor_de_livro_controlador.dart';
import 'package:devocional/dados/biblioteca.dart';
import 'package:devocional/dados/dia_da_leitura.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/funcoes/marcar_dia_da_leitura.dart';
import 'package:devocional/telas/hoje.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
