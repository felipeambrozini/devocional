import 'package:devocional/dados/dia_da_leitura.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/dados/planos.dart';
import 'package:devocional/funcoes/marcar_dia_da_leitura.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chave = '2026-11-24';

DiaDoCronograma get _diaDoCronograma =>
    const DiaDoCronograma(chave: _chave, capitulos: ['joao.3']);

DiaDePlano _diaDoPlano(String planoId, [int numero = 1]) =>
    DiaDePlano(planoId: planoId, numero: numero, capitulos: const ['joao.3']);

void main() {
  late Estado estado;
  late BuildContext contexto;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // O ramo do cronograma só marca com conta.
    Nuvem.instancia.logadoForcado = true;
    estado = Estado(await SharedPreferences.getInstance());
  });
  tearDown(() => Nuvem.instancia.logadoForcado = null);

  /// Uma tela com um Scaffold, para o aviso ter onde aparecer.
  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              contexto = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  Future<void> fecharOAviso(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
  }

  group('registrarCapituloLidoDoDia num dia de duas leituras', () {
    const duas = DiaDoCronograma(
      chave: _chave,
      capitulos: ['genesis.1', 'salmos.1'],
    );
    const chaveDoProgresso = 'cronograma:$_chave';

    testWidgets('ler só a primeira não marca, e a segunda marca', (
      tester,
    ) async {
      await montar(tester);

      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 1);
      await tester.pump();
      expect(estado.foiLido(_chave), isFalse);
      expect(find.byType(SnackBar), findsNothing);
      expect(estado.progressoDosDias.lidosDoDia(chaveDoProgresso), {
        'genesis.1',
      });

      await registrarCapituloLidoDoDia(contexto, estado, duas, 'salmos', 1);
      await tester.pump();
      expect(estado.foiLido(_chave), isTrue);
      expect(find.text('Leitura do dia marcada como lida'), findsOneWidget);
      await fecharOAviso(tester);
    });

    testWidgets('ler na ordem inversa também marca', (tester) async {
      await montar(tester);

      await registrarCapituloLidoDoDia(contexto, estado, duas, 'salmos', 1);
      await tester.pump();
      expect(estado.foiLido(_chave), isFalse);

      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 1);
      await tester.pump();
      expect(estado.foiLido(_chave), isTrue);
      await fecharOAviso(tester);
    });

    testWidgets('ler o mesmo capítulo duas vezes não marca o dia', (
      tester,
    ) async {
      await montar(tester);

      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 1);
      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 1);
      await tester.pump();

      expect(estado.foiLido(_chave), isFalse);
      await fecharOAviso(tester);
    });

    testWidgets('capítulo de fora do dia não conta nem é guardado', (
      tester,
    ) async {
      await montar(tester);

      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 1);
      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 2);
      await registrarCapituloLidoDoDia(contexto, estado, duas, 'joao', 1);
      await tester.pump();

      expect(estado.foiLido(_chave), isFalse);
      expect(estado.progressoDosDias.lidosDoDia(chaveDoProgresso), {
        'genesis.1',
      });
      await fecharOAviso(tester);
    });

    testWidgets('depois de marcar, o andamento é esquecido', (tester) async {
      await montar(tester);

      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 1);
      await registrarCapituloLidoDoDia(contexto, estado, duas, 'salmos', 1);
      await tester.pump();

      expect(estado.progressoDosDias.lidosDoDia(chaveDoProgresso), isEmpty);
      await fecharOAviso(tester);
    });

    testWidgets('dia já lido continua lido, sem aviso, e esquece o andamento', (
      tester,
    ) async {
      await montar(tester);
      await estado.alternarLido(_chave);

      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 1);
      await registrarCapituloLidoDoDia(contexto, estado, duas, 'salmos', 1);
      await tester.pump();

      expect(estado.foiLido(_chave), isTrue);
      expect(find.byType(SnackBar), findsNothing);
      expect(estado.progressoDosDias.lidosDoDia(chaveDoProgresso), isEmpty);
      await fecharOAviso(tester);
    });

    testWidgets('o andamento sobrevive a reabrir o Estado entre as leituras', (
      tester,
    ) async {
      await montar(tester);
      await registrarCapituloLidoDoDia(contexto, estado, duas, 'genesis', 1);

      final reaberto = Estado(await SharedPreferences.getInstance());
      await registrarCapituloLidoDoDia(contexto, reaberto, duas, 'salmos', 1);
      await tester.pump();

      expect(reaberto.foiLido(_chave), isTrue);
      await fecharOAviso(tester);
    });

    testWidgets('num dia de plano local também espera todos os capítulos', (
      tester,
    ) async {
      await montar(tester);
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['joao'],
        dias: 5,
      );
      final dia = DiaDePlano(
        planoId: plano.id,
        numero: 2,
        capitulos: const ['2joao.1', '3joao.1'],
      );

      await registrarCapituloLidoDoDia(contexto, estado, dia, '2joao', 1);
      await tester.pump();
      expect(estado.foiLidoNoPlano(plano.id, 2), isFalse);

      await registrarCapituloLidoDoDia(contexto, estado, dia, '3joao', 1);
      await tester.pump();
      expect(estado.foiLidoNoPlano(plano.id, 2), isTrue);
      expect(find.text('Dia 2 de Cartas marcado como lido'), findsOneWidget);
      await fecharOAviso(tester);
    });

    testWidgets('dia de um capítulo só marca de uma vez', (tester) async {
      await montar(tester);

      await registrarCapituloLidoDoDia(
        contexto,
        estado,
        _diaDoCronograma,
        'joao',
        3,
      );
      await tester.pump();

      expect(estado.foiLido(_chave), isTrue);
      await fecharOAviso(tester);
    });
  });

  group('marcarDiaDaLeituraAoTerminar no cronograma', () {
    testWidgets('marca o dia e avisa com Desfazer', (tester) async {
      await montar(tester);
      expect(estado.foiLido(_chave), isFalse);

      await marcarDiaDaLeituraAoTerminar(contexto, estado, _diaDoCronograma);
      await tester.pump();

      expect(estado.foiLido(_chave), isTrue);
      expect(find.text('Leitura do dia marcada como lida'), findsOneWidget);
      expect(find.text('Desfazer'), findsOneWidget);
      await fecharOAviso(tester);
    });

    testWidgets('o Desfazer desmarca o dia', (tester) async {
      await montar(tester);
      await marcarDiaDaLeituraAoTerminar(contexto, estado, _diaDoCronograma);
      await tester.pump();

      await tester.pumpAndSettle();
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(estado.foiLido(_chave), isFalse);
      expect(find.text('Leitura do dia marcada como lida'), findsNothing);
      await fecharOAviso(tester);
    });

    testWidgets('dia já lido continua lido, sem aviso', (tester) async {
      await montar(tester);
      await estado.alternarLido(_chave);

      await marcarDiaDaLeituraAoTerminar(contexto, estado, _diaDoCronograma);
      await tester.pump();

      expect(estado.foiLido(_chave), isTrue);
      expect(find.text('Leitura do dia marcada como lida'), findsNothing);
      await fecharOAviso(tester);
    });

    testWidgets('chamar duas vezes não desmarca', (tester) async {
      await montar(tester);
      await marcarDiaDaLeituraAoTerminar(contexto, estado, _diaDoCronograma);
      await marcarDiaDaLeituraAoTerminar(contexto, estado, _diaDoCronograma);
      await tester.pump();

      expect(estado.foiLido(_chave), isTrue);
      await fecharOAviso(tester);
    });

    testWidgets('o Desfazer não marca de novo um dia já desmarcado à mão', (
      tester,
    ) async {
      await montar(tester);
      await marcarDiaDaLeituraAoTerminar(contexto, estado, _diaDoCronograma);
      await tester.pump();
      await estado.alternarLido(_chave);
      expect(estado.foiLido(_chave), isFalse);

      await tester.pumpAndSettle();
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(estado.foiLido(_chave), isFalse);
      await fecharOAviso(tester);
    });

    testWidgets('marca só o dia pedido, não os vizinhos', (tester) async {
      await montar(tester);
      await marcarDiaDaLeituraAoTerminar(contexto, estado, _diaDoCronograma);
      await tester.pump();

      expect(estado.foiLido('2026-11-23'), isFalse);
      expect(estado.foiLido('2026-11-25'), isFalse);
      await fecharOAviso(tester);
    });
  });

  group('marcarDiaDaLeituraAoTerminar num plano local', () {
    late PlanoDoUsuario plano;

    setUp(() async {
      plano = await estado.criarPlano(
        titulo: 'Evangelhos',
        livros: ['joao'],
        dias: 5,
      );
    });

    testWidgets('marca o dia e avisa com o número e o título', (tester) async {
      await montar(tester);

      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        _diaDoPlano(plano.id, 2),
      );
      await tester.pump();

      expect(estado.foiLidoNoPlano(plano.id, 2), isTrue);
      expect(estado.foiLidoNoPlano(plano.id, 1), isFalse);
      expect(
        find.text('Dia 2 de Evangelhos marcado como lido'),
        findsOneWidget,
      );
      await fecharOAviso(tester);
    });

    testWidgets('o Desfazer desmarca o dia', (tester) async {
      await montar(tester);
      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        _diaDoPlano(plano.id, 2),
      );
      await tester.pump();

      await tester.pumpAndSettle();
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(estado.foiLidoNoPlano(plano.id, 2), isFalse);
      await fecharOAviso(tester);
    });

    testWidgets('dia já lido continua lido, sem aviso', (tester) async {
      await montar(tester);
      await estado.alternarLidoNoPlano(plano.id, 2);

      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        _diaDoPlano(plano.id, 2),
      );
      await tester.pump();

      expect(estado.foiLidoNoPlano(plano.id, 2), isTrue);
      expect(find.textContaining('marcado como lido'), findsNothing);
      await fecharOAviso(tester);
    });

    testWidgets('o primeiro dia, no limite inferior, também marca', (
      tester,
    ) async {
      await montar(tester);
      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        _diaDoPlano(plano.id, 1),
      );
      await tester.pump();

      expect(estado.foiLidoNoPlano(plano.id, 1), isTrue);
      await fecharOAviso(tester);
    });

    testWidgets('o plano fixo de Jesus também marca', (tester) async {
      await montar(tester);
      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        _diaDoPlano('jesus'),
      );
      await tester.pump();

      expect(estado.foiLidoNoPlano('jesus', 1), isTrue);
      await fecharOAviso(tester);
    });

    testWidgets('plano inexistente não faz nada', (tester) async {
      await montar(tester);

      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        _diaDoPlano('nao_existe'),
      );
      await tester.pump();

      expect(estado.foiLidoNoPlano('nao_existe', 1), isFalse);
      expect(estado.diasLidosDoPlano('nao_existe'), 0);
      expect(find.byType(SnackBar), findsNothing);
      await fecharOAviso(tester);
    });

    testWidgets('plano apagado depois de abrir a leitura é ignorado', (
      tester,
    ) async {
      await montar(tester);
      await estado.removerPlano(plano.id);

      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        _diaDoPlano(plano.id),
      );
      await tester.pump();

      expect(estado.foiLidoNoPlano(plano.id, 1), isFalse);
      expect(find.byType(SnackBar), findsNothing);
      await fecharOAviso(tester);
    });
  });

  group('marcarDiaDaLeituraAoTerminar num plano compartilhado', () {
    testWidgets('sem login não marca nem avisa', (tester) async {
      Nuvem.instancia.logadoForcado = false;
      await montar(tester);
      final compartilhado = await estado.criarPlano(
        titulo: 'Em grupo',
        livros: ['joao'],
        dias: 5,
      );
      await estado.aplicarPlanoDaNuvem(
        compartilhado.copyWith(compartilhado: true),
        lidos: {},
      );

      await marcarDiaDaLeituraAoTerminar(
        contexto,
        estado,
        _diaDoPlano(compartilhado.id),
      );
      await tester.pump();

      expect(estado.foiLidoNoPlano(compartilhado.id, 1), isFalse);
      expect(find.byType(SnackBar), findsNothing);
      await fecharOAviso(tester);
    });
  });
}
