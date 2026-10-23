import 'dart:convert';
import 'dart:io';

import 'package:felipe_ambrozini/dados/biblioteca.dart';
import 'package:felipe_ambrozini/dados/config_admin.dart';
import 'package:felipe_ambrozini/dados/estado.dart';
import 'package:felipe_ambrozini/dados/leitura_de_livros.dart';
import 'package:felipe_ambrozini/dados/modelos.dart';
import 'package:felipe_ambrozini/dados/recursos.dart';
import 'package:felipe_ambrozini/estilo/espacamento.dart';
import 'package:felipe_ambrozini/telas/biblioteca.dart';
import 'package:felipe_ambrozini/telas/leitor_de_livro.dart';
import 'package:felipe_ambrozini/telas/livro.dart';
import 'package:felipe_ambrozini/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    test(
      'capítulos com título e parágrafos, sem travessão nem aspa curva',
      () async {
        const totalDeCapitulos = {
          'somente_pela_graca': 20,
          'alfabeto_de_ouro': 23,
          'o_ganhador_de_almas': 15,
          'ao_redor_do_portao_estreito': 12,
          'conversas_de_joao_lavrador': 25,
          'retratos_de_joao_lavrador': 39,
          'segundo_a_promessa': 20,
          'o_maior_combate_do_mundo': 4,
          'o_evangelho_do_reino': 28,
          'licoes_aos_meus_alunos': 31,
          'a_biblia_e_o_jornal': 44,
          'ate_que_ele_venha': 21,
          'pescadores_de_criancas': 23,
          'o_santo_e_o_seu_salvador': 13,
          'tesouro_de_davi': 149,
        };
        final proibidos = RegExp('[—–‘’“”]');
        for (final obra in obrasDaBiblioteca) {
          final livro = (await Biblioteca.instancia.capitulos(obra.slug))!;
          expect(
            livro,
            hasLength(totalDeCapitulos[obra.slug]),
            reason: obra.slug,
          );
          for (final (indice, capitulo) in livro.indexed) {
            final onde = '${obra.slug}, capítulo $indice';
            expect(capitulo.titulo.trim(), isNotEmpty, reason: onde);
            expect(capitulo.paragrafos, isNotEmpty, reason: onde);
            for (final texto in [capitulo.titulo, ...capitulo.paragrafos]) {
              expect(texto.trim(), isNotEmpty, reason: onde);
              expect(proibidos.hasMatch(texto), isFalse, reason: onde);
              expect(
                texto.contains('[['),
                isFalse,
                reason: '$onde: marcador sobrando',
              );
            }
          }
        }
      },
    );

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

    test(
      'lembra o último livro em que se leu, e nenhum antes de começar',
      () async {
        final estado = await abrirEstado();
        expect(estado.leituraDeLivros.ultimoLivro, isNull);

        await estado.leituraDeLivros.registrarPosicao('alfabeto_de_ouro', 0, 0);
        await estado.leituraDeLivros.registrarPosicao(slug, 2, 0.5);
        expect(estado.leituraDeLivros.ultimoLivro, slug);
        await estado.leituraDeLivros.registrarPosicao('alfabeto_de_ouro', 1, 0);
        expect(estado.leituraDeLivros.ultimoLivro, 'alfabeto_de_ouro');

        expect(estado.leituraDeLivros.livrosEmLeitura, [
          'alfabeto_de_ouro',
          slug,
        ]);

        final reaberto = await abrirEstado();
        expect(reaberto.leituraDeLivros.ultimoLivro, 'alfabeto_de_ouro');
        expect(reaberto.leituraDeLivros.livrosEmLeitura, [
          'alfabeto_de_ouro',
          slug,
        ]);
      },
    );

    test(
      'só avisa os ouvintes quando o capítulo muda ou a rolagem anda um quarto',
      () async {
        final estado = await abrirEstado();
        var avisos = 0;
        estado.addListener(() => avisos++);

        await estado.leituraDeLivros.registrarPosicao(slug, 1, 0);
        expect(avisos, 1);
        await estado.leituraDeLivros.registrarPosicao(slug, 1, 0.1);
        await estado.leituraDeLivros.registrarPosicao(slug, 1, 0.2);
        expect(avisos, 1);
        await estado.leituraDeLivros.registrarPosicao(slug, 1, 0.3);
        expect(avisos, 2);
        await estado.leituraDeLivros.registrarPosicao(slug, 1, 0.4);
        expect(avisos, 2);
        await estado.leituraDeLivros.registrarPosicao(slug, 2, 0);
        expect(avisos, 3);
      },
    );

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

    test(
      'concluir zera a leitura do livro e guarda destaques e notas',
      () async {
        final estado = await abrirEstado();
        final leitura = estado.leituraDeLivros;
        await leitura.registrarPosicao('alfabeto_de_ouro', 0, 0);
        await leitura.registrarPosicao(slug, 19, 0.9);
        await leitura.alternarLido(slug, 19);
        await leitura.definirNota(slug, 19, 0, 'minha nota');

        await leitura.concluir(slug);
        expect(leitura.posicaoDe(slug), isNull);
        expect(leitura.quantosLidos(slug), 0);
        expect(leitura.livrosEmLeitura, ['alfabeto_de_ouro']);
        expect(leitura.destaquesDe(slug, 19)[0]!.nota, 'minha nota');

        final reaberto = await abrirEstado();
        expect(reaberto.leituraDeLivros.posicaoDe(slug), isNull);
        expect(reaberto.leituraDeLivros.quantosLidos(slug), 0);
        expect(reaberto.leituraDeLivros.livrosEmLeitura, ['alfabeto_de_ouro']);
        expect(
          reaberto.leituraDeLivros.destaquesDe(slug, 19)[0]!.nota,
          'minha nota',
        );
      },
    );

    group('sincronia com a conta', () {
      /// Um segundo aparelho: outro armazenamento, vazio.
      Future<Estado> outroAparelho() async {
        SharedPreferences.setMockInitialValues({});
        return abrirEstado();
      }

      test('a cópia fundida em outro aparelho traz a mesma leitura', () async {
        final celular = await abrirEstado();
        final leitura = celular.leituraDeLivros;
        await leitura.registrarPosicao(slug, 4, 0.5);
        await leitura.alternarLido(slug, 3);
        await leitura.definirNota(slug, 3, 1, 'boa');
        final copia = leitura.serializar();

        final web = await outroAparelho();
        await web.leituraDeLivros.fundir(copia);
        expect(web.leituraDeLivros.posicaoDe(slug)!.capitulo, 4);
        expect(web.leituraDeLivros.foiLido(slug, 3), isTrue);
        expect(web.leituraDeLivros.destaquesDe(slug, 3)[1]!.nota, 'boa');
        expect(web.leituraDeLivros.serializar(), copia);
      });

      test(
        'na mesma volta os lidos se somam e vale a posição mais recente',
        () async {
          final celular = await abrirEstado();
          await celular.leituraDeLivros.registrarPosicao(slug, 2, 0);
          await celular.leituraDeLivros.alternarLido(slug, 1);
          final copiaDoCelular = celular.leituraDeLivros.serializar();

          final web = await outroAparelho();
          await web.leituraDeLivros.alternarLido(slug, 2);
          await web.leituraDeLivros.registrarPosicao(slug, 6, 0.2);
          await web.leituraDeLivros.fundir(copiaDoCelular);
          expect(web.leituraDeLivros.posicaoDe(slug)!.capitulo, 6);
          expect(web.leituraDeLivros.quantosLidos(slug), 2);
        },
      );

      test(
        'terminar o livro em outro aparelho zera a leitura antiga daqui',
        () async {
          final web = await abrirEstado();
          await web.leituraDeLivros.registrarPosicao(slug, 5, 0.5);
          await web.leituraDeLivros.alternarLido(slug, 4);

          final celular = await outroAparelho();
          await celular.leituraDeLivros.registrarPosicao(slug, 19, 0);
          await celular.leituraDeLivros.concluir(slug);

          await web.leituraDeLivros.fundir(
            celular.leituraDeLivros.serializar(),
          );
          expect(web.leituraDeLivros.posicaoDe(slug), isNull);
          expect(web.leituraDeLivros.quantosLidos(slug), 0);
          expect(web.leituraDeLivros.vezesConcluido(slug), 1);
        },
      );

      test(
        'uma cópia de uma volta anterior não desfaz o que já foi terminado',
        () async {
          final antigo = await abrirEstado();
          await antigo.leituraDeLivros.registrarPosicao(slug, 3, 0);
          final copiaAntiga = antigo.leituraDeLivros.serializar();

          final atual = await outroAparelho();
          await atual.leituraDeLivros.registrarPosicao(slug, 19, 0);
          await atual.leituraDeLivros.concluir(slug);
          await atual.leituraDeLivros.fundir(copiaAntiga);
          expect(atual.leituraDeLivros.posicaoDe(slug), isNull);
          expect(atual.leituraDeLivros.vezesConcluido(slug), 1);
        },
      );

      test(
        'no mesmo parágrafo vale o destaque mais novo, e os outros se somam',
        () async {
          final celular = await abrirEstado();
          await celular.leituraDeLivros.definirNota(slug, 1, 0, 'primeira');
          final copia = celular.leituraDeLivros.serializar();

          final web = await outroAparelho();
          await web.leituraDeLivros.alternarDestaque(slug, 2, 4);
          await Future<void>.delayed(const Duration(milliseconds: 5));
          await web.leituraDeLivros.definirNota(slug, 1, 0, 'segunda');
          await web.leituraDeLivros.fundir(copia);
          expect(web.leituraDeLivros.destaquesDe(slug, 1)[0]!.nota, 'segunda');
          expect(web.leituraDeLivros.destaquesDe(slug, 2).keys, [4]);
        },
      );

      test(
        'da cópia só entra o que é confiável, e uma entrada torta não impede as outras',
        () async {
          final estado = await abrirEstado();
          final copia = jsonEncode({
            'versao': 1,
            'livros': {
              'livro_que_nao_existe': {
                'concluidas': 1,
                'lidos': [1],
              },
              slug: {'concluidas': 'torta'},
              'alfabeto_de_ouro': {
                'concluidas': 0,
                'posicao': {'capitulo': 3, 'fracao': 0.2, 'em': 5},
                'lidos': [-4, 2, 99999999],
              },
            },
            'destaques': [
              {
                'slug': slug,
                'capitulo': -1,
                'paragrafo': 0,
                'nota': 'x',
                'em': 1,
              },
              {
                'slug': slug,
                'capitulo': 1,
                'paragrafo': 0,
                'nota': 'ok',
                'em': 1,
              },
            ],
          });
          await estado.leituraDeLivros.fundir(copia);
          final leitura = estado.leituraDeLivros;
          expect(leitura.posicaoDe('livro_que_nao_existe'), isNull);
          expect(leitura.posicaoDe('alfabeto_de_ouro')!.capitulo, 3);
          expect(leitura.quantosLidos('alfabeto_de_ouro'), 1);
          expect(leitura.todosOsDestaques.map((d) => d.nota), ['ok']);
        },
      );

      test('um carimbo de tempo no futuro não ganha todas as fusões', () async {
        final estado = await abrirEstado();
        final futuro =
            DateTime.now().millisecondsSinceEpoch + 10 * 24 * 3600 * 1000;
        await estado.leituraDeLivros.fundir(
          jsonEncode({
            'versao': 1,
            'livros': {
              slug: {
                'concluidas': 0,
                'posicao': {'capitulo': 2, 'fracao': 0.5, 'em': futuro},
                'lidos': <int>[],
              },
            },
            'destaques': <Object>[],
          }),
        );
        expect(
          estado.leituraDeLivros.posicaoDe(slug)!.em,
          lessThan(futuro),
          reason: 'o carimbo é limitado a um dia à frente',
        );
      });

      test('a nota é limitada, para não encher o documento da conta', () async {
        final estado = await abrirEstado();
        await estado.leituraDeLivros.definirNota(slug, 0, 0, 'a' * 3000);
        expect(
          estado.leituraDeLivros.destaquesDe(slug, 0)[0]!.nota.length,
          LeituraDeLivros.tamanhoMaximoDaNota,
        );
      });

      test('uma cópia estragada não derruba a leitura daqui', () async {
        final estado = await abrirEstado();
        await estado.leituraDeLivros.registrarPosicao(slug, 1, 0);
        await estado.leituraDeLivros.fundir('isto não é json');
        expect(estado.leituraDeLivros.posicaoDe(slug)!.capitulo, 1);
      });
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
      await tester.scrollUntilVisible(find.text('Somente pela Graça'), 300);
      expect(
        find.descendant(
          of: find.widgetWithText(DevocionalCartaoDaObra, 'Somente pela Graça'),
          matching: find.text('20 capítulos'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Somente pela Graça').last);
      await tester.pumpAndSettle();
      expect(find.text('Começar a ler'), findsOneWidget);
      expect(find.text(capitulos.first.titulo), findsOneWidget);
    });

    testWidgets('os cartões da estante têm espaço entre si', (tester) async {
      await abrir(tester, '/biblioteca');
      final cartoes = find.byType(DevocionalCartaoDaObra);
      expect(cartoes, findsAtLeastNWidgets(2));

      final primeiro = tester.getRect(cartoes.at(0));
      final segundo = tester.getRect(cartoes.at(1));
      expect(
        segundo.top - primeiro.bottom,
        greaterThanOrEqualTo(DevocionalEspacamento.sp12),
      );
    });

    testWidgets('o leitor mostra o capítulo e troca pelas setas do teclado', (
      tester,
    ) async {
      final estado = await abrir(tester, '/biblioteca/$slug/1');
      expect(find.text('Capítulo 1 de 20'), findsOneWidget);
      expect(find.text(capitulos[0].titulo), findsOneWidget);

      // No toque não há barra de setas no rodapé (só na web, se ligada).
      expect(find.byTooltip('Próximo capítulo'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Capítulo 2 de 20'), findsOneWidget);
      expect(find.text(capitulos[1].titulo), findsOneWidget);
      // Abrir o capítulo é o que o "continuar" da estante vai ler.
      expect(estado.leituraDeLivros.posicaoDe(slug)!.capitulo, 1);
    });

    testWidgets('deslizar troca de capítulo e dá para desfazer', (
      tester,
    ) async {
      await abrir(tester, '/biblioteca/$slug/1');

      await tester.timedDrag(
        find.byType(SingleChildScrollView).first,
        const Offset(-400, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Capítulo 2 de 20'), findsOneWidget);
      expect(find.text('Desfazer'), findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(find.text('Capítulo 1 de 20'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('no primeiro capítulo, voltar não faz nada', (tester) async {
      await abrir(tester, '/biblioteca/$slug/1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Capítulo 1 de 20'), findsOneWidget);

      await tester.timedDrag(
        find.byType(SingleChildScrollView).first,
        const Offset(400, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Capítulo 1 de 20'), findsOneWidget);
    });

    testWidgets('do último capítulo, avançar termina a leitura e recomeça', (
      tester,
    ) async {
      final estado = await abrir(tester, '/biblioteca/$slug/20');
      await estado.leituraDeLivros.alternarLido(slug, 19);
      expect(find.text('Terminar a leitura'), findsOneWidget);

      // Cancelar não muda nada.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Terminar a leitura?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Capítulo 20 de 20'), findsOneWidget);
      expect(estado.leituraDeLivros.foiLido(slug, 19), isTrue);

      // Confirmar termina, volta à estante e deixa o livro fora de "em
      // leitura": o capítulo 1 só abre, e grava a posição, quando o usuário
      // abrir o livro de novo.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();
      expect(find.byType(TelaBiblioteca), findsOneWidget);
      expect(find.textContaining('Capítulo 1 de 20'), findsNothing);
      expect(find.textContaining('Você terminou'), findsOneWidget);
      expect(estado.leituraDeLivros.quantosLidos(slug), 0);
      expect(estado.leituraDeLivros.posicaoDe(slug), isNull);
      expect(estado.leituraDeLivros.livrosEmLeitura, isNot(contains(slug)));
      expect(estado.leituraDeLivros.vezesConcluido(slug), 1);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets(
      'terminar o livro rolando o capítulo sobrevive a fechar o app',
      (tester) async {
        final estado = await abrir(tester, '/biblioteca/$slug/20');
        await estado.leituraDeLivros.alternarLido(slug, 18);

        // Lê até o fim: cada pausa da rolagem grava a posição do capítulo.
        await tester.scrollUntilVisible(find.text('Terminar a leitura'), 500);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Terminar a leitura'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Terminar'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 6));

        // "Fechar e abrir o app": lê do disco de novo, sem passar pela memória.
        final reaberta = LeituraDeLivros.ler(
          await SharedPreferences.getInstance(),
          () {},
        );
        expect(reaberta.posicaoDe(slug), isNull);
        expect(reaberta.quantosLidos(slug), 0);
        expect(reaberta.vezesConcluido(slug), 1);
      },
    );

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

      await mostrar(obrasDaBiblioteca.take(2).toList());
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
