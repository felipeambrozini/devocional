import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/progresso_dos_dias.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late ProgressoDosDias progresso;
  var mudou = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mudou = 0;
    progresso = ProgressoDosDias.ler(prefs, () => mudou++);
  });

  group('registrar e ler', () {
    test('dia sem andamento não tem capítulo lido', () {
      expect(progresso.lidosDoDia('cronograma:2026-11-24'), isEmpty);
    });

    test('registrar guarda o capítulo no dia certo', () async {
      await progresso.registrar('cronograma:2026-11-24', 'genesis.1');
      expect(progresso.lidosDoDia('cronograma:2026-11-24'), {'genesis.1'});
      expect(progresso.lidosDoDia('cronograma:2026-11-25'), isEmpty);
    });

    test('vários capítulos do mesmo dia se acumulam', () async {
      await progresso.registrar('plano:abc:1', 'genesis.1');
      await progresso.registrar('plano:abc:1', 'salmos.1');
      expect(progresso.lidosDoDia('plano:abc:1'), {'genesis.1', 'salmos.1'});
    });

    test(
      'registrar o mesmo capítulo duas vezes não duplica nem avisa',
      () async {
        await progresso.registrar('plano:abc:1', 'genesis.1');
        final antes = mudou;
        await progresso.registrar('plano:abc:1', 'genesis.1');
        expect(progresso.lidosDoDia('plano:abc:1'), {'genesis.1'});
        expect(mudou, antes);
      },
    );

    test('registrar avisa quem escuta', () async {
      await progresso.registrar('plano:abc:1', 'genesis.1');
      expect(mudou, 1);
    });

    test('o conjunto devolvido não deixa mexer no andamento', () async {
      await progresso.registrar('plano:abc:1', 'genesis.1');
      final lidos = progresso.lidosDoDia('plano:abc:1');
      expect(() => lidos.add('salmos.1'), throwsUnsupportedError);
    });
  });

  group('sobreviver a reabrir o Estado', () {
    test('o andamento volta depois de abrir o Estado de novo', () async {
      final primeiro = Estado(prefs);
      await primeiro.progressoDosDias.registrar('plano:abc:2', 'joao.1');
      await primeiro.progressoDosDias.registrar('plano:abc:2', 'joao.2');

      final segundo = Estado(await SharedPreferences.getInstance());
      expect(segundo.progressoDosDias.lidosDoDia('plano:abc:2'), {
        'joao.1',
        'joao.2',
      });
    });

    test('o que foi esquecido não volta', () async {
      final primeiro = Estado(prefs);
      await primeiro.progressoDosDias.registrar('plano:abc:2', 'joao.1');
      await primeiro.progressoDosDias.esquecer('plano:abc:2');

      final segundo = Estado(await SharedPreferences.getInstance());
      expect(segundo.progressoDosDias.lidosDoDia('plano:abc:2'), isEmpty);
    });
  });

  group('limite de dias', () {
    test('guarda no máximo ${ProgressoDosDias.maximoDeDias} dias', () async {
      const limite = ProgressoDosDias.maximoDeDias;
      for (var i = 0; i < limite + 5; i++) {
        await progresso.registrar('plano:abc:$i', 'joao.1');
      }
      var guardados = 0;
      for (var i = 0; i < limite + 5; i++) {
        if (progresso.lidosDoDia('plano:abc:$i').isNotEmpty) guardados++;
      }
      expect(guardados, limite);
    });

    test('o dia mexido há mais tempo sai primeiro', () async {
      const limite = ProgressoDosDias.maximoDeDias;
      for (var i = 0; i < limite; i++) {
        await progresso.registrar('plano:abc:$i', 'joao.1');
      }
      await progresso.registrar('plano:abc:$limite', 'joao.1');

      expect(progresso.lidosDoDia('plano:abc:0'), isEmpty);
      expect(progresso.lidosDoDia('plano:abc:1'), {'joao.1'});
      expect(progresso.lidosDoDia('plano:abc:$limite'), {'joao.1'});
    });

    test('mexer num dia antigo o poupa da saída', () async {
      const limite = ProgressoDosDias.maximoDeDias;
      for (var i = 0; i < limite; i++) {
        await progresso.registrar('plano:abc:$i', 'joao.1');
      }
      await progresso.registrar('plano:abc:0', 'joao.2');
      await progresso.registrar('plano:abc:$limite', 'joao.1');

      expect(progresso.lidosDoDia('plano:abc:0'), {'joao.1', 'joao.2'});
      expect(progresso.lidosDoDia('plano:abc:1'), isEmpty);
    });

    test('exatamente no limite ninguém sai', () async {
      const limite = ProgressoDosDias.maximoDeDias;
      for (var i = 0; i < limite; i++) {
        await progresso.registrar('plano:abc:$i', 'joao.1');
      }
      expect(progresso.lidosDoDia('plano:abc:0'), {'joao.1'});
    });

    test('o limite também vale depois de reabrir', () async {
      const limite = ProgressoDosDias.maximoDeDias;
      for (var i = 0; i < limite + 1; i++) {
        await progresso.registrar('plano:abc:$i', 'joao.1');
      }
      final reaberto = ProgressoDosDias.ler(prefs, () {});
      expect(reaberto.lidosDoDia('plano:abc:0'), isEmpty);
      expect(reaberto.lidosDoDia('plano:abc:$limite'), {'joao.1'});
    });
  });

  group('esquecer', () {
    test('apaga o andamento só do dia pedido', () async {
      await progresso.registrar('plano:abc:1', 'joao.1');
      await progresso.registrar('plano:abc:2', 'joao.1');

      await progresso.esquecer('plano:abc:1');

      expect(progresso.lidosDoDia('plano:abc:1'), isEmpty);
      expect(progresso.lidosDoDia('plano:abc:2'), {'joao.1'});
    });

    test('esquecer dia sem andamento não faz nada nem avisa', () async {
      await progresso.esquecer('plano:abc:9');
      expect(mudou, 0);
    });
  });

  group('JSON corrompido', () {
    for (final cru in [
      'isto não é json',
      '[1, 2, 3]',
      '{"plano:abc:1": "joao.1"}',
      '{"plano:abc:1": [1, 2]}',
    ]) {
      test('"$cru" zera o andamento sem quebrar', () async {
        SharedPreferences.setMockInitialValues({'progresso_dos_dias': cru});
        final sujo = await SharedPreferences.getInstance();

        final lido = ProgressoDosDias.ler(sujo, () {});

        expect(lido.lidosDoDia('plano:abc:1'), isEmpty);
        // E segue funcionando depois de zerar.
        await lido.registrar('plano:abc:1', 'joao.1');
        expect(lido.lidosDoDia('plano:abc:1'), {'joao.1'});
      });
    }

    test('o Estado abre normalmente com o andamento corrompido', () async {
      SharedPreferences.setMockInitialValues({
        'progresso_dos_dias': '{quebrado',
      });
      final estado = Estado(await SharedPreferences.getInstance());
      expect(estado.progressoDosDias.lidosDoDia('plano:abc:1'), isEmpty);
    });
  });
}
