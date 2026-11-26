import 'dart:convert';
import 'dart:io';

import 'package:devocional/dados/canon.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lê o asset direto do disco. Um teste de dados não precisa subir um app inteiro
/// só para validar o conteúdo de um JSON.
List<DiaDoPlano> carregarPlano([
  String caminho = 'assets/planos/cronograma.json',
]) {
  final cru = File(caminho).readAsStringSync();
  return [
    for (final d in json.decode(cru) as List)
      DiaDoPlano.doJson(d as Map<String, dynamic>),
  ];
}

/// Confere que nenhum capítulo do canon ficou de fora do plano, para que uma
/// edição futura não volte a pular um trecho inteiro (como as genealogias de
/// 1 Crônicas).
void conferirCoberturaDoCanon(List<DiaDoPlano> plano) {
  final lidos = <String, Set<int>>{};
  for (final dia in plano) {
    for (final faixa in dia.faixas) {
      lidos.putIfAbsent(faixa.livro, () => <int>{}).addAll(faixa.capitulos);
    }
  }
  for (final livro in canon) {
    final capitulos = lidos[livro.slug] ?? const <int>{};
    for (var capitulo = 1; capitulo <= livro.capitulos; capitulo++) {
      expect(
        capitulos,
        contains(capitulo),
        reason: 'falta ${livro.nome} $capitulo',
      );
    }
  }
}

