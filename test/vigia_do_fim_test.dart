import 'package:flutter/services.dart';
import 'dart:async';

import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _espera = Duration(milliseconds: 100);

void main() {
  setUp(() => DevocionalVigiaDoFim.esperaSemRolagem = _espera);
  tearDown(() {
    DevocionalVigiaDoFim.esperaSemRolagem = const Duration(seconds: 20);
    // Deixa o app "à vista" para o próximo teste.
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  late ScrollController rolagem;
  late ValueNotifier<Object> chave;
  late int avisos;

  /// Um capítulo de [altura] px dentro de uma tela de 800 px.
  Future<void> montar(
    WidgetTester tester, {
    required double altura,
    Widget Function(Widget conteudo)? envolver,
  }) async {
    rolagem = ScrollController();
    chave = ValueNotifier<Object>('joao.3');
    avisos = 0;
    addTearDown(rolagem.dispose);
    addTearDown(chave.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Object>(
            valueListenable: chave,
            builder: (context, valor, _) => DevocionalVigiaDoFim(
              chave: valor,
              rolagem: rolagem,
              aoChegarAoFim: () => avisos++,
              child: Focus(
                autofocus: true,
                child: SingleChildScrollView(
                  controller: rolagem,
                  child: SizedBox(height: altura, child: const Placeholder()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> rolarComODedoAteOFim(WidgetTester tester) async {
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();
  }

  group('chegar ao fim rolando', () {
    testWidgets('a rolagem do usuário até o fim avisa uma vez', (tester) async {
      await montar(tester, altura: 3000);
      expect(avisos, 0);

      await rolarComODedoAteOFim(tester);
      expect(rolagem.offset, rolagem.position.maxScrollExtent);
      expect(avisos, 1);
    });

    testWidgets('rolar até o meio não avisa', (tester) async {
      await montar(tester, altura: 3000);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(rolagem.offset, greaterThan(0));
      expect(rolagem.offset, lessThan(rolagem.position.maxScrollExtent));
      expect(avisos, 0);
    });

    testWidgets('voltar ao fim de novo não avisa outra vez', (tester) async {
      await montar(tester, altura: 3000);
      await rolarComODedoAteOFim(tester);
      expect(avisos, 1);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 5000),
      );
      await tester.pumpAndSettle();
      await rolarComODedoAteOFim(tester);
      expect(avisos, 1);
    });

    testWidgets('rolagem feita pelo código até o fim não conta', (
      tester,
    ) async {
      await montar(tester, altura: 3000);
      rolagem.jumpTo(rolagem.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(avisos, 0);

      // Nem a espera de um capítulo curto vale aqui: ele rola.
      await tester.pump(_espera * 3);
      expect(avisos, 0);
    });

    testWidgets('animateTo feito pelo código até o fim também não conta', (
      tester,
    ) async {
      await montar(tester, altura: 3000);
      rolagem.animateTo(
        rolagem.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      expect(avisos, 0);
    });

    testWidgets(
      'rolagem animada depois de uma tecla conta (PageDown, espaço)',
      (tester) async {
        await montar(tester, altura: 3000);
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump();
        unawaited(
          rolagem.animateTo(
            rolagem.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.linear,
          ),
        );
        await tester.pumpAndSettle();
        expect(avisos, 1);
      },
    );

    testWidgets('com navegação acessível, chegar ao fim pelo código conta', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await montar(tester, altura: 3000);
      unawaited(
        rolagem.animateTo(
          rolagem.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
      );
      await tester.pumpAndSettle();
      expect(avisos, 1);
    });

    testWidgets('depois de um salto do código, o dedo ainda avisa', (
      tester,
    ) async {
      await montar(tester, altura: 3000);
      rolagem.jumpTo(rolagem.position.maxScrollExtent - 400);
      await tester.pumpAndSettle();
      expect(avisos, 0);

      await rolarComODedoAteOFim(tester);
      expect(avisos, 1);
    });

    testWidgets('lista de dentro do capítulo não conta como o fim dele', (
      tester,
    ) async {
      final interna = ScrollController();
      addTearDown(interna.dispose);
      rolagem = ScrollController();
      addTearDown(rolagem.dispose);
      avisos = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DevocionalVigiaDoFim(
              chave: 'joao.3',
              rolagem: rolagem,
              aoChegarAoFim: () => avisos++,
              child: SingleChildScrollView(
                controller: rolagem,
                child: Column(
                  children: [
                    SizedBox(
                      height: 100,
                      child: SingleChildScrollView(
                        key: const Key('interna'),
                        controller: interna,
                        scrollDirection: Axis.horizontal,
                        child: const SizedBox(width: 3000, height: 100),
                      ),
                    ),
                    const SizedBox(height: 3000),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.drag(
        find.byKey(const Key('interna')),
        const Offset(-5000, 0),
      );
      await tester.pumpAndSettle();
      expect(interna.offset, interna.position.maxScrollExtent);
      expect(avisos, 0);
    });
  });

  group('capítulo que cabe na tela', () {
    testWidgets('avisa depois da espera, uma vez só', (tester) async {
      await montar(tester, altura: 300);
      await tester.pump();
      expect(avisos, 0);

      await tester.pump(_espera ~/ 2);
      expect(avisos, 0, reason: 'a espera ainda não acabou');

      await tester.pump(_espera);
      expect(avisos, 1);

      await tester.pump(_espera * 5);
      expect(avisos, 1);
    });

    testWidgets('a espera padrão é de 20 segundos', (tester) async {
      DevocionalVigiaDoFim.esperaSemRolagem = const Duration(seconds: 20);
      await montar(tester, altura: 300);
      await tester.pump();
      await tester.pump(const Duration(seconds: 19));
      expect(avisos, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(avisos, 1);
    });

    testWidgets('capítulo que rola não ganha a espera', (tester) async {
      await montar(tester, altura: 3000);
      await tester.pump(_espera * 5);
      expect(avisos, 0);
    });

    testWidgets('capítulo do tamanho exato da tela conta como cabendo', (
      tester,
    ) async {
      // maxScrollExtent 0 é o limite: 600 px de conteúdo na tela de teste (800x600)
      // menos nada de barra (o Scaffold não tem AppBar aqui).
      await montar(tester, altura: 600);
      await tester.pump();
      await tester.pump(_espera * 2);
      expect(avisos, 1);
    });

    testWidgets('sair da tela antes da espera não avisa', (tester) async {
      await montar(tester, altura: 300);
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(_espera * 5);
      expect(avisos, 0);
    });

    testWidgets('com outra rota por cima, espera e avisa só quando volta', (
      tester,
    ) async {
      await montar(tester, altura: 300);
      await tester.pump();
      final contexto = tester.element(find.byType(DevocionalVigiaDoFim));
      unawaited(
        Navigator.of(contexto).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('por cima')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(_espera * 3);
      expect(avisos, 0, reason: 'ninguém está lendo o capítulo');

      Navigator.of(contexto).pop();
      await tester.pumpAndSettle();
      await tester.pump(_espera * 2);
      expect(avisos, 1);
    });

    testWidgets('com o app em segundo plano, espera e avisa só ao voltar', (
      tester,
    ) async {
      final binding = TestWidgetsFlutterBinding.instance;
      await montar(tester, altura: 300);
      await tester.pump();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      await tester.pump(_espera * 3);
      expect(avisos, 0);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(_espera * 2);
      expect(avisos, 1);
    });
  });

  group('trocar a chave', () {
    testWidgets('recomeça do zero: o novo capítulo avisa de novo ao fim', (
      tester,
    ) async {
      await montar(tester, altura: 3000);
      await rolarComODedoAteOFim(tester);
      expect(avisos, 1);

      chave.value = 'joao.4';
      await tester.pumpAndSettle();
      rolagem.jumpTo(0);
      await tester.pumpAndSettle();
      expect(avisos, 1);

      await rolarComODedoAteOFim(tester);
      expect(avisos, 2);
    });

    testWidgets('a rolagem do usuário do capítulo anterior não vale no novo', (
      tester,
    ) async {
      await montar(tester, altura: 3000);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      chave.value = 'joao.4';
      await tester.pumpAndSettle();
      // O código leva ao fim do capítulo novo: não é leitura.
      rolagem.jumpTo(rolagem.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(avisos, 0);
    });

    testWidgets('capítulo curto também recomeça a espera', (tester) async {
      await montar(tester, altura: 300);
      await tester.pump();
      await tester.pump(_espera * 2);
      expect(avisos, 1);

      chave.value = 'joao.4';
      await tester.pump();
      await tester.pump(_espera ~/ 2);
      expect(avisos, 1, reason: 'a espera do capítulo novo ainda corre');
      await tester.pump(_espera * 2);
      expect(avisos, 2);
    });

    testWidgets('trocar durante a espera cancela a espera do capítulo antigo', (
      tester,
    ) async {
      await montar(tester, altura: 300);
      await tester.pump();
      await tester.pump(_espera ~/ 2 + const Duration(milliseconds: 10));

      chave.value = 'joao.4';
      await tester.pump();
      // Passou da espera do antigo, mas não da do novo.
      await tester.pump(_espera ~/ 2 + const Duration(milliseconds: 10));
      expect(avisos, 0);
      await tester.pump(_espera);
      expect(avisos, 1);
    });
  });
}
