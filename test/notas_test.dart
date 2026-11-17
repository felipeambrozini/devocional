import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/controladores/notas_controlador.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/leitura_de_livros.dart';
import 'package:devocional/telas/notas.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Busca na tela de Marcações: filtra por referência e por texto da nota, não
/// pelo corpo do versículo, que é carregado sob demanda e ficaria fora do
/// alcance de uma busca em memória sem derrubar o carregamento tardio.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> aquecer(WidgetTester tester) => tester.runAsync(() async {
    final c = Conteudo.instancia;
    await c.capitulo('joao', 3);
    await c.capitulo('romanos', 8);
    await c.capitulo('salmos', 23);
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
    await estado.alternarFavorito('joao', 3, 16);
    await estado.alternarFavorito('romanos', 8, 28);
    await montar(tester, estado);

    expect(find.text('Favoritos (2)'), findsOneWidget);
  });

  testWidgets('busca por trecho da referência filtra a lista', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito('joao', 3, 16);
    await estado.alternarFavorito('romanos', 8, 28);
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'joão');
    await tester.pumpAndSettle();

    expect(find.text('Favoritos (1)'), findsOneWidget);
    expect(find.textContaining('João 3:16'), findsOneWidget);
    expect(find.textContaining('Romanos'), findsNothing);
  });

  testWidgets('a busca ignora acento e caixa', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito('joao', 3, 16);
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'JOAO');
    await tester.pumpAndSettle();

    expect(find.text('Favoritos (1)'), findsOneWidget);
  });

  testWidgets('busca por trecho da anotação filtra a aba de anotações', (
    tester,
  ) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.definirNota('joao', 3, 16, 'o amor de Deus');
    await estado.definirNota('salmos', 23, 1, 'o Senhor é meu pastor');
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'pastor');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notas (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Salmo 23:1'), findsOneWidget);
    expect(find.textContaining('João 3:16'), findsNothing);
  });

  testWidgets('sem achado, mostra o aviso de nada encontrado', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito('joao', 3, 16);
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'apocalipse');
    await tester.pumpAndSettle();

    expect(find.text('Favoritos (0)'), findsOneWidget);
    expect(find.text('Nada encontrado'), findsOneWidget);
  });

  testWidgets('limpar a busca devolve a lista inteira', (tester) async {
    final estado = Estado(await SharedPreferences.getInstance());
    await estado.alternarFavorito('joao', 3, 16);
    await estado.alternarFavorito('romanos', 8, 28);
    await montar(tester, estado);

    await tester.enterText(find.byType(TextField), 'joão');
    await tester.pumpAndSettle();
    expect(find.text('Favoritos (1)'), findsOneWidget);

    await tester.tap(find.byIcon(FontAwesomeIcons.xmark.data));
    await tester.pumpAndSettle();
    expect(find.text('Favoritos (2)'), findsOneWidget);
  });

  group('cada aba vê só as próprias notas', () {
    Future<Estado> montarDe(
      WidgetTester tester,
      Estado estado,
      OrigemDasNotas origem,
    ) async {
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(home: TelaNotas(origem: origem)),
        ),
      );
      await tester.pumpAndSettle();
      return estado;
    }

    Future<Estado> estadoMisturado() async {
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.alternarFavorito('joao', 3, 16);
      await estado.leituraDeLivros.alternarDestaque(
        slugDoDevocional('manha'),
        diaDoDevocional(DateTime(2025, 11, 17)),
        paragrafoDoDevocional,
      );
      await estado.leituraDeLivros.definirNota(
        'respigas_entre_os_feixes',
        0,
        0,
        'ilustração boa',
      );
      return estado;
    }

    testWidgets('Bíblia não mostra devocional nem livro', (tester) async {
      await montarDe(tester, await estadoMisturado(), OrigemDasNotas.biblia);

      expect(find.text('Favoritos (1)'), findsOneWidget);
      expect(find.text('Notas (0)'), findsOneWidget);
    });

    testWidgets('Devocional mostra só a leitura favoritada', (tester) async {
      await montarDe(
        tester,
        await estadoMisturado(),
        OrigemDasNotas.devocional,
      );

      expect(find.text('Favoritos (1)'), findsOneWidget);
      expect(find.text('Notas (0)'), findsOneWidget);
      expect(find.text('Manhã, 17 de novembro'), findsOneWidget);
    });

    testWidgets('Biblioteca mostra só o livro, com a nota', (tester) async {
      await montarDe(
        tester,
        await estadoMisturado(),
        OrigemDasNotas.biblioteca,
      );

      expect(find.text('Favoritos (1)'), findsOneWidget);
      expect(find.text('Notas (1)'), findsOneWidget);
      expect(find.text('Respigas entre os Feixes, capítulo 1'), findsOneWidget);
    });

    test('o parâmetro da rota desconhecido cai na Bíblia', () {
      expect(
        OrigemDasNotas.doParametro('devocional'),
        OrigemDasNotas.devocional,
      );
      expect(OrigemDasNotas.doParametro('lixo'), OrigemDasNotas.biblia);
      expect(OrigemDasNotas.doParametro(null), OrigemDasNotas.biblia);
    });
  });
}
