import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> aquecerAssets(WidgetTester tester) async {
    await tester.runAsync(() async {
      final conteudo = Conteudo.instancia;
      await conteudo.plano();
      final agora = DateTime.now();
      await conteudo.diaDoPlano(agora);
      for (final periodo in Periodo.values) {
        await conteudo.devocional(agora, periodo);
      }
      await conteudo.promessa(agora);
      await conteudo.capitulo('genesis', 1);
      await conteudo.capitulo('salmos', 119);
      await conteudo.introducao('genesis');
    });
  }

  testWidgets('o cartão de ajuda aparece na primeira visita e some com Entendi', (
    tester,
  ) async {
    await aquecerAssets(tester);
    final estado = Estado(await SharedPreferences.getInstance());
    // O cartão cresceu com as linhas de ajuda e a Hoje abre com as duas
    // leituras do dia no topo: numa janela de 800x900 o cartão nasce além
    // da área que a lista constrói. Rola até ele, como o visitante faria,
    // antes de conferir e tocar.
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(AppDevocional(estado: estado));
    await tester.pumpAndSettle();

    // O GoRouter navega ate Hoje num frame: a lista nao existe ate a rota
    // aterrar. Espera-a antes de rolar e tocar, senao o scroll nao encontra
    // nada e o tap cai no espaco vazio.
    for (var i = 0; i < 50 && find.byType(ListView).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    // O cartão fica abaixo das leituras do dia na 800×900: rola até ele para
    // construí-lo (scrollUntilVisible materializa, não basta visto que o
    // ListView já o constrói adiante do visitável), depois garante que está de
    // fato à mostra antes de tocar.
    await tester.scrollUntilVisible(
      find.text('Entendi'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(find.text('Como usar'), findsOneWidget);
    expect(find.text('Entendi'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Como usar'), findsNothing);

    // E não volta: a escolha fica gravada no estado.
    await tester.pumpWidget(AppDevocional(estado: estado));
    await tester.pumpAndSettle();
    expect(find.text('Como usar'), findsNothing);
  });

  testWidgets('o aviso de dia marcado aparece e some sozinho em 3s', (
    tester,
  ) async {
    await aquecerAssets(tester);
    final estado = Estado(await SharedPreferences.getInstance());
    await tester.pumpWidget(AppDevocional(estado: estado));
    await tester.pumpAndSettle();

    // O _router é um singleton global (lib/main.dart). O primeiro teste
    // muda o estado dele; garante que este teste comece na aba Hoje.
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final goRouter = app.routerConfig as GoRouter;
    goRouter.go('/hoje');
    await tester.pumpAndSettle();

    // O GoRouter navega ate Hoje num frame: a lista ainda nao existe.
    // Espera-a antes de garantir o botao visivel e tocar (mesmo padrão do teste 1).
    for (var i = 0; i < 50 && find.byType(ListView).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    // O _LeituraDeHoje usa CarregaUmaVez (FutureBuilder) que carrega
    // assincronamente. Espera o FutureBuilder completar.
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Procura pelo tooltip "Marcar como lido" ou "Desmarcar" que está no IconButton.
    final botaoMarcar = find.byTooltip('Marcar como lido');
    final botaoDesmarcar = find.byTooltip('Desmarcar');
    
    if (botaoMarcar.evaluate().isNotEmpty) {
      expect(botaoMarcar, findsOneWidget);
      await tester.ensureVisible(botaoMarcar);
      await tester.pumpAndSettle();
      await tester.tap(botaoMarcar);
    } else if (botaoDesmarcar.evaluate().isNotEmpty) {
      // Já está marcado - desmarca primeiro para testar o fluxo completo
      expect(botaoDesmarcar, findsOneWidget);
      await tester.ensureVisible(botaoDesmarcar);
      await tester.pumpAndSettle();
      await tester.tap(botaoDesmarcar);
      await tester.pumpAndSettle();
      
      // Agora marca
      final botaoMarcar2 = find.byTooltip('Marcar como lido');
      expect(botaoMarcar2, findsOneWidget);
      await tester.ensureVisible(botaoMarcar2);
      await tester.pumpAndSettle();
      await tester.tap(botaoMarcar2);
    } else {
      fail('Nem "Marcar como lido" nem "Desmarcar" encontrado. Verifique se o FutureBuilder completou.');
    }
    await tester.pumpAndSettle();

    expect(find.text('Dia marcado como lido.'), findsOneWidget);

    // O aviso some sozinho: o "Desfazer" é a saída opcional, não a única.
    // (Regressão do bug do Flutter 3.44.9: o timer do ScaffoldMessenger nunca
    // nasce quando o SnackBar tem ação; o fechamento sai de mostrarAviso.)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Dia marcado como lido.'), findsNothing);
  });
}