import 'dart:convert';
import 'dart:io';

import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:flutter_test/flutter_test.dart';

/// 29 de fevereiro só pode aparecer em ano bissexto.
///
/// Isto não é uma regra que o app precise impor com um `if`: a própria data cuida
/// disso. Estes testes existem para provar essa afirmação em vez de confiar nela, e
/// para quebrar se alguém trocar a construção da chave por algo que aceite 29-02
/// num ano comum.
void main() {
  Map<String, dynamic> ler(String caminho) =>
      json.decode(File(caminho).readAsStringSync()) as Map<String, dynamic>;

  group('29 de fevereiro', () {
    test('em ano bissexto a chave é 29-02', () {
      expect(Conteudo.chaveDoDia(DateTime(2028, 2, 29)), '29-02');
      expect(Conteudo.chaveDoDia(DateTime(2024, 2, 29)), '29-02');
    });

    test('em ano comum o próprio DateTime impede a data', () {
      // 2027 não é bissexto: o Dart normaliza 29 de fevereiro para 1 de março,
      // então a chave gerada é 01-03 e o conteúdo do dia 29 fica inalcançável.
      final normalizada = DateTime(2027, 2, 29);
      expect(normalizada.month, 3);
      expect(normalizada.day, 1);
      expect(Conteudo.chaveDoDia(normalizada), '01-03');
    });

    test('nenhum dia de ano comum produz a chave 29-02', () {
      for (final ano in [2025, 2026, 2027, 2029, 2030, 2100]) {
        var dia = DateTime(ano, 1, 1);
        final fim = DateTime(ano, 12, 31);
        while (!dia.isAfter(fim)) {
          expect(
            Conteudo.chaveDoDia(dia),
            isNot('29-02'),
            reason: 'ano $ano não é bissexto',
          );
          dia = dia.add(const Duration(days: 1));
        }
      }
    });

    test('em ano bissexto existe exatamente um 29-02 no ano', () {
      for (final ano in [2024, 2028, 2032]) {
        var dia = DateTime(ano, 1, 1);
        final fim = DateTime(ano, 12, 31);
        var quantos = 0;
        while (!dia.isAfter(fim)) {
          if (Conteudo.chaveDoDia(dia) == '29-02') quantos++;
          dia = dia.add(const Duration(days: 1));
        }
        expect(quantos, 1, reason: 'ano $ano é bissexto');
      }
    });

    test(
      'os assets acompanham a regra: devocionais têm 29-02, o plano comum não',
      () {
        // Manhã e Noite e Promessas de Deus são obras de 366 dias e trazem o dia
        // extra; o cronograma de leitura em ano comum tem 365 entradas e não o
        // prevê. O ano bissexto usa a variante própria, testada abaixo.
        expect(
          ler('assets/devotionals/manha_e_noite.json').containsKey('29-02'),
          isTrue,
        );
        expect(
          ler('assets/devotionals/promessas_de_deus.json').containsKey('29-02'),
          isTrue,
        );

        final plano =
            json.decode(File('assets/reading_plan.json').readAsStringSync())
                as List;
        final datas = plano
            .map((d) => (d as Map<String, dynamic>)['date'])
            .toList();
        expect(datas, isNot(contains('29-02')));
        expect(datas.length, 365);
      },
    );

    test('o cronograma bissexto tem 366 dias, incluindo 29-02', () {
      final plano =
          json.decode(
                File('assets/reading_plan_bissexto.json').readAsStringSync(),
              )
              as List;
      final datas = plano
          .map((d) => (d as Map<String, dynamic>)['date'])
          .toList();
      expect(datas.toSet().length, 366);
      expect(datas, contains('29-02'));
    });

    test('diasDoAno casa com o tamanho do cronograma de cada ano', () {
      expect(Conteudo.diasDoAno(2027), 365);
      expect(Conteudo.diasDoAno(2028), 366);
      // O número não é solto: é o divisor do progresso e o rótulo da tela Hoje,
      // então tem de bater com a contagem do asset correspondente.
      for (final (ano, arquivo) in [
        (2027, 'assets/reading_plan.json'),
        (2028, 'assets/reading_plan_bissexto.json'),
      ]) {
        final plano = json.decode(File(arquivo).readAsStringSync()) as List;
        expect(
          plano.length,
          Conteudo.diasDoAno(ano),
          reason: '$ano em $arquivo',
        );
      }
    });

    test('Conteudo.ehBissexto segue a regra gregoriana', () {
      expect(Conteudo.ehBissexto(2024), isTrue);
      expect(Conteudo.ehBissexto(2028), isTrue);
      expect(Conteudo.ehBissexto(2025), isFalse);
      expect(Conteudo.ehBissexto(1900), isFalse);
      expect(Conteudo.ehBissexto(2000), isTrue);
    });
  });
}
