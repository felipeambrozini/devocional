import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/lembretes.dart';
import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Implementação falsa: grava o que foi chamado, sem canal de plataforma.
///
/// `Lembretes.instancia` é um campo estático mutável exatamente para isto —
/// ver o comentário em `lib/data/lembretes.dart`.
class _LembretesFalsas implements Lembretes {
  bool permissaoConcedida = true;
  String? chaveDeAberturaSimulada;
  void Function(String)? _callback;

  final agendamentos = <(TimeOfDay manha, TimeOfDay noite)>[];
  int vezesCancelado = 0;

  @override
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  }) async {
    _callback = aoTocarNotificacao;
  }

  @override
  Future<String?> chaveQueAbriuOApp() async => chaveDeAberturaSimulada;

  @override
  Future<bool> pedirPermissao() async => permissaoConcedida;

  @override
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  }) async {
    agendamentos.add((manhaEPromessas, noite));
  }

  @override
  Future<void> cancelar() async => vezesCancelado++;

  /// Simula o toque numa notificação com o app já aberto.
  void simularToque(String chave) => _callback?.call(chave);
}

void main() {
  late _LembretesFalsas falsas;
  late Estado estado;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    falsas = _LembretesFalsas();
    Lembretes.instancia = falsas;
    estado = await Estado.abrir();
  });

  group('alternarLembretes', () {
    test('ligar com permissão concedida agenda nos horários salvos', () async {
      final concedida = await alternarLembretes(estado, true);

      expect(concedida, isTrue);
      expect(estado.lembretesAtivos, isTrue);
      expect(falsas.agendamentos, hasLength(1));
      final (manha, noite) = falsas.agendamentos.single;
      expect(manha, const TimeOfDay(hour: 6, minute: 0));
      expect(noite, const TimeOfDay(hour: 18, minute: 0));
    });

    test('ligar com permissão negada não liga nem agenda', () async {
      falsas.permissaoConcedida = false;
      final concedida = await alternarLembretes(estado, true);

      expect(concedida, isFalse);
      expect(estado.lembretesAtivos, isFalse);
      expect(falsas.agendamentos, isEmpty);
    });

    test('desligar cancela e persiste', () async {
      await alternarLembretes(estado, true);
      await alternarLembretes(estado, false);

      expect(estado.lembretesAtivos, isFalse);
      expect(falsas.vezesCancelado, 1);
    });
  });

  group('aplicarHorarioDeLembrete', () {
    test('com os lembretes desligados, só grava, não agenda', () async {
      await aplicarHorarioDeLembrete(estado, minutosManha: 7 * 60);

      expect(estado.minutosLembreteManha, 7 * 60);
      expect(falsas.agendamentos, isEmpty);
    });

    test(
      'com os lembretes ligados, grava e reagenda com o novo horário',
      () async {
        await alternarLembretes(estado, true);
        falsas.agendamentos.clear();

        await aplicarHorarioDeLembrete(estado, minutosManha: 7 * 60 + 30);

        expect(estado.minutosLembreteManha, 7 * 60 + 30);
        expect(falsas.agendamentos, hasLength(1));
        final (manha, noite) = falsas.agendamentos.single;
        expect(manha, const TimeOfDay(hour: 7, minute: 30));
        // A noite não mudou nesta chamada, mas o reagendamento leva os dois
        // horários juntos: agendar() sempre substitui os três.
        expect(noite, const TimeOfDay(hour: 18, minute: 0));
      },
    );

    test('trocar só a noite não move o horário da manhã', () async {
      await alternarLembretes(estado, true);
      falsas.agendamentos.clear();

      await aplicarHorarioDeLembrete(estado, minutosNoite: 21 * 60);

      final (manha, noite) = falsas.agendamentos.single;
      expect(manha, const TimeOfDay(hour: 6, minute: 0));
      expect(noite, const TimeOfDay(hour: 21, minute: 0));
    });
  });

  group('toque na notificação', () {
    test('o payload chega ao callback registrado em inicializar', () async {
      final recebidas = <String>[];
      await falsas.inicializar(aoTocarNotificacao: recebidas.add);

      falsas.simularToque('promessas');

      expect(recebidas, ['promessas']);
    });
  });

  group('a seção Lembretes na folha de ajustes', () {
    // Explícito, e não o padrão do ambiente de teste: lembretesSuportados
    // depende da plataforma, e o teste não deveria valer ou não conforme um
    // padrão não declarado em nenhum lugar.
    Future<void> comoAndroid(
      WidgetTester tester,
      Future<void> Function() corpo,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await corpo();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    Future<void> abrirAFolha(WidgetTester tester) async {
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: BotaoDeAjustes(estado: estado)),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(BotaoDeAjustes));
      await tester.pumpAndSettle();
    }

    testWidgets('tocar o interruptor liga de verdade, não só na UI', (
      tester,
    ) async {
      await comoAndroid(tester, () async {
        await abrirAFolha(tester);

        // A folha agora rola (a seção Lembretes empurrou o conteúdo além da
        // altura padrão de teste), então o interruptor pode nascer fora da
        // viewport visível.
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(estado.lembretesAtivos, isTrue);
        expect(falsas.agendamentos, hasLength(1));
        // E a UI reflete: os campos de horário aparecem só com o interruptor
        // ligado.
        expect(find.text('Manhã e Promessas'), findsOneWidget);
        expect(find.text('Noite'), findsOneWidget);
      });
    });

    testWidgets('permissão negada avisa e não liga', (tester) async {
      await comoAndroid(tester, () async {
        falsas.permissaoConcedida = false;
        await abrirAFolha(tester);

        // A folha agora rola (a seção Lembretes empurrou o conteúdo além da
        // altura padrão de teste), então o interruptor pode nascer fora da
        // viewport visível.
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(estado.lembretesAtivos, isFalse);
        expect(falsas.agendamentos, isEmpty);
        expect(
          find.textContaining('Permissão de notificação negada'),
          findsOneWidget,
        );
      });
    });
  });
}
