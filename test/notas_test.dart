import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/telas/notas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Busca na tela de Marcações: filtra por referência e por texto da nota, não
/// pelo corpo do versículo, que é carregado sob demanda e ficaria fora do
/// alcance de uma busca em memória sem derrubar o carregamento tardio.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> aquecer(WidgetTester tester) => tester.runAsync(() async {
    final c = Conteudo.instancia;
    await c.capitulo(Versao.bkj, 'joao', 3);
    await c.capitulo(Versao.bkj, 'romanos', 8);
    await c.capitulo(Versao.bkj, 'salmos', 23);
  });

  Future<Estado> montar(WidgetTester tester, Estado estado) async {
    await aquecer(tester);
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: const MaterialApp(home: TelaNotas()),
      ),
    );
    await tester.pumpAndSettle();
    return estado;
  }

  testWidgets('sem termo, a lista mostra tudo', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
    await estado.alternarFavorito(Versao.bkj, 'romanos', 8, 28);
    await montar(tester, estado);

    expect(find.text('Favoritos (2)'), findsOneWidget);
  });

  testWidgets('busca por trecho da referência filtra a lista', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
    await estado.alternarFavorito(Versao.bkj, 'romanos', 8, 28);
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'joão');
    await tester.pumpAndSettle();

    expect(find.text('Favoritos (1)'), findsOneWidget);
    expect(find.textContaining('João 3:16'), findsOneWidget);
    expect(find.textContaining('Romanos'), findsNothing);
  });

  testWidgets('a busca ignora acento e caixa', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'JOAO');
    await tester.pumpAndSettle();

    expect(find.text('Favoritos (1)'), findsOneWidget);
  });

  testWidgets('busca por trecho da anotação filtra a aba de anotações', (
    tester,
  ) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.definirNota(Versao.bkj, 'joao', 3, 16, 'o amor de Deus');
    await estado.definirNota(
      Versao.bkj,
      'salmos',
      23,
      1,
      'o Senhor é meu pastor',
    );
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'pastor');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notas (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Salmos 23:1'), findsOneWidget);
    expect(find.textContaining('João 3:16'), findsNothing);
  });

  testWidgets('sem achado, mostra o aviso de nada encontrado', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'apocalipse');
    await tester.pumpAndSettle();

    expect(find.text('Favoritos (0)'), findsOneWidget);
    expect(find.text('Nada encontrado'), findsOneWidget);
  });

  testWidgets('limpar a busca devolve a lista inteira', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
    await estado.alternarFavorito(Versao.bkj, 'romanos', 8, 28);
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'joão');
    await tester.pumpAndSettle();
    expect(find.text('Favoritos (1)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Favoritos (2)'), findsOneWidget);
  });
}
