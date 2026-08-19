import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/planos.dart';
import 'package:felipe_ambrozini/telas/plano.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
      // botão de criar antes de tocar, como um dedo faria.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Criar plano'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Criar plano'));
      await tester.pumpAndSettle();

      // Cai na tela do plano, com o título padrão e o dia 1 marcável.
      expect(find.text('Gênesis em 30 dias'), findsOneWidget);
      expect(find.text('0 de 30 dias concluídos'), findsOneWidget);

      await tester.tap(find.byTooltip('Marcar como lido').first);
      await tester.pumpAndSettle();
      expect(find.text('1 de 30 dias concluídos'), findsOneWidget);
      expect(estado.diasLidosDoPlano(estado.planosDoUsuario.single.id), 1);

      // De volta à lista, o cartão mostra o progresso.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Seus planos'), findsOneWidget);
      expect(find.text('Gênesis em 30 dias'), findsOneWidget);
      expect(find.text('1 de 30 dias lidos'), findsOneWidget);
    });

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
  });
}