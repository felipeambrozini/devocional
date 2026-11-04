import 'dart:convert';

import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Estado> reabrir() async =>
      Estado(await SharedPreferences.getInstance());

  String copiaComDias(List<String> dias, [List<Map<String, Object?>>? notas]) =>
      json.encode({'versao': 1, 'marcacoes': notas ?? [], 'dias_lidos': dias});

  Map<String, Object?> notaJson(String nota, [int? em]) => {
    'livro': 'joao',
    'capitulo': 3,
    'versiculo': 16,
    'nota': nota,
    'em': ?em,
  };

  group('dias lidos por ano', () {
    test('marca de 2026 nao aparece em 2027', () async {
      final estado = await Estado.abrir();
      await estado.alternarLido('2026-08-01');

      expect(estado.foiLido(Estado.chaveDeLeitura(2026, '01-08')), isTrue);
      expect(estado.foiLido(Estado.chaveDeLeitura(2027, '01-08')), isFalse);
      expect(estado.progressoDoAno(2027, 365), 0);
      expect(estado.diasLidosNoAno(2027), 0);
      expect(estado.diasLidosNoAno(2026), 1);
    });

    test('2028 nao herda marcas de 2027', () async {
      final estado = await Estado.abrir();
      await estado.alternarLido(Estado.chaveDeLeitura(2027, '15-03'));

      expect(estado.diasLidosNoAno(2028), 0);
      expect(estado.foiLido(Estado.chaveDeLeitura(2028, '15-03')), isFalse);
    });

    test('o total de todos os anos continua contando 2026 em 2027', () async {
      final estado = await Estado.abrir();
      await estado.alternarLido('2026-12-25');
      await estado.alternarLido('2027-01-01');

      expect(estado.diasLidosEmTodosOsAnos, 2);
      expect(estado.diasLidosNoAno(2027), 1);
      expect(json.decode(estado.exportar())['dias_lidos'], [
        '2026-12-25',
        '2027-01-01',
      ]);
    });
  });

  group('migracao das chaves DD-MM', () {
    test('de 28/07 em diante vira 2026, antes disso vira 2027', () {
      expect(Estado.migrarChaveDeLeitura('28-07'), '2026-07-28');
      expect(Estado.migrarChaveDeLeitura('01-08'), '2026-08-01');
      expect(Estado.migrarChaveDeLeitura('27-07'), '2027-07-27');
      expect(Estado.migrarChaveDeLeitura('05-01'), '2027-01-05');
    });

    test('e idempotente e deixa passar a chave nova', () {
      final uma = Estado.migrarChaveDeLeitura('01-08');
      expect(Estado.migrarChaveDeLeitura(uma), uma);
      expect(Estado.migrarChaveDeLeitura('2028-02-29'), '2028-02-29');
    });

    test('o carregamento migra uma vez so, mesmo reabrindo', () async {
      SharedPreferences.setMockInitialValues({
        'dias_lidos': ['01-08', '05-01'],
      });
      final estado = await reabrir();
      await estado.alternarLido('2026-09-01');

      final reaberto = await reabrir();
      expect(reaberto.diasLidosEmTodosOsAnos, 3);
      expect(reaberto.foiLido('2026-08-01'), isTrue);
      expect(reaberto.foiLido('2027-01-05'), isTrue);
    });

    test('importar copia antiga funciona e une sem apagar', () async {
      final estado = await Estado.abrir();
      await estado.alternarLido('2026-08-01');

      final (_, dias) = await estado.importar(
        copiaComDias(['01-08', '05-01', '2026-09-02']),
      );

      expect(dias, 2, reason: '01-08 ja existia como 2026-08-01');
      expect(estado.diasLidosEmTodosOsAnos, 3);
      expect(estado.foiLido('2027-01-05'), isTrue);
    });
  });

  group('carimbo das notas', () {
    const antigo = 1000;
    const novo = 2000;

    Future<Estado> comNotaLocalEmitidaEm(int em) async {
      SharedPreferences.setMockInitialValues({
        'marcacoes': json.encode([notaJson('local', em)]),
      });
      return reabrir();
    }

    test('definirNota grava o carimbo e ele sobrevive ao disco', () async {
      final antes = DateTime.now().millisecondsSinceEpoch;
      final estado = await Estado.abrir();
      await estado.definirNota('joao', 3, 16, 'minha nota');

      expect(
        (await reabrir()).marcacaoDe('joao', 3, 16)!.em,
        greaterThanOrEqualTo(antes),
      );
    });

    test('nota editada aqui, mais nova, nao e trocada pela velha', () async {
      final estado = await comNotaLocalEmitidaEm(novo);
      await estado.importar(copiaComDias([], [notaJson('velha', antigo)]));

      expect(estado.marcacaoDe('joao', 3, 16)!.nota, 'local');
    });

    test('nota que chega mais nova vence', () async {
      final estado = await comNotaLocalEmitidaEm(antigo);
      await estado.importar(copiaComDias([], [notaJson('nova', novo)]));

      expect(estado.marcacaoDe('joao', 3, 16)!.nota, 'nova');
    });

    test('sem carimbo dos dois lados fica a local', () async {
      SharedPreferences.setMockInitialValues({
        'marcacoes': json.encode([notaJson('local')]),
      });
      final estado = await reabrir();
      await estado.importar(copiaComDias([], [notaJson('de fora')]));

      expect(estado.marcacaoDe('joao', 3, 16)!.nota, 'local');
    });

    test('nota vazia que chega nao apaga a local', () async {
      final estado = await comNotaLocalEmitidaEm(antigo);
      await estado.importar(copiaComDias([], [notaJson('', novo)]));

      expect(estado.marcacaoDe('joao', 3, 16)!.nota, 'local');
    });

    test('carimbo no futuro distante e limitado a um dia', () {
      final distante = DateTime.now().millisecondsSinceEpoch * 2;
      final marcacao = Marcacao.doJson(notaJson('x', distante));

      expect(
        marcacao.em,
        lessThanOrEqualTo(
          DateTime.now()
              .add(const Duration(days: 1, minutes: 1))
              .millisecondsSinceEpoch,
        ),
      );
    });

    test('marcacao sem carimbo nao escreve o campo', () {
      expect(
        const Marcacao(livro: 'joao', capitulo: 3, versiculo: 16).paraJson(),
        isNot(contains('em')),
      );
    });
  });
}
