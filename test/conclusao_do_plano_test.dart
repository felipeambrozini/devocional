import 'package:devocional/dados/estado.dart';
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
