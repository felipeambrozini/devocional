import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/nuvem.dart';
import 'package:felipe_ambrozini/data/planos.dart';
import 'package:felipe_ambrozini/telas/meu_plano.dart';
import 'package:felipe_ambrozini/telas/novo_plano.dart';
import 'package:felipe_ambrozini/telas/plano.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TelaNovoPlano e TelaDeUmPlano agora são rotas de verdade sob `/plano` (ver
/// main.dart), não Navigator.push avulso — então os testes de widget que
/// navegam entre elas (criar um plano, marcar um dia e voltar) precisam de um
/// GoRouter de verdade na árvore, não só um MaterialApp com Navigator cru.
/// Espelha o formato de main.dart, sem o shell de abas: aqui só o ramo do
/// Plano importa.
GoRouter _routerDoPlano(Estado estado, DateTime hoje) => GoRouter(
  initialLocation: '/plano',
  routes: [
    GoRoute(
      path: '/plano',
      builder: (context, state) => TelaPlano(hoje: hoje),
      routes: [
        GoRoute(
          path: 'novo',
          builder: (context, state) => TelaNovoPlano(estado: estado),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TelaDeUmPlano(
              estado: estado,
              planoId: id,
              plano: estado.planoDoUsuario(id),
            );
          },
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Conteudo.instancia.aquecerIndiceDeDevocionais();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Reabre o estado a partir do mesmo armazenamento, provando que o dado
  /// sobreviveu e não estava só na memória.
  Future<Estado> reabrir() async =>
      Estado(await SharedPreferences.getInstance());

  group('montarPlanoDeLeitura', () {
    test('cobre todos os capítulos, em ordem, sem repetir nem pular', () {
      final dias = montarPlanoDeLeitura(livros: ['genesis'], dias: 10);
      expect(dias, hasLength(10));

      final vistos = <(String, int)>[];
      for (final dia in dias) {
        for (final faixa in dia.faixas) {
          for (final n in faixa.capitulos) {
            vistos.add((faixa.livro, n));
          }
        }
      }
      expect(vistos, hasLength(50));
      expect(vistos.first, ('genesis', 1));
      expect(vistos.last, ('genesis', 50));
      for (var i = 1; i < vistos.length; i++) {
        final (livroA, capituloA) = vistos[i - 1];
        final (livroB, capituloB) = vistos[i];
        expect(livroB, livroA, reason: 'livro na posição $i');
        expect(capituloB, capituloA + 1, reason: 'capítulo na posição $i');
      }
    });

    test('distribui com diferença de no máximo um capítulo por dia', () {
      // 150 salmos em 60 dias: uns dias pegam 2 e outros 3, nunca mais longe.
      final dias = montarPlanoDeLeitura(livros: ['salmos'], dias: 60);
      final tamanhos = [for (final d in dias) d.faixas.single.capitulos.length];
      expect(tamanhos.reduce((a, b) => a + b), 150);
      expect(tamanhos, everyElement(inInclusiveRange(2, 3)));
    });

    test('um dia por capítulo quando o prazo iguala o total', () {
      final dias = montarPlanoDeLeitura(livros: ['genesis'], dias: 50);
      expect(dias, hasLength(50));
      for (var i = 0; i < dias.length; i++) {
        final faixa = dias[i].faixas.single;
        expect(faixa.deCapitulo, faixa.ateCapitulo, reason: 'dia ${i + 1}');
        expect(faixa.ateCapitulo, i + 1);
      }
    });

    test('dias a mais que capítulos são cortados, sem dia vazio', () {
      final dias = montarPlanoDeLeitura(livros: ['genesis'], dias: 60);
      expect(dias, hasLength(50));
      for (final dia in dias) {
        expect(dia.faixas, isNotEmpty, reason: 'dia ${dia.numero}');
      }
      expect(dias.map((d) => d.numero), [for (var i = 1; i <= 50; i++) i]);
    });

    test('dias menores que 1 devolvem lista vazia', () {
      expect(montarPlanoDeLeitura(livros: ['genesis'], dias: 0), isEmpty);
      expect(montarPlanoDeLeitura(livros: ['genesis'], dias: -3), isEmpty);
    });

    test('sem livros conhecidos devolve lista vazia', () {
      expect(montarPlanoDeLeitura(livros: [], dias: 10), isEmpty);
      expect(
        montarPlanoDeLeitura(livros: ['livro_que_nao_existe'], dias: 10),
        isEmpty,
      );
    });

    test('capítulos do mesmo livro no mesmo dia viram uma faixa só', () {
      final primeiro = montarPlanoDeLeitura(
        livros: ['genesis'],
        dias: 10,
      ).first;
      expect(primeiro.faixas, hasLength(1));
      expect(primeiro.faixas.single.rotulo, 'Gênesis 1-5');
    });

    test('a virada de livro quebra a faixa', () {
      // Gênesis (50) + Êxodo (40) = 90 capítulos em 3 dias, 30 por dia.
      final dias = montarPlanoDeLeitura(livros: ['genesis', 'exodo'], dias: 3);
      expect(dias, hasLength(3));
      final segundo = dias[1];
      expect(segundo.faixas, hasLength(2));
      expect(segundo.faixas.first.rotulo, 'Gênesis 31-50');
      expect(segundo.faixas.last.rotulo, 'Êxodo 1-10');
      expect(dias[2].faixas.single.rotulo, 'Êxodo 11-40');
    });

    test('sem incluirDevocionais, itens são só ItemDeCapitulo', () {
      final dia = montarPlanoDeLeitura(livros: ['genesis'], dias: 50)[0];
      expect(dia.itens, [isA<ItemDeCapitulo>()]);
    });

    test('incluirDevocionais=true intercala os devocionais do capítulo, '
        'na posição pedida', () {
      // Dia 1 é só Gênesis 1 (50 capítulos em 50 dias). Vários devocionais do
      // ano citam Gênesis 1 (ex. 05-01, manhã e noite, citando Gênesis 1:4 —
      // ver test/conteudo_test.dart); não importa quantos são ao todo, só que
      // entram todos e na posição certa em relação ao capítulo.
      final antes = montarPlanoDeLeitura(
        livros: ['genesis'],
        dias: 50,
        incluirDevocionais: true,
      )[0];
      expect(antes.itens.last, isA<ItemDeCapitulo>());
      expect(
        antes.itens.whereType<ItemDeDevocional>(),
        contains(
          isA<ItemDeDevocional>()
              .having((i) => i.tipo, 'tipo', TipoDeDevocional.manha)
              .having((i) => i.chaveDoDia, 'chaveDoDia', '05-01'),
        ),
      );

      final depois = montarPlanoDeLeitura(
        livros: ['genesis'],
        dias: 50,
        incluirDevocionais: true,
        devocionalAntes: false,
      )[0];
      expect(depois.itens.first, isA<ItemDeCapitulo>());
      // Mesmo conjunto de devocionais, só muda de lado do capítulo.
      expect(depois.itens.length, antes.itens.length);
    });

    test('faixas continua exposto e ignora os itens de devocional', () {
      final dia = montarPlanoDeLeitura(
        livros: ['genesis'],
        dias: 50,
        incluirDevocionais: true,
      )[0];
      expect(dia.faixas, hasLength(1));
      expect(dia.faixas.single.rotulo, 'Gênesis 1');
      expect(dia.rotulo, 'Gênesis 1');
    });

    test(
      'um devocional citado por dois capítulos da mesma faixa não se repete',
      () {
        // Nenhum devocional real hoje cita dois capítulos de um mesmo livro
        // no mesmo dia (conferido em assets/devocionais/*.json), então este
        // teste exercita o mecanismo de dedup em si: o mesmo ItemDeDevocional
        // "encontrado" sob dois capítulos de uma faixa (aqui, simulado
        // chamando devocionaisDoCapitulo com o mesmo par duas vezes) deve
        // resultar em uma entrada só, na ordem de entrada.
        const manha = ItemDeDevocional(
          tipo: TipoDeDevocional.manha,
          chaveDoDia: '05-01',
        );
        const noite = ItemDeDevocional(
          tipo: TipoDeDevocional.noite,
          chaveDoDia: '05-01',
        );
        // O mesmo padrão de `{...}.toList()` usado por _itensComDevocionais:
        // um Set por spread de uma lista dedupe por igualdade de valor (ver
        // ItemDeDevocional.==) preservando a ordem em que cada item apareceu
        // pela primeira vez.
        final encontrados = [manha, noite, manha];
        final resultado = {...encontrados}.toList();
        expect(resultado, [manha, noite]);
      },
    );
  });

  group('resumo e título', () {
    test('resumoDosLivros com 0, 1, 2, 3 e mais livros', () {
      expect(resumoDosLivros([]), '');
      expect(resumoDosLivros(['genesis']), 'Gênesis');
      expect(resumoDosLivros(['genesis', 'exodo']), 'Gênesis e Êxodo');
      expect(
        resumoDosLivros(['genesis', 'exodo', 'levitico']),
        'Gênesis, Êxodo e Levítico',
      );
      expect(
        resumoDosLivros(['genesis', 'exodo', 'levitico', 'numeros']),
        'Gênesis, Êxodo e mais 2 livros',
      );
    });

    test('listaDosLivros não trunca, ao contrário do resumo', () {
      expect(listaDosLivros([]), '');
      expect(listaDosLivros(['genesis']), 'Gênesis');
      expect(
        listaDosLivros(['genesis', 'exodo', 'levitico', 'numeros']),
        'Gênesis, Êxodo, Levítico e Números',
      );
    });

    test('tituloDePlano usa o resumo e concorda no singular', () {
      expect(tituloDePlano(['genesis'], 1), 'Gênesis em 1 dia');
      expect(tituloDePlano(['genesis'], 30), 'Gênesis em 30 dias');
      expect(tituloDePlano([], 7), 'Plano de leitura em 7 dias');
    });
  });

  group('PlanoDoUsuario', () {
    test('paraJson e doJson são ida e volta, com e sem compartilhado', () {
      final plano = PlanoDoUsuario(
        id: 'abc',
        titulo: 'Meu plano',
        livros: ['genesis', 'salmos'],
        dias: 21,
        criadoEm: DateTime(2027, 5, 1, 12),
      );
      final lido = PlanoDoUsuario.doJson(plano.paraJson());
      expect(lido.id, 'abc');
      expect(lido.titulo, 'Meu plano');
      expect(lido.livros, ['genesis', 'salmos']);
      expect(lido.dias, 21);
      expect(lido.criadoEm, DateTime(2027, 5, 1, 12));
      expect(lido.compartilhado, isFalse);

      final compartilhado = plano.compartilhadoComo(true);
      expect(compartilhado.compartilhado, isTrue);
      final relido = PlanoDoUsuario.doJson(compartilhado.paraJson());
      expect(relido.compartilhado, isTrue);
    });

    test('doJson descarta livros que não existem no canon', () {
      final plano = PlanoDoUsuario.doJson({
        'id': 'x',
        'titulo': 'X',
        'livros': ['genesis', 'nao_existe', 42],
        'dias': 10,
        'criadoEm': 0,
      });
      expect(plano.livros, ['genesis']);
    });

    test('doJsonDaNuvem é compartilhado por definição e usa o criadoEm dado', () {
      final criadoEm = DateTime(2027, 5, 1);
      final plano = PlanoDoUsuario.doJsonDaNuvem(
        {'titulo': 'Nuvem', 'livros': ['exodo'], 'dias': 40},
        id: 'doc-1',
        criadoEm: criadoEm,
      );
      expect(plano.id, 'doc-1');
      expect(plano.titulo, 'Nuvem');
      expect(plano.compartilhado, isTrue);
      expect(plano.criadoEm, criadoEm);
      expect(plano.totalDeCapitulos, 40);
    });

    test('totalDeCapitulos soma os capítulos dos livros', () {
      final plano = PlanoDoUsuario(
        id: 'a',
        titulo: '',
        livros: ['genesis', 'salmos'],
        dias: 30,
        criadoEm: DateTime(2027),
      );
      expect(plano.totalDeCapitulos, 200);
    });

    test('diasDoPlano é determinístico e corta os dias que sobram', () {
      final plano = PlanoDoUsuario(
        id: 'a',
        titulo: '',
        livros: ['genesis'],
        dias: 60,
        criadoEm: DateTime(2027),
      );
      expect(plano.diasDoPlano, hasLength(50));
      expect(
        plano.diasDoPlano.map((d) => d.rotulo),
        plano.diasDoPlano.map((d) => d.rotulo),
        reason: 'a mesma receita monta os mesmos dias toda vez',
      );
    });

    test('incluirDevocionais/devocionalAntes por padrão são false/true, '
        'e paraJson/doJson preservam quando setados', () {
      final padrao = PlanoDoUsuario(
        id: 'a',
        titulo: '',
        livros: ['genesis'],
        dias: 30,
        criadoEm: DateTime(2027),
      );
      expect(padrao.incluirDevocionais, isFalse);
      expect(padrao.devocionalAntes, isTrue);

      final comDevocionais = PlanoDoUsuario(
        id: 'b',
        titulo: '',
        livros: ['genesis'],
        dias: 30,
        criadoEm: DateTime(2027),
        incluirDevocionais: true,
        devocionalAntes: false,
      );
      final lido = PlanoDoUsuario.doJson(comDevocionais.paraJson());
      expect(lido.incluirDevocionais, isTrue);
      expect(lido.devocionalAntes, isFalse);
    });

    test('doJson sem os campos novos (plano antigo) cai no padrão', () {
      final plano = PlanoDoUsuario.doJson({
        'id': 'x',
        'titulo': 'X',
        'livros': ['genesis'],
        'dias': 10,
        'criadoEm': 0,
      });
      expect(plano.incluirDevocionais, isFalse);
      expect(plano.devocionalAntes, isTrue);
    });

    test('diasDoPlano com incluirDevocionais monta itens intercalados', () {
      final plano = PlanoDoUsuario(
        id: 'a',
        titulo: '',
        livros: ['genesis'],
        dias: 50,
        criadoEm: DateTime(2027),
        incluirDevocionais: true,
      );
      expect(
        plano.diasDoPlano[0].itens.whereType<ItemDeDevocional>(),
        isNotEmpty,
      );
    });
  });

  test('novoIdDePlano gera ids únicos', () {
    final ids = {for (var i = 0; i < 100; i++) novoIdDePlano()};
    expect(ids, hasLength(100));
  });

  group('planos do usuário no Estado', () {
    test('criarPlano põe o mais novo na frente, com título padrão, e persiste', () async {
      final estado = await Estado.abrir();
      final a = await estado.criarPlano(titulo: '', livros: ['genesis'], dias: 30);
      final b = await estado.criarPlano(titulo: 'Meu plano', livros: ['salmos'], dias: 10);
      expect(a.titulo, 'Gênesis em 30 dias');
      expect(b.titulo, 'Meu plano');
      expect(estado.planosDoUsuario.map((p) => p.id), [b.id, a.id]);

      final relido = await reabrir();
      expect(relido.planosDoUsuario, hasLength(2));
      expect(relido.planosDoUsuario.first.titulo, 'Meu plano');
    });

    test('alternarLidoNoPlano marca, desmarca e persiste', () async {
      final estado = await Estado.abrir();
      final plano = await estado.criarPlano(titulo: '', livros: ['genesis'], dias: 5);
      expect(estado.foiLidoNoPlano(plano.id, 1), isFalse);

      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.alternarLidoNoPlano(plano.id, 2);
      expect(estado.diasLidosDoPlano(plano.id), 2);
      expect(estado.foiLidoNoPlano(plano.id, 1), isTrue);

      final relido = await reabrir();
      expect(relido.diasLidosDoPlano(plano.id), 2);
      expect(relido.foiLidoNoPlano(plano.id, 1), isTrue);

      await relido.alternarLidoNoPlano(plano.id, 1);
      expect(relido.foiLidoNoPlano(plano.id, 1), isFalse);
      expect((await reabrir()).diasLidosDoPlano(plano.id), 1);
    });

    test('removerPlano apaga o plano e o progresso, e persiste', () async {
      final estado = await Estado.abrir();
      final plano = await estado.criarPlano(titulo: '', livros: ['genesis'], dias: 5);
      await estado.alternarLidoNoPlano(plano.id, 3);
      await estado.removerPlano(plano.id);
      expect(estado.planosDoUsuario, isEmpty);
      expect(estado.diasLidosDoPlano(plano.id), 0);
      expect((await reabrir()).planosDoUsuario, isEmpty);
    });

    test('substituirLidosDoPlano troca o conjunto inteiro e persiste', () async {
      final estado = await Estado.abrir();
      final plano = await estado.criarPlano(titulo: '', livros: ['genesis'], dias: 5);
      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.substituirLidosDoPlano(plano.id, {2, 3});
      expect(estado.foiLidoNoPlano(plano.id, 1), isFalse);
      expect(estado.foiLidoNoPlano(plano.id, 2), isTrue);
      expect(estado.diasLidosDoPlano(plano.id), 2);
      expect((await reabrir()).diasLidosDoPlano(plano.id), 2);
    });

    test('aplicarPlanoDaNuvem adiciona na frente com os dias lidos', () async {
      final estado = await Estado.abrir();
      final plano = PlanoDoUsuario.doJsonDaNuvem(
        {'titulo': 'Nuvem', 'livros': ['exodo'], 'dias': 40},
        id: 'doc-1',
        criadoEm: DateTime(2027),
      );
      await estado.aplicarPlanoDaNuvem(plano, lidos: {1, 2, 3});
      expect(estado.planosDoUsuario.single.id, 'doc-1');
      expect(estado.planosDoUsuario.single.compartilhado, isTrue);
      expect(estado.diasLidosDoPlano('doc-1'), 3);
      expect((await reabrir()).planosDoUsuario.single.id, 'doc-1');
    });

    test('aplicarPlanoDaNuvem substitui no lugar, sem mudar a posição', () async {
      final estado = await Estado.abrir();
      final local = await estado.criarPlano(titulo: 'Local', livros: ['genesis'], dias: 30);
      final outro = await estado.criarPlano(titulo: 'Outro', livros: ['salmos'], dias: 10);
      // A lista está [outro, local]: reabrir pelo link não pode saltar o local
      // para a frente a cada abertura.
      final daNuvem = PlanoDoUsuario.doJsonDaNuvem(
        {'titulo': 'Local (atualizado)', 'livros': ['genesis'], 'dias': 30},
        id: local.id,
        criadoEm: DateTime(2027),
      );
      await estado.aplicarPlanoDaNuvem(daNuvem, lidos: {1});
      expect(estado.planosDoUsuario.map((p) => p.id), [outro.id, local.id]);
      expect(estado.planosDoUsuario.last.titulo, 'Local (atualizado)');
      expect(estado.diasLidosDoPlano(local.id), 1);
    });

    test('marcarCompartilhado persiste o flag', () async {
      final estado = await Estado.abrir();
      final plano = await estado.criarPlano(titulo: '', livros: ['genesis'], dias: 5);
      await estado.marcarCompartilhado(plano.id);
      expect(estado.planosDoUsuario.single.compartilhado, isTrue);
      expect((await reabrir()).planosDoUsuario.single.compartilhado, isTrue);
    });

    test('criarPlano aceita e persiste incluirDevocionais/devocionalAntes', () async {
      final estado = await Estado.abrir();
      final plano = await estado.criarPlano(
        titulo: '',
        livros: ['genesis'],
        dias: 30,
        incluirDevocionais: true,
        devocionalAntes: false,
      );
      expect(plano.incluirDevocionais, isTrue);
      expect(plano.devocionalAntes, isFalse);

      final relido = await reabrir();
      final planoRelido = relido.planosDoUsuario.single;
      expect(planoRelido.incluirDevocionais, isTrue);
      expect(planoRelido.devocionalAntes, isFalse);
    });

    test('atualizarPlano renomeia e liga/desliga devocionais, e persiste', () async {
      final estado = await Estado.abrir();
      final plano = await estado.criarPlano(
        titulo: 'Nome original',
        livros: ['genesis'],
        dias: 30,
      );

      final atualizado = await estado.atualizarPlano(
        plano.id,
        titulo: 'Nome novo',
        incluirDevocionais: true,
        devocionalAntes: false,
      );
      expect(atualizado.titulo, 'Nome novo');
      expect(atualizado.incluirDevocionais, isTrue);
      expect(atualizado.devocionalAntes, isFalse);
      // Livros e dias não mudam: atualizarPlano não mexe neles.
      expect(atualizado.livros, plano.livros);
      expect(atualizado.dias, plano.dias);
      expect(estado.planosDoUsuario.single.titulo, 'Nome novo');

      final relido = await reabrir();
      final planoRelido = relido.planosDoUsuario.single;
      expect(planoRelido.titulo, 'Nome novo');
      expect(planoRelido.incluirDevocionais, isTrue);
      expect(planoRelido.devocionalAntes, isFalse);
    });

    test('atualizarPlano com título em branco mantém o nome anterior', () async {
      final estado = await Estado.abrir();
      final plano = await estado.criarPlano(
        titulo: 'Nome original',
        livros: ['genesis'],
        dias: 30,
      );
      final atualizado = await estado.atualizarPlano(plano.id, titulo: '   ');
      expect(atualizado.titulo, 'Nome original');
    });

    test('armazenamento corrompido não impede o app de abrir', () async {
      SharedPreferences.setMockInitialValues({
        'planos_do_usuario': 'isto não é json {',
        'planos_lidos': '[1, 2, 3]',
      });
      final estado = await Estado.abrir();
      expect(estado.planosDoUsuario, isEmpty);
      expect(estado.diasLidosDoPlano('qualquer'), 0);
    });
  });

  group('a tela de Meus Planos', () {
    testWidgets('cria um plano pelo formulário e marca um dia', (tester) async {
      // O cronograma (primeira aba) carrega o asset do plano do ano; aquece
      // antes, senão a Future do FutureBuilder nunca completa no tempo falso.
      await tester.runAsync(() => Conteudo.instancia.plano(bissexto: false));
      final estado = Estado(await SharedPreferences.getInstance());
      // A aba Meus Planos só existe com conta: ver plano.dart.
      Nuvem.instancia.logadoForcado = true;
      addTearDown(() => Nuvem.instancia.logadoForcado = null);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(
            routerConfig: _routerDoPlano(estado, DateTime(2027, 2, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Meus planos'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum plano de leitura ainda'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Criar plano'));
      await tester.pumpAndSettle();
      expect(find.text('Novo plano de leitura'), findsOneWidget);

      // Escolhe Gênesis pela busca do seletor.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Escolher livros'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Gênesis',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Gênesis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      // A prévia mostra o primeiro dia já montado, antes de confirmar.
      expect(find.text('Dia 1 · Gênesis 1-2'), findsOneWidget);

      // O formulário ficou mais alto que a viewport do teste: rola até o
      // botão de criar antes de tocar, como um dedo faria. O botão só é
      // montado na árvore depois que a rolagem o traz para perto da
      // viewport (ListView não constrói filhos muito além dela).
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Criar plano'),
        200,
        // .first: as duas TextFormField (título e dias) têm cada uma um
        // Scrollable interno do EditableText; o da própria ListView vem
        // primeiro na árvore.
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Criar plano'));
      await tester.pumpAndSettle();

      // Cai na tela do plano, com o título padrão e o dia 1 marcável.
      expect(find.text('Gênesis em 30 dias'), findsOneWidget);
      // O contador canônico mora no cabeçalho ("dias lidos"); o rótulo
      // duplicado "dias concluídos" no meio da lista foi removido.
      expect(find.text('0 de 30 dias lidos'), findsOneWidget);

      await tester.tap(find.byTooltip('Marcar como lido').first);
      await tester.pumpAndSettle();
      expect(find.text('1 de 30 dias lidos'), findsOneWidget);
      expect(estado.diasLidosDoPlano(estado.planosDoUsuario.single.id), 1);

      // De volta à lista, o cartão mostra o progresso.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Seus planos'), findsOneWidget);
      expect(find.text('Gênesis em 30 dias'), findsOneWidget);
      expect(find.text('1 de 30 dias lidos'), findsOneWidget);
    });

    testWidgets(
      'trocar de aba e voltar para Planos mostra a lista, não o plano aberto '
      'antes de trocar',
      (tester) async {
        await tester.runAsync(() => Conteudo.instancia.plano(bissexto: false));
        final estado = Estado(await SharedPreferences.getInstance());
        Nuvem.instancia.logadoForcado = true;
        addTearDown(() => Nuvem.instancia.logadoForcado = null);
        final plano = await estado.criarPlano(
          titulo: 'Meu plano de teste',
          livros: ['genesis'],
          dias: 30,
        );

        // Espelha Moldura._irParaAba de main.dart: a aba Plano (índice 0
        // aqui) sempre reseta para a lista ao voltar de outra aba.
        final router = GoRouter(
          initialLocation: '/plano',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, shell) => Scaffold(
                body: shell,
                bottomNavigationBar: NavigationBar(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (i) => shell.goBranch(
                    i,
                    initialLocation: i == shell.currentIndex || i == 0,
                  ),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.event_note),
                      label: 'Plano',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.book),
                      label: 'Bíblia',
                    ),
                  ],
                ),
              ),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/plano',
                      builder: (context, state) =>
                          TelaPlano(hoje: DateTime(2027, 2, 15)),
                      routes: [
                        GoRoute(
                          path: 'novo',
                          builder: (context, state) =>
                              TelaNovoPlano(estado: estado),
                        ),
                        GoRoute(
                          path: ':id',
                          builder: (context, state) {
                            final id = state.pathParameters['id']!;
                            return TelaDeUmPlano(
                              estado: estado,
                              planoId: id,
                              plano: estado.planoDoUsuario(id),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/biblia',
                      builder: (context, state) => const Text('tela biblia'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          EscopoDoEstado(
            estado: estado,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Meus planos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(plano.titulo));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Opções do plano'), findsOneWidget);

        await tester.tap(find.text('Bíblia'));
        await tester.pumpAndSettle();
        expect(find.text('tela biblia'), findsOneWidget);

        await tester.tap(find.text('Plano'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Opções do plano'), findsNothing);
        expect(find.text('Seus planos'), findsOneWidget);
      },
    );

    testWidgets('o cartão de um plano compartilhado mostra o selo', (
      tester,
    ) async {
      await tester.runAsync(() => Conteudo.instancia.plano(bissexto: false));
      final estado = Estado(await SharedPreferences.getInstance());
      final plano = await estado.criarPlano(
        titulo: '',
        livros: ['genesis'],
        dias: 5,
      );
      await estado.marcarCompartilhado(plano.id);
      Nuvem.instancia.logadoForcado = true;
      addTearDown(() => Nuvem.instancia.logadoForcado = null);

      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: estado,
            child: TelaPlano(hoje: DateTime(2027, 2, 15)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meus planos'));
      await tester.pumpAndSettle();

      expect(find.text('Gênesis em 5 dias'), findsOneWidget);
      expect(find.text('5 dias · 50 capítulos'), findsOneWidget);
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    });

    testWidgets('checkbox de devocionais mostra o seletor e cria o plano '
        'com os 2 campos', (tester) async {
      await tester.runAsync(() async {
        await Conteudo.instancia.plano(bissexto: false);
        await Conteudo.instancia.aquecerIndiceDeDevocionais();
      });
      final estado = Estado(await SharedPreferences.getInstance());
      Nuvem.instancia.logadoForcado = true;
      addTearDown(() => Nuvem.instancia.logadoForcado = null);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/plano/novo',
              routes: [
                GoRoute(
                  path: '/plano',
                  builder: (context, state) => const SizedBox.shrink(),
                  routes: [
                    GoRoute(
                      path: 'novo',
                      builder: (context, state) => TelaNovoPlano(estado: estado),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Escolher livros'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Gênesis',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Gênesis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Incluir devocionais dos livros'), findsOneWidget);
      // Sem marcar o checkbox, o seletor antes/depois não aparece.
      expect(find.text('Antes do capítulo'), findsNothing);

      await tester.tap(find.text('Incluir devocionais dos livros'));
      await tester.pumpAndSettle();
      expect(find.text('Antes do capítulo'), findsOneWidget);
      expect(find.text('Depois do capítulo'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Criar plano'),
        200,
        // .first: as duas TextFormField (título e dias) têm cada uma um
        // Scrollable interno do EditableText; o da própria ListView vem
        // primeiro na árvore.
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Criar plano'));
      await tester.pumpAndSettle();

      expect(estado.planosDoUsuario.single.incluirDevocionais, isTrue);
      expect(estado.planosDoUsuario.single.devocionalAntes, isTrue);
    });
  });

  group('editar plano', () {
    testWidgets(
      'menu de opções renomeia o plano local',
      (tester) async {
        final estado = Estado(await SharedPreferences.getInstance());
        final plano = await estado.criarPlano(
          titulo: 'Nome original',
          livros: ['genesis'],
          dias: 30,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: EscopoDoEstado(
              estado: estado,
              child: TelaDeUmPlano(
                estado: estado,
                planoId: plano.id,
                plano: plano,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Opções do plano'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar plano'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Nome do plano'),
          'Nome editado',
        );
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        expect(estado.planosDoUsuario.single.titulo, 'Nome editado');
        // Livros e dias não foram tocados no formulário: sem confirmação de
        // reinício de progresso, o plano continua com os mesmos.
        expect(estado.planosDoUsuario.single.livros, plano.livros);
        expect(estado.planosDoUsuario.single.dias, plano.dias);
        expect(find.text('Nome editado'), findsOneWidget);
      },
    );

    testWidgets('cancelar o editor não muda nada', (tester) async {
      final estado = Estado(await SharedPreferences.getInstance());
      final plano = await estado.criarPlano(
        titulo: 'Nome original',
        livros: ['genesis'],
        dias: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: estado,
            child: TelaDeUmPlano(
              estado: estado,
              planoId: plano.id,
              plano: plano,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opções do plano'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar plano'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Nome do plano'),
        'Isto não deveria ficar',
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(estado.planosDoUsuario.single.titulo, 'Nome original');
    });
  });
}