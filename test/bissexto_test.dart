import 'dart:convert';
import 'dart:io';

import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:flutter_test/flutter_test.dart';

/// 29 de fevereiro só pode aparecer em ano bissexto.
///
/// Isto não é uma regra que o app precise impor com um `if`: a própria data cuida
/// disso. Estes testes existem para provar essa afirmação em vez de confiar nela, e
/// para quebrar se alguém trocar a construção da chave por algo que aceite 02-29
/// num ano comum.
void main() {
  Map<String, dynamic> ler(String caminho) =>
      json.decode(File(caminho).readAsStringSync()) as Map<String, dynamic>;

  group('29 de fevereiro', () {
    test('em ano bissexto a chave é 02-29', () {
      expect(Conteudo.chaveDoDia(DateTime(2028, 2, 29)), '02-29');
      expect(Conteudo.chaveDoDia(DateTime(2024, 2, 29)), '02-29');
    });

    test('em ano comum o próprio DateTime impede a data', () {
      // 2027 não é bissexto: o Dart normaliza 29 de fevereiro para 1 de março,
      // então a chave gerada é 03-01 e o conteúdo do dia 29 fica inalcançável.
      final normalizada = DateTime(2027, 2, 29);
      expect(normalizada.month, 3);
      expect(normalizada.day, 1);
      expect(Conteudo.chaveDoDia(normalizada), '03-01');
    });

    test('nenhum dia de ano comum produz a chave 02-29', () {
      for (final ano in [2025, 2026, 2027, 2029, 2030, 2100]) {
        var dia = DateTime(ano, 1, 1);
        final fim = DateTime(ano, 12, 31);
        while (!dia.isAfter(fim)) {
          expect(Conteudo.chaveDoDia(dia), isNot('02-29'),
              reason: 'ano $ano não é bissexto');
          dia = dia.add(const Duration(days: 1));
        }
      }
    });

    test('em ano bissexto existe exatamente um 02-29 no ano', () {
      for (final ano in [2024, 2028, 2032]) {
        var dia = DateTime(ano, 1, 1);
        final fim = DateTime(ano, 12, 31);
        var quantos = 0;
        while (!dia.isAfter(fim)) {
          if (Conteudo.chaveDoDia(dia) == '02-29') quantos++;
          dia = dia.add(const Duration(days: 1));
        }
        expect(quantos, 1, reason: 'ano $ano é bissexto');
      }
    });

    test('os assets acompanham a regra: devocionais têm 02-29, o plano não', () {
      // Manhã e Noite e Promessas de Deus são obras de 366 dias e trazem o dia
      // extra; o cronograma de leitura tem 365 entradas e não o prevê.
      expect(ler('assets/devotional/morning_evening.json').containsKey('02-29'),
          isTrue);
      expect(ler('assets/devotional/promises.json').containsKey('02-29'), isTrue);

      final plano = json.decode(
        File('assets/reading_plan.json').readAsStringSync(),
      ) as List;
      final datas = plano.map((d) => (d as Map<String, dynamic>)['date']).toList();
      expect(datas, isNot(contains('02-29')));
      expect(datas.length, 365);
    });
  });
}
