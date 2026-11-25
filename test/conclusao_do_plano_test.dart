import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/planos.dart';
import 'package:devocional/funcoes/conclusao_do_plano.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O fim de um plano personalizado: quando conta como concluído e o aviso.

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Estado> abrir() async => Estado(await SharedPreferences.getInstance());

  group('planoConcluido', () {
    test('plano sem nenhum dia marcado não está concluído', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      expect(planoConcluido(estado, plano), isFalse);
    });

    test('faltando um dia, não está concluído', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);
      expect(planoConcluido(estado, plano), isFalse);
    });

    test('com todos os dias marcados, está concluído', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.alternarLidoNoPlano(plano.id, 2);
      expect(planoConcluido(estado, plano), isTrue);
    });

    test('desmarcar um dia tira o plano de concluído', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.alternarLidoNoPlano(plano.id, 2);
      await estado.alternarLidoNoPlano(plano.id, 2);
      expect(planoConcluido(estado, plano), isFalse);
    });

    test('dias de outro plano não contam', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Um',
        livros: ['3joao'],
        dias: 1,
      );
      final outro = await estado.criarPlano(
        titulo: 'Dois',
        livros: ['3joao'],
        dias: 1,
      );
      await estado.alternarLidoNoPlano(outro.id, 1);
      expect(planoConcluido(estado, plano), isFalse);
      expect(planoConcluido(estado, outro), isTrue);
    });
  });

  group('data de conclusão', () {
    test('concluir o último dia grava a data de conclusão', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);
      expect(estado.concluidoEm(plano.id), isNull);

      final antes = DateTime.now();
      await estado.alternarLidoNoPlano(plano.id, 2);
      final data = estado.concluidoEm(plano.id);
      expect(data, isNotNull);
      expect(
        data!.isBefore(antes.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(estado.planoEstaConcluido(plano), isTrue);

      final reaberto = await abrir();
      expect(
        reaberto.concluidoEm(plano.id),
        data,
        reason: 'a data fica gravada no aparelho',
      );
    });

    test('desmarcar um dia de plano concluído apaga a data', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.alternarLidoNoPlano(plano.id, 2);
      expect(estado.concluidoEm(plano.id), isNotNull);

      await estado.alternarLidoNoPlano(plano.id, 2);
      expect(estado.concluidoEm(plano.id), isNull);
      expect((await abrir()).concluidoEm(plano.id), isNull);
    });

    test('plano concluído antes desta versão ganha data ao abrir', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['3joao'],
        dias: 1,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);
      // Como um aparelho que concluiu o plano antes de a data existir.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('planos_concluidos');

      final reaberto = await abrir();
      expect(reaberto.concluidoEm(plano.id), isNotNull);
      expect(
        prefs.getString('planos_concluidos'),
        contains(plano.id),
        reason:
            'a data notada ao abrir fica gravada, sem mudar a cada abertura',
      );
    });

    test('recomeçar zera os dias e a data', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.alternarLidoNoPlano(plano.id, 2);

      await estado.recomecarPlano(plano.id);
      expect(estado.diasLidosDoPlano(plano.id), 0);
      expect(estado.concluidoEm(plano.id), isNull);
      expect(planoConcluido(estado, plano), isFalse);

      final reaberto = await abrir();
      expect(reaberto.diasLidosDoPlano(plano.id), 0);
      expect(reaberto.concluidoEm(plano.id), isNull);
    });

    test('recomeçar vale para A Vida de Jesus em 30 dias', () async {
      final estado = await abrir();
      for (final dia in planoDeJesus.diasDoPlano) {
        await estado.alternarLidoNoPlano(planoDeJesus.id, dia.numero);
      }
      expect(estado.concluidoEm(planoDeJesus.id), isNotNull);

      await estado.recomecarPlano(planoDeJesus.id);
      expect(estado.diasLidosDoPlano(planoDeJesus.id), 0);
      expect(estado.concluidoEm(planoDeJesus.id), isNull);
    });
  });

  group('avisoDePlanoConcluido', () {
    test('diz o título do plano, sem comemoração', () async {
      final estado = await abrir();
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['3joao'],
        dias: 1,
      );
      expect(avisoDePlanoConcluido(plano), 'Você concluiu o plano Cartas');
    });
  });
}
