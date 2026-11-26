import 'package:devocional/controladores/notas_controlador.dart';
import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/leitura_de_livros.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/telas/notas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A visão `?aba=todas` do perfil: favoritos e notas das três origens juntos,
/// cada item com o rótulo de onde veio.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Nuvem.instancia.logadoForcado = true;
  });
  tearDown(() => Nuvem.instancia.logadoForcado = null);

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

  Future<void> montar(
    WidgetTester tester,
    Estado estado,
    OrigemDasNotas origem,
  ) async {
    await tester.runAsync(() => Conteudo.instancia.capitulo('joao', 3));
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: MaterialApp(home: TelaNotas(origem: origem)),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('o parâmetro todas é reconhecido', () {
    expect(OrigemDasNotas.doParametro('todas'), OrigemDasNotas.todas);
  });

  testWidgets(
    'todas junta favoritos da Bíblia, do Devocional e da Biblioteca',
    (tester) async {
      await montar(tester, await estadoMisturado(), OrigemDasNotas.todas);

      expect(find.text('Favoritos (3)'), findsOneWidget);
      expect(find.text('Notas (1)'), findsOneWidget);
      expect(find.textContaining('João 3:16'), findsOneWidget);
      expect(find.text('Manhã, 17 de novembro'), findsOneWidget);
      expect(find.text('Respigas entre os Feixes, capítulo 1'), findsOneWidget);
    },
  );

  testWidgets('todas indica a origem de cada item', (tester) async {
    await montar(tester, await estadoMisturado(), OrigemDasNotas.todas);

    expect(find.text('Bíblia'), findsOneWidget);
    expect(find.text('Devocional'), findsOneWidget);
    expect(find.text('Respigas entre os Feixes'), findsOneWidget);
  });

  testWidgets('a busca filtra nas três origens', (tester) async {
    await montar(tester, await estadoMisturado(), OrigemDasNotas.todas);

    await tester.enterText(find.byType(TextField), 'respigas');
    await tester.pumpAndSettle();
    expect(find.text('Favoritos (1)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'manhã');
    await tester.pumpAndSettle();
    expect(find.text('Favoritos (1)'), findsOneWidget);
    expect(find.text('Manhã, 17 de novembro'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'joão');
    await tester.pumpAndSettle();
    expect(find.text('Favoritos (1)'), findsOneWidget);
    expect(find.textContaining('João 3:16'), findsOneWidget);
  });

  testWidgets('remover um item em todas remove na origem certa', (
    tester,
  ) async {
    final estado = await estadoMisturado();
    await montar(tester, estado, OrigemDasNotas.todas);

    Future<void> remover(String referencia) async {
      await tester.tap(find.byTooltip('Remover $referencia dos favoritos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
    }

    await remover('Manhã, 17 de novembro');
    expect(estado.leituraDeLivros.todosOsDestaques.length, 1);
    expect(estado.marcacoes.length, 1);

    await remover('Respigas entre os Feixes, capítulo 1');
    expect(estado.leituraDeLivros.todosOsDestaques, isEmpty);
    expect(estado.marcacoes.length, 1);

    await remover('João 3:16');
    expect(estado.marcacoes, isEmpty);
    expect(find.text('Favoritos (0)'), findsOneWidget);
  });

  testWidgets('a tela por aba continua mostrando só a sua origem', (
    tester,
  ) async {
    await montar(tester, await estadoMisturado(), OrigemDasNotas.devocional);

    expect(find.text('Favoritos (1)'), findsOneWidget);
    expect(find.text('Manhã, 17 de novembro'), findsOneWidget);
    expect(find.text('Devocional'), findsNothing);
    expect(find.byIcon(FontAwesomeIcons.trash.data), findsOneWidget);
  });
}
