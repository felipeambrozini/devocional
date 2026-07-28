import 'dart:convert';
import 'dart:io';

import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lê o asset direto do disco. Um teste de dados não precisa subir um app inteiro
/// só para validar o conteúdo de um JSON.
List<DiaDoPlano> carregarPlano() {
  final cru = File('assets/reading_plan.json').readAsStringSync();
  return [
    for (final d in json.decode(cru) as List) DiaDoPlano.doJson(d as Map<String, dynamic>),
  ];
}

void main() {
  final plano = carregarPlano();

  group('cronograma anual', () {
    test('tem exatamente 365 dias', () {
      expect(plano.length, 365);
    });

    test('cobre toda data de 01-01 a 12-31, uma vez cada', () {
      const diasPorMes = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      final datas = plano.map((d) => d.data).toList();
      expect(datas.toSet().length, 365, reason: 'ha data repetida');
      for (var mes = 1; mes <= 12; mes++) {
        for (var dia = 1; dia <= diasPorMes[mes - 1]; dia++) {
          final chave = '${mes.toString().padLeft(2, '0')}-'
              '${dia.toString().padLeft(2, '0')}';
          expect(datas, contains(chave), reason: 'falta $chave');
        }
      }
      // 29 de fevereiro nao existe no cronograma: em ano bissexto e dia de recuperacao.
      expect(datas, isNot(contains('02-29')));
    });

    test('todo livro citado existe no canon e as faixas cabem nele', () {
      for (final dia in plano) {
        expect(dia.faixas, isNotEmpty, reason: '${dia.data} sem faixa');
        for (final faixa in dia.faixas) {
          final livro = livroPorSlug(faixa.livro);
          expect(livro, isNotNull, reason: '${dia.data}: livro ${faixa.livro}');
          expect(faixa.deCapitulo, greaterThanOrEqualTo(1));
          expect(faixa.deCapitulo, lessThanOrEqualTo(faixa.ateCapitulo));
          expect(faixa.ateCapitulo, lessThanOrEqualTo(livro!.capitulos),
              reason: '${dia.data}: ${livro.nome} ${faixa.ateCapitulo}');
        }
      }
    });

    test('faixa por versiculo fica num unico capitulo e nao vira faixa de capitulos', () {
      final porVersiculo = plano.where((d) => d.faixas.any((f) => f.porVersiculo));
      // Os tres dias de Salmos 119 no fim de outubro.
      expect(porVersiculo.map((d) => d.data), ['10-29', '10-30', '10-31']);

      final primeiro = porVersiculo.first.faixas.single;
      expect(primeiro.livro, 'salmos');
      expect(primeiro.deCapitulo, 119);
      expect(primeiro.ateCapitulo, 119);
      expect(primeiro.deVersiculo, 1);
      expect(primeiro.ateVersiculo, 56);
      expect(primeiro.rotulo, 'Salmos 119:1-56');
      // O capitulo inteiro seria 176 versiculos; a faixa nao pode virar isso.
      expect(primeiro.capitulos.length, 1);
    });

    test('dia com varios livros gera uma faixa por livro, na ordem escrita', () {
      final dia = plano.firstWhere((d) => d.data == '07-28');
      expect(dia.rotulo, 'Obadias 1, 2 Reis 1 a 4');
      // O '2' de '2 Reis' nao pode ser lido como capitulo de Obadias, que tem so um.
      expect(dia.faixas.map((f) => f.livro), ['obadias', '2reis']);
      expect(dia.faixas.last.deCapitulo, 1);
      expect(dia.faixas.last.ateCapitulo, 4);
    });

    test('capitulos avulsos do mesmo livro nao viram uma faixa continua', () {
      final dia = plano.firstWhere((d) => d.data == '06-12');
      expect(dia.rotulo, 'Salmos 3, 4, 12, 13, 28, 55');
      expect(dia.faixas.length, 6);
      expect(dia.faixas.map((f) => f.deCapitulo), [3, 4, 12, 13, 28, 55]);
      for (final faixa in dia.faixas) {
        expect(faixa.deCapitulo, faixa.ateCapitulo);
      }
    });

    test('livros numerados nao sao confundidos com os de nome parecido', () {
      final dia = plano.firstWhere((d) => d.data == '03-02');
      expect(dia.faixas.map((f) => f.livro), ['1joao', '2joao', '3joao']);
    });

    test('rotulo de faixa e legivel na tela', () {
      const umCapitulo = Faixa(livro: 'joao', deCapitulo: 3, ateCapitulo: 3);
      const varios = Faixa(livro: 'marcos', deCapitulo: 1, ateCapitulo: 3);
      expect(umCapitulo.rotulo, 'João 3');
      expect(varios.rotulo, 'Marcos 1-3');
      expect(varios.capitulos, [1, 2, 3]);
    });
  });
}
