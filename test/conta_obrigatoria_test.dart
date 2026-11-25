import 'package:devocional/dados/dia_da_leitura.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/funcoes/marcar_dia_da_leitura.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O cronograma anual e a leitura do dia só existem com conta: sem ela, o
/// lugar deles é um convite para entrar, e o fim do capítulo não marca nada.

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    Nuvem.instancia.logadoForcado = null;
    Nuvem.instancia.carregandoContaForcado = null;
  });

  Future<Estado> abrir() async => Estado(await SharedPreferences.getInstance());

  Future<void> montar(WidgetTester tester, Widget filho) async {
    final estado = await abrir();
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: MaterialApp(home: Scaffold(body: filho)),
      ),
    );
    await tester.pump();
  }

  testWidgets('sem conta, a aba do cronograma pede login', (tester) async {
    Nuvem.instancia.logadoForcado = false;

    await montar(
      tester,
      TabernaculoAbaDoCronograma(hoje: DateTime(2026, 3, 1)),
    );

    expect(find.text('Entre para ver o plano'), findsOneWidget);
    expect(find.byType(TabernaculoCartaoDeDia), findsNothing);
  });

  testWidgets('sem conta, a Hoje mostra o convite no lugar da leitura do dia', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;

    await montar(tester, TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)));

    expect(find.byType(TabernaculoCartaoDeEntrar), findsOneWidget);
    expect(find.byType(TabernaculoCartaoLeituraProgresso), findsNothing);
  });

  testWidgets('restaurando a conta, a Hoje não mostra o convite', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;
    Nuvem.instancia.carregandoContaForcado = true;

    await montar(tester, TabernaculoLeituraDeHoje(data: DateTime(2026, 3, 1)));

    expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
  });

  testWidgets('sem conta, chegar ao fim do capítulo não marca o dia', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrir();
    late BuildContext contexto;
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
    const chave = '2026-11-24';

    await marcarDiaDaLeituraAoTerminar(
      contexto,
      estado,
      const DiaDoCronograma(chave: chave, capitulos: ['joao.3']),
    );
    await tester.pump();

    expect(estado.foiLido(chave), isFalse);
  });
}