void main() {
  final plano = carregarPlano();

  group('cronograma anual', () {
    test('tem exatamente 365 dias', () {
      expect(plano.length, 365);
    });

    test('cobre toda data de 01-01 a 31-12, uma vez cada', () {
      const diasPorMes = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      final datas = plano.map((d) => d.data).toList();
      expect(datas.toSet().length, 365, reason: 'ha data repetida');
      for (var mes = 1; mes <= 12; mes++) {
        for (var dia = 1; dia <= diasPorMes[mes - 1]; dia++) {
          final chave =
              '${dia.toString().padLeft(2, '0')}-'
              '${mes.toString().padLeft(2, '0')}';
          expect(datas, contains(chave), reason: 'falta $chave');
        }
      }
      // 29 de fevereiro nao existe no cronograma comum: em ano bissexto a
      // variante de 366 dias o inclui como dia proprio.
      expect(datas, isNot(contains('29-02')));
    });

    test('todo livro citado existe no canon e as faixas cabem nele', () {
      for (final dia in plano) {
        expect(dia.faixas, isNotEmpty, reason: '${dia.data} sem faixa');
        for (final faixa in dia.faixas) {
          final livro = livroPorSlug(faixa.livro);
          expect(livro, isNotNull, reason: '${dia.data}: livro ${faixa.livro}');
          expect(faixa.deCapitulo, greaterThanOrEqualTo(1));
          expect(faixa.deCapitulo, lessThanOrEqualTo(faixa.ateCapitulo));
          expect(
            faixa.ateCapitulo,
            lessThanOrEqualTo(livro!.capitulos),
            reason: '${dia.data}: ${livro.nome} ${faixa.ateCapitulo}',
          );
        }
      }
    });

    test('cobre todos os capitulos do canon, sem lacuna', () {
      conferirCoberturaDoCanon(plano);
    });

    test(
      'faixa por versiculo fica num unico capitulo e nao vira faixa de capitulos',
      () {
        final porVersiculo = plano.where(
          (d) => d.faixas.any((f) => f.porVersiculo),
        );
        // Os tres dias de Salmos 119 no fim de outubro.
        expect(porVersiculo.map((d) => d.data), ['29-10', '30-10', '31-10']);

        final primeiro = porVersiculo.first.faixas.single;
        expect(primeiro.livro, 'salmos');
        expect(primeiro.deCapitulo, 119);
        expect(primeiro.ateCapitulo, 119);
        expect(primeiro.deVersiculo, 1);
        expect(primeiro.ateVersiculo, 56);
        expect(primeiro.rotulo, 'Salmo 119:1 a 56');
        // O capitulo inteiro seria 176 versiculos; a faixa nao pode virar isso.
        expect(primeiro.capitulos.length, 1);
      },
    );

    test(
      'dia com varios livros gera uma faixa por capitulo, na ordem escrita',
      () {
        final dia = plano.firstWhere((d) => d.data == '28-07');
        expect(dia.rotulo, 'Obadias 1, 2 Reis 1 a 4');
        // O '2' de '2 Reis' nao pode ser lido como capitulo de Obadias, que tem so um.
        expect(dia.faixas.map((f) => f.livro), [
          'obadias',
          '2reis',
          '2reis',
          '2reis',
          '2reis',
        ]);
        expect(dia.faixas[1].deCapitulo, 1);
        expect(dia.faixas.last.ateCapitulo, 4);
      },
    );

    test('capitulos avulsos do mesmo livro nao viram uma faixa continua', () {
      final dia = plano.firstWhere((d) => d.data == '12-06');
      expect(dia.rotulo, 'Salmos 3, 4, 12, 13, 28, 55');
      expect(dia.faixas.length, 6);
      expect(dia.faixas.map((f) => f.deCapitulo), [3, 4, 12, 13, 28, 55]);
      for (final faixa in dia.faixas) {
        expect(faixa.deCapitulo, faixa.ateCapitulo);
      }
    });

    test('livros numerados nao sao confundidos com os de nome parecido', () {
      final dia = plano.firstWhere((d) => d.data == '02-03');
      expect(dia.faixas.map((f) => f.livro), [
        '1joao',
        '1joao',
        '2joao',
        '3joao',
      ]);
    });

    test('rotulo de faixa e legivel na tela', () {
      const umCapitulo = Faixa(livro: 'joao', deCapitulo: 3, ateCapitulo: 3);
      const varios = Faixa(livro: 'marcos', deCapitulo: 1, ateCapitulo: 3);
      expect(umCapitulo.rotulo, 'João 3');
      expect(varios.rotulo, 'Marcos 1 a 3');
      expect(varios.capitulos, [1, 2, 3]);
    });
  });

  group('cronograma bissexto', () {
    final planoBissexto = carregarPlano(
      'assets/planos/cronograma_bissexto.json',
    );

    test('tem exatamente 366 dias, um por data do ano incluindo 29-02', () {
      expect(planoBissexto.length, 366);
      final datas = planoBissexto.map((d) => d.data).toList();
      expect(datas.toSet().length, 366);
      expect(datas, contains('29-02'));
    });

    test('so difere do cronograma comum na divisao de 28/2 e 29/2', () {
      final comum = {for (final d in plano) d.data: d.rotulo};
      final bissexto = {for (final d in planoBissexto) d.data: d.rotulo};
      for (final data in bissexto.keys) {
        if (data == '28-02' || data == '29-02') continue;
        expect(bissexto[data], comum[data], reason: 'divergiu em $data');
      }
      expect(bissexto['28-02'], '2 Pedro 1 a 3');
      expect(bissexto['29-02'], 'Judas 1');
    });

    test('todo livro citado existe no canon e as faixas cabem nele', () {
      for (final dia in planoBissexto) {
        for (final faixa in dia.faixas) {
          final livro = livroPorSlug(faixa.livro);
          expect(livro, isNotNull, reason: '${dia.data}: livro ${faixa.livro}');
          expect(
            faixa.ateCapitulo,
            lessThanOrEqualTo(livro!.capitulos),
            reason: '${dia.data}: ${livro.nome} ${faixa.ateCapitulo}',
          );
        }
      }
    });

    test('cobre todos os capitulos do canon, sem lacuna', () {
      conferirCoberturaDoCanon(planoBissexto);
    });
  });

  group('anos anteriores', () {
    test(
      'anosAnterioresComLeitura ignora o ano atual e anos sem leitura',
      () async {
        SharedPreferences.setMockInitialValues({
          'dias_lidos': [
            '2024-03-01',
            '2024-12-31',
            '2025-01-05',
            '2026-02-02',
            '2027-01-01',
          ],
        });
        final estado = Estado(await SharedPreferences.getInstance());

        expect(estado.anosAnterioresComLeitura(anoAtual: 2026), [2025, 2024]);
        expect(estado.anosAnterioresComLeitura(anoAtual: 2024), isEmpty);
      },
    );

    test('anosAnterioresComLeitura ignora chave malformada', () async {
      SharedPreferences.setMockInitialValues({
        'dias_lidos': ['abc-01-01', '2024-03-01'],
      });
      final estado = Estado(await SharedPreferences.getInstance());

      expect(estado.anosAnterioresComLeitura(anoAtual: 2026), [2024]);
    });

    Future<Estado> montarAno(
      WidgetTester tester, {
      required Map<String, Object> prefs,
    }) async {
      Nuvem.instancia.logadoForcado = true;
      addTearDown(() => Nuvem.instancia.logadoForcado = null);
      SharedPreferences.setMockInitialValues(prefs);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => Conteudo.instancia.plano(bissexto: true));
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Scaffold(
              body: TabernaculoAbaDoCronograma(
                hoje: DateTime(2026, 11, 25),
                ano: 2024,
                somenteLeitura: true,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump();
      return estado;
    }

    testWidgets('ano passado mostra os dias lidos daquele ano', (tester) async {
      await montarAno(
        tester,
        prefs: {
          'dias_lidos': [
            '2024-01-01',
            '2024-01-02',
            '2024-02-29',
            '2026-01-03',
          ],
        },
      );

      expect(find.text('2 de 31 dias concluídos em Janeiro'), findsOneWidget);

      await tester.tap(find.text('Fevereiro'));
      await tester.pump();
      await tester.pump();

      // A variante de 366 dias: fevereiro tem 29 e o dia 29 está lido.
      expect(find.text('1 de 29 dias concluídos em Fevereiro'), findsOneWidget);
    });

    testWidgets('ano passado não passa o dia às faixas da leitura', (
      tester,
    ) async {
      await montarAno(tester, prefs: {});

      final botoes = tester.widgetList<TabernaculoBotaoDeFaixa>(
        find.byType(TabernaculoBotaoDeFaixa),
      );
      expect(botoes, isNotEmpty);
      expect(botoes.every((b) => b.dia == null), isTrue);
    });

    testWidgets('ano passado não marca nada ao tocar', (tester) async {
      final estado = await montarAno(
        tester,
        prefs: {
          'dias_lidos': ['2024-01-01'],
        },
      );

      expect(find.text('Marcar como lido'), findsNothing);
      expect(find.text('Desfazer'), findsNothing);
      final antes = estado.diasLidosNoAno(2024);

      await tester.tap(find.text('Dia lido').first);
      await tester.pump();
      await tester.pump();

      expect(estado.diasLidosNoAno(2024), antes);
      expect(estado.foiLido(Estado.chaveDeLeitura(2024, '01-01')), isTrue);
      expect(find.text('Dia marcado como lido'), findsNothing);
    });
  });
}
