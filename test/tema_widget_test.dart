import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:felipe_ambrozini/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O tema ponta a ponta: escolher no Estado precisa chegar na tela.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Aplica a mudança e avança o relógio além da transição de tema.
  ///
  /// São dois quadros de propósito. No primeiro o `setState` entra e o
  /// AnimatedTheme do MaterialApp começa a transição de 200 ms, ainda na cor
  /// antiga; só no segundo, já passado o prazo, a cor é a de destino. Com um
  /// quadro só, o teste lia a paleta velha e parecia que nada tinha mudado.
  ///
  /// E `pumpAndSettle` não serve aqui: sem aquecer os assets, a tela Hoje fica
  /// com o CircularProgressIndicator girando e nada nunca assenta.
  Future<void> passarATransicao(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A cor de fundo que o app está de fato pintando.
  Color fundoEmUso(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Moldura))).colorScheme.surface;

  testWidgets('escolher claro ou escuro troca a paleta na hora', (
    tester,
  ) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await tester.pumpWidget(AppDevocional(estado: estado));
    await tester.pump();

    await estado.definirModoDoTema(ModoDoTema.escuro);
    await passarATransicao(tester);
    expect(fundoEmUso(tester), Cores.fundo);

    await estado.definirModoDoTema(ModoDoTema.claro);
    await passarATransicao(tester);
    expect(fundoEmUso(tester), Cores.pergaminho);
  });

  testWidgets('no automático, quem manda é o aparelho', (tester) async {
    // O padrão é seguir o sistema, e o sistema pode virar com o app aberto.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final estado = Estado(await SharedPreferences.getInstance());
    expect(estado.modoDoTema, ModoDoTema.sistema);
    await tester.pumpWidget(AppDevocional(estado: estado));
    await passarATransicao(tester);
    expect(fundoEmUso(tester), Cores.pergaminho);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await passarATransicao(tester);
    expect(
      fundoEmUso(tester),
      Cores.fundo,
      reason:
          'o MaterialApp tem os dois temas montados, então virar o sistema '
          'não pode depender de passar pelo Estado',
    );
  });

  testWidgets('a folha de ajustes traz tamanho e aparência juntos', (
    tester,
  ) async {
    final estado = Estado(await SharedPreferences.getInstance());
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

    // As duas escolhas moram na mesma folha: quem abre para aumentar a letra vê
    // que dá para trocar o tema sem ter que procurar em outro lugar.
    expect(find.text('Tamanho do texto'), findsOneWidget);
    expect(find.text('Aparência'), findsOneWidget);
    for (final modo in ModoDoTema.values) {
      expect(find.text(modo.rotulo), findsOneWidget, reason: modo.rotulo);
    }
    for (final rotulo in rotulosDeEscala) {
      expect(find.text(rotulo), findsOneWidget, reason: rotulo);
    }

    // A folha rola: as escolhas mais baixas precisam entrar na tela antes do
    // toque, como nas outras folhas do app (ver baloes_test.dart).
    await tester.ensureVisible(find.text(ModoDoTema.claro.rotulo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ModoDoTema.claro.rotulo));
    await tester.pumpAndSettle();
    expect(estado.modoDoTema, ModoDoTema.claro);

    await tester.ensureVisible(find.text('Grande'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grande'));
    await tester.pumpAndSettle();
    expect(estado.escalaDeLeitura, 1.3);
  });

  testWidgets('escolher escuro ignora o aparelho no claro', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final estado = Estado(await SharedPreferences.getInstance());
    await estado.definirModoDoTema(ModoDoTema.escuro);
    await tester.pumpWidget(AppDevocional(estado: estado));
    await passarATransicao(tester);

    // Às nove da noite o celular pode ainda estar no claro; quem lê na cama
    // escolheu escuro e a escolha tem que valer.
    expect(fundoEmUso(tester), Cores.fundo);
  });
}
