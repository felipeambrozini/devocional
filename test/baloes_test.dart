import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/lembretes.dart';
import 'package:felipe_ambrozini/data/recursos.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:felipe_ambrozini/telas/chat.dart';
import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LembretesFalsas implements Lembretes {
  bool permissaoConcedida = true;
  @override
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  }) async {}

  @override
  Future<String?> chaveQueAbriuOApp() async => null;

  @override
  Future<bool> pedirPermissao() async => permissaoConcedida;

  @override
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  }) async {}

  @override
  Future<void> cancelar() async {}

  @override
  String fusoAtual = 'America/Sao_Paulo';
}

void main() {
  setUp(() {
    // A dica de primeira visita já foi dada (o teste dela está no fim deste
    // arquivo): estes testes tratam da presença dos balões, e o tooltip
    // estável é o rótulo do balão.
    SharedPreferences.setMockInitialValues({'baloes_tooltip_dispensado': true});
    Lembretes.instancia = _LembretesFalsas();
    // Estes testes exercitam o recurso em si, não a restrição por e-mail: o
    // login de verdade nunca roda no ambiente de teste (ver Recursos).
    Recursos.conversasForcado = true;
  });

  tearDown(() => Recursos.conversasForcado = null);

  testWidgets(
    'contador sobe ao abrir a folha e continua ao abrir o seletor de horário',
    (tester) async {
      // Explícito, e não o padrão do ambiente de teste: lembretesSuportados
      // depende da plataforma, e a seção de lembretes só existe em Android.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final estado = Estado(await SharedPreferences.getInstance());
        await tester.pumpWidget(AppDevocional(estado: estado));
        await tester.pumpAndSettle();

        expect(camadasFlutuantes.value, 0);
        expect(
          find.byTooltip('Conversas com Charles Spurgeon'),
          findsOneWidget,
        );
        // A placa de nome é o que torna os retratos reconhecíveis sem tooltip:
        // quem é cada um deve estar visível, não só no anúncio do leitor de
        // tela. O finder desce até o balão para não colidir com outros textos.
        expect(
          find.descendant(
            of: find.byType(BalaoDeChat),
            matching: find.text('Spurgeon'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(BalaoDeChat),
            matching: find.text('Felipe'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byType(BotaoDeAjustes));
        await tester.pumpAndSettle();

        expect(camadasFlutuantes.value, greaterThan(0), reason: 'folha aberta');
        expect(find.text('Tamanho do texto'), findsOneWidget);
        expect(
          find.byTooltip('Conversas com Charles Spurgeon'),
          findsNothing,
          reason: 'os balões não podem flutuar por cima da folha de ajustes',
        );

        await tester.ensureVisible(
          find.widgetWithText(
            SwitchListTile,
            'Avisar no horário do devocional',
          ),
        );
        await tester.tap(
          find.widgetWithText(
            SwitchListTile,
            'Avisar no horário do devocional',
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Noite'));
        final hora = MaterialLocalizations.of(
          tester.element(find.text('Noite')),
        ).formatTimeOfDay(const TimeOfDay(hour: 18, minute: 0));
        await tester.tap(find.text(hora));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(
          camadasFlutuantes.value,
          greaterThan(1),
          reason: 'o seletor de horário soma por cima da folha',
        );
        expect(
          find.byTooltip('Conversas com Charles Spurgeon'),
          findsNothing,
          reason: 'os balões não podem flutuar por cima do seletor de horário',
        );

        // Fecha o seletor e a folha: o contador volta a zero. Um toque na
        // barreira seria frágil — a folha isScrollControlled quase preenche a
        // tela —, então o pop é explícito, como o botão de voltar faria.
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.text('Tamanho do texto'))).pop();
        await tester.pumpAndSettle();
        expect(camadasFlutuantes.value, 0);
        expect(
          find.byTooltip('Conversas com Charles Spurgeon'),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('a folha de ajustes não tem mais o interruptor dos balões', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(AppDevocional(estado: estado));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BotaoDeAjustes));
      await tester.pumpAndSettle();

      // A aba Conversas é a entrada do chat; o interruptor que escondia os
      // balões saiu da folha junto com a função dele.
      expect(
        find.widgetWithText(SwitchListTile, 'Mostrar botões de conversa'),
        findsNothing,
      );
      expect(find.text('Reexibir dica dos botões de conversa'), findsOneWidget);

      Navigator.of(tester.element(find.text('Tamanho do texto'))).pop();
      await tester.pumpAndSettle();
      expect(camadasFlutuantes.value, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('em tela estreita, a aba Conversas é a entrada do chat', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(AppDevocional(estado: estado));
      await tester.pumpAndSettle();

      // Sem faixa nem balão: nada de retrato por cima do texto de leitura.
      expect(find.byType(BalaoDeChat), findsNothing);

      await tester.tap(find.text('Conversas'));
      await tester.pumpAndSettle();

      // A aba é a entrada do chat: as duas cartas levam ao histórico de cada
      // persona.
      expect(find.text('Charles Spurgeon'), findsOneWidget);
      expect(find.text('Felipe Ambrozini'), findsOneWidget);

      await tester.tap(find.text('Charles Spurgeon'));
      await tester.pumpAndSettle();

      expect(find.text('Começar conversa'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
