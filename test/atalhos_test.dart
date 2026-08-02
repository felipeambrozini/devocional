import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:felipe_ambrozini/telas/biblia.dart';
import 'package:felipe_ambrozini/telas/busca.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Atalhos de teclado do leitor, para Windows e web.
///
/// O caso difícil não é o atalho em si: é o foco. O IndexedStack da moldura
/// mantém as cinco telas vivas, e o evento de tecla sobe a partir de quem tem o
/// foco. Duas coisas quebravam isso, e as duas estão cobertas aqui: o atalho
/// declarado só no corpo da tela, que a tecla contornava quando o foco caía num
/// botão da AppBar, e o foco parado no nó do escopo da aba, que fica acima da
/// tela e portanto acima dos atalhos dela.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> aquecer(WidgetTester tester) => tester.runAsync(() async {
    final c = Conteudo.instancia;
    await c.plano();
    for (final p in Periodo.values) {
      await c.devocional(DateTime.now(), p);
    }
    await c.promessa(DateTime.now());
    for (final v in Versao.values) {
      await c.capitulo(v, 'genesis', 1);
      await c.capitulo(v, 'genesis', 2);
    }
    await c.introducao('genesis');
  });

  testWidgets('no leitor, as setas passam de capítulo', (tester) async {
    await aquecer(tester);
    final estado = Estado(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: const MaterialApp(home: TelaBiblia()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(estado.ultimaLeitura, ('genesis', 2));
    expect(find.text('Gênesis 2'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(estado.ultimaLeitura, ('genesis', 1));
  });

  testWidgets('Ctrl+F abre a busca', (tester) async {
    await aquecer(tester);
    // O escopo fica acima do MaterialApp, como em main.dart: uma rota empurrada
    // nasce no Navigator raiz e não enxergaria um escopo posto dentro do home.
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: Estado(await SharedPreferences.getInstance()),
        child: const MaterialApp(home: TelaBiblia()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(find.byType(TelaBusca), findsOneWidget);
  });

  testWidgets('dentro da moldura, a seta só vale depois de abrir a aba Bíblia', (
    tester,
  ) async {
    await aquecer(tester);
    final estado = Estado(await SharedPreferences.getInstance());
    await tester.pumpWidget(AppDevocional(estado: estado));
    await tester.pumpAndSettle();

    // Abre em Hoje. A aba Bíblia está viva no IndexedStack, mas não na frente:
    // a tecla não pode virar capítulo por trás de outra tela.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      estado.ultimaLeitura,
      isNull,
      reason: 'a aba escondida não pode responder ao teclado',
    );

    await tester.tap(find.text('Bíblia').last);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(
      estado.ultimaLeitura,
      ('genesis', 2),
      reason:
          'trocar de aba precisa entregar o foco ao conteúdo, senão o '
          'atalho só funcionaria depois de clicar no texto, que abre a folha '
          'de ações do versículo',
    );
  });
}
