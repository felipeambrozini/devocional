import 'dart:io';

import 'package:felipe_ambrozini/dados/biblioteca.dart';
import 'package:felipe_ambrozini/dados/config_admin.dart';
import 'package:felipe_ambrozini/dados/estado.dart';
import 'package:felipe_ambrozini/dados/modelos.dart';
import 'package:felipe_ambrozini/dados/recursos.dart';
import 'package:felipe_ambrozini/telas/biblioteca.dart';
import 'package:felipe_ambrozini/telas/leitor_de_livro.dart';
import 'package:felipe_ambrozini/telas/livro.dart';
import 'package:felipe_ambrozini/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// As mesmas rotas de main.dart, sem o shell de abas: aqui só a biblioteca
/// importa.
GoRouter _router(String inicial) => GoRouter(
  initialLocation: inicial,
  routes: [
    GoRoute(
      path: '/biblioteca',
      builder: (context, state) => const TelaBiblioteca(),
      routes: [
        GoRoute(
          path: ':slug',
          builder: (context, state) =>
              TelaDoLivro(slug: state.pathParameters['slug']!),
          routes: [
            GoRoute(
              path: ':capitulo',
              builder: (context, state) => TelaLeitorDeLivro(
                slug: state.pathParameters['slug']!,
                capitulo: int.tryParse(state.pathParameters['capitulo']!) ?? 0,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  const slug = 'somente_pela_graca';
  late List<CapituloDoLivro> capitulos;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    capitulos = (await Biblioteca.instancia.capitulos(slug))!;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Estado> abrirEstado() async =>
      Estado(await SharedPreferences.getInstance());

  group('assets dos livros', () {
    test('cada livro do catálogo tem asset, e cada asset está no catálogo', () {
      final arquivos = {
        for (final f in Directory('assets/livros').listSync().whereType<File>())
          f.uri.pathSegments.last.replaceAll('.json', ''),
      };
      expect(arquivos, {for (final obra in obrasDaBiblioteca) obra.slug});
    });

    test('capítulos com título e parágrafos, sem travessão nem aspa curva', () async {
      const totalDeCapitulos = {'somente_pela_graca': 20, 'alfabeto_de_ouro': 23};
      final proibidos = RegExp('[—–‘’“”]');
      for (final obra in obrasDaBiblioteca) {
        final livro = (await Biblioteca.instancia.capitulos(obra.slug))!;
        expect(livro, hasLength(totalDeCapitulos[obra.slug]), reason: obra.slug);
        for (final (indice, capitulo) in livro.indexed) {
          final onde = '${obra.slug}, capítulo $indice';
          expect(capitulo.titulo.trim(), isNotEmpty, reason: onde);
          expect(capitulo.paragrafos, isNotEmpty, reason: onde);
          for (final texto in [capitulo.titulo, ...capitulo.paragrafos]) {
            expect(texto.trim(), isNotEmpty, reason: onde);
            expect(proibidos.hasMatch(texto), isFalse, reason: onde);
            expect(texto.contains('[['), isFalse, reason: '$onde: marcador sobrando');
          }
        }
      }
    });

    test('livro que não existe devolve nulo, sem lançar', () async {
      expect(await Biblioteca.instancia.capitulos('nao_existe'), isNull);
    });
  });

  group('LeituraDeLivros', () {
    test('guarda a posição e sobrevive a reabrir o estado', () async {
      final estado = await abrirEstado();
      await estado.leituraDeLivros.registrarPosicao(slug, 3, 0.4);

      final reaberto = await abrirEstado();
      final posicao = reaberto.leituraDeLivros.posicaoDe(slug)!;
      expect(posicao.capitulo, 3);
      expect(posicao.fracao, 0.4);
      expect(reaberto.leituraDeLivros.posicaoDe('outro'), isNull);
    });

    test('lembra o último livro em que se leu, e nenhum antes de começar', () async {
      final estado = await abrirEstado();
      expect(estado.leituraDeLivros.ultimoLivro, isNull);

      await estado.leituraDeLivros.registrarPosicao('alfabeto_de_ouro', 0, 0);
      await estado.leituraDeLivros.registrarPosicao(slug, 2, 0.5);
      expect(estado.leituraDeLivros.ultimoLivro, slug);
      await estado.leituraDeLivros.registrarPosicao('alfabeto_de_ouro', 1, 0);
      expect(estado.leituraDeLivros.ultimoLivro, 'alfabeto_de_ouro');

      expect(estado.leituraDeLivros.livrosEmLeitura, ['alfabeto_de_ouro', slug]);

      final reaberto = await abrirEstado();
      expect(reaberto.leituraDeLivros.ultimoLivro, 'alfabeto_de_ouro');
      expect(reaberto.leituraDeLivros.livrosEmLeitura, ['alfabeto_de_ouro', slug]);
    });

    test('só a troca de capítulo avisa os ouvintes, não a rolagem', () async {
      final estado = await abrirEstado();
      var avisos = 0;
      estado.addListener(() => avisos++);

      await estado.leituraDeLivros.registrarPosicao(slug, 1, 0);
      expect(avisos, 1);
      await estado.leituraDeLivros.registrarPosicao(slug, 1, 0.3);
      await estado.leituraDeLivros.registrarPosicao(slug, 1, 0.6);
      expect(avisos, 1);
      await estado.leituraDeLivros.registrarPosicao(slug, 2, 0);
      expect(avisos, 2);
    });

    test('a fração fica entre 0 e 1', () async {
      final estado = await abrirEstado();
      await estado.leituraDeLivros.registrarPosicao(slug, 0, 7);
      expect(estado.leituraDeLivros.posicaoDe(slug)!.fracao, 1);
    });

    test('marca e desmarca capítulos lidos, e conta', () async {
      final estado = await abrirEstado();
      final leitura = estado.leituraDeLivros;
      await leitura.alternarLido(slug, 0);
      await leitura.alternarLido(slug, 4);
      expect(leitura.quantosLidos(slug), 2);
      expect(leitura.foiLido(slug, 4), isTrue);

      await leitura.alternarLido(slug, 4);
      expect(leitura.foiLido(slug, 4), isFalse);

      final reaberto = await abrirEstado();
      expect(reaberto.leituraDeLivros.quantosLidos(slug), 1);
    });

    test('destaque liga e desliga, e uma nota segura o destaque', () async {
      final estado = await abrirEstado();
      final leitura = estado.leituraDeLivros;

      await leitura.alternarDestaque(slug, 2, 5);
      expect(leitura.destaquesDe(slug, 2).keys, [5]);
      await leitura.alternarDestaque(slug, 2, 5);
      expect(leitura.destaquesDe(slug, 2), isEmpty);

      await leitura.definirNota(slug, 2, 5, '  Lembrar disto  ');
      expect(leitura.destaquesDe(slug, 2)[5]!.nota, 'Lembrar disto');

      // Com nota, tirar o destaque não apaga o trabalho do usuário.
      await leitura.alternarDestaque(slug, 2, 5);
      expect(leitura.destaquesDe(slug, 2)[5]!.nota, 'Lembrar disto');

      // Nota vazia limpa a nota e mantém o grifo.
      await leitura.definirNota(slug, 2, 5, '');
      expect(leitura.destaquesDe(slug, 2)[5]!.nota, isEmpty);
    });

    test('destaques e notas sobrevivem a reabrir o estado', () async {
      final estado = await abrirEstado();
      await estado.leituraDeLivros.definirNota(slug, 1, 0, 'minha nota');

      final reaberto = await abrirEstado();
      expect(
        reaberto.leituraDeLivros.todosOsDestaques.single.nota,
        'minha nota',
      );
    });

    test('dado corrompido no disco não impede o estado de abrir', () async {
      SharedPreferences.setMockInitialValues({
        'livros_posicoes': 'isto nao e json',
        'livros_lidos': '[1, 2',
        'livros_destaques': '{}',
      });
      final estado = await abrirEstado();
      expect(estado.leituraDeLivros.posicaoDe(slug), isNull);
      expect(estado.leituraDeLivros.quantosLidos(slug), 0);
      expect(estado.leituraDeLivros.todosOsDestaques, isEmpty);
    });
  });

  group('Recursos.biblioteca', () {
    tearDown(() {
      ConfigAdmin.instancia.redefinirParaTeste();
      Recursos.bibliotecaForcado = null;
    });

    test('padrão é ligada', () => expect(Recursos.biblioteca, isTrue));

    test('o painel desliga, e o forçado de teste manda', () {
      ConfigAdmin.instancia.definirParaTeste(bibliotecaAtiva: false);
      expect(Recursos.biblioteca, isFalse);
      Recursos.bibliotecaForcado = true;
      expect(Recursos.biblioteca, isTrue);
    });

    test('documento do admin sem o campo mantém ligada', () {
      ConfigAdmin.instancia.aplicarMapa({'manhaAtivo': true});
      expect(Recursos.biblioteca, isTrue);
      ConfigAdmin.instancia.aplicarMapa({'bibliotecaAtiva': false});
      expect(Recursos.biblioteca, isFalse);
    });
  });

  group('telas', () {
    Future<Estado> abrir(WidgetTester tester, String inicial) async {
      final estado = await abrirEstado();
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(routerConfig: _router(inicial)),
        ),
      );
      await tester.pumpAndSettle();
      return estado;
    }

    testWidgets('a estante mostra o livro e abre o sumário', (tester) async {
      await abrir(tester, '/biblioteca');
      expect(find.text('Somente pela Graça'), findsWidgets);
      expect(find.text('20 capítulos'), findsOneWidget);

      await tester.tap(find.text('Somente pela Graça').last);
      await tester.pumpAndSettle();
      expect(find.text('Começar a ler'), findsOneWidget);
      expect(find.text(capitulos.first.titulo), findsOneWidget);
    });

    testWidgets('o leitor mostra o capítulo e troca pelo rodapé', (
      tester,
    ) async {
      final estado = await abrir(tester, '/biblioteca/$slug/1');
      expect(find.text('Capítulo 1 de 20'), findsOneWidget);
      expect(find.text(capitulos[0].titulo), findsOneWidget);

      await tester.tap(find.byTooltip('Próximo capítulo'));
      await tester.pumpAndSettle();
      expect(find.text('Capítulo 2 de 20'), findsOneWidget);
      expect(find.text(capitulos[1].titulo), findsOneWidget);
      // Abrir o capítulo é o que o "continuar" da estante vai ler.
      expect(estado.leituraDeLivros.posicaoDe(slug)!.capitulo, 1);
    });

    testWidgets('capítulo fora da faixa avisa em vez de quebrar', (
      tester,
    ) async {
      await abrir(tester, '/biblioteca/$slug/99');
      expect(find.text('Capítulo não encontrado'), findsOneWidget);
    });

    testWidgets('tocar no parágrafo destaca, anota e marca como lido', (
      tester,
    ) async {
      final estado = await abrir(tester, '/biblioteca/$slug/2');
      final inicio = capitulos[1].paragrafos.first.substring(0, 25);

      await tester.tap(find.textContaining(inicio));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Destacar'));
      await tester.pumpAndSettle();
      expect(estado.leituraDeLivros.destaquesDe(slug, 1).keys, [0]);

      await tester.tap(find.textContaining(inicio));
      await tester.pumpAndSettle();
      expect(find.text('Tirar destaque'), findsOneWidget);
      await tester.tap(find.text('Anotar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Boa ilustração');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(
        estado.leituraDeLivros.destaquesDe(slug, 1)[0]!.nota,
        'Boa ilustração',
      );
      expect(find.text('Boa ilustração'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Marcar como lido'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Marcar como lido'));
      await tester.pumpAndSettle();
      expect(estado.leituraDeLivros.foiLido(slug, 1), isTrue);
      expect(find.text('Capítulo lido'), findsOneWidget);
    });

    testWidgets('a Hoje mostra nada, um cartão ou uma lista horizontal', (
      tester,
    ) async {
      final estado = await abrirEstado();
      Future<void> mostrar(List<ObraDaBiblioteca> obras) async {
        await tester.pumpWidget(
          EscopoDoEstado(
            estado: estado,
            child: MaterialApp(
              home: Scaffold(
                body: DevocionalLivrosEmLeitura(obras: obras, aoAbrir: (_) {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mostrar([]);
      expect(find.byType(DevocionalCartaoDaObra), findsNothing);

      await mostrar([obrasDaBiblioteca.first]);
      expect(find.byType(DevocionalCartaoDaObra), findsOneWidget);
      expect(find.text('Seus livros'), findsNothing);

      await mostrar(obrasDaBiblioteca);
      expect(find.text('Seus livros'), findsOneWidget);
      expect(find.byType(DevocionalCartaoDaObra), findsNWidgets(2));
    });

    testWidgets('com a leitura começada o sumário oferece continuar', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final estado = await abrirEstado();
      await estado.leituraDeLivros.registrarPosicao(slug, 4, 0);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(routerConfig: _router('/biblioteca/$slug')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continuar de onde parei'), findsOneWidget);
      expect(find.text('Parei aqui'), findsOneWidget);
    });
  });
}
