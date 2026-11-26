import 'dart:async';

import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/telas/notas.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abrir sem Firebase (a web sem rede não baixa o SDK): a conta resolve pela
/// última sessão confirmada neste aparelho, e nunca fica em "Verificando sua
/// conta" para sempre (ver `Nuvem.prazoDaSessao`).
void main() {
  tearDown(() => Nuvem.instancia.redefinirParaTestes());

  Future<Estado> abrirCom(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final estado = await Estado.abrir();
    await estado.alternarFavorito('joao', 3, 16);
    return estado;
  }

  Future<void> montarNotas(WidgetTester tester, Estado estado) async {
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: const MaterialApp(home: TelaNotas()),
      ),
    );
    await tester.pump();
  }

  void firebaseQueFalha() =>
      Nuvem.instancia.iniciarFirebaseForcado = () =>
          Future.error(Exception('SDK do Firebase não baixou'));

  testWidgets('com a última sessão logada, as notas mostram a cópia local', (
    tester,
  ) async {
    final estado = await abrirCom({Nuvem.chaveDaUltimaSessao: 'conta-a'});
    firebaseQueFalha();

    await tester.runAsync(() => Nuvem.instancia.iniciar(estado));
    await montarNotas(tester, estado);

    expect(Nuvem.instancia.carregandoConta, isFalse);
    expect(Nuvem.instancia.logado, isTrue);
    expect(Nuvem.instancia.uid, 'conta-a');
    expect(find.text('Favoritos (1)'), findsOneWidget);
    expect(find.byType(TabernaculoVerificandoConta), findsNothing);
  });

  testWidgets('sem última sessão, as notas mostram o convite', (tester) async {
    final estado = await abrirCom({});
    firebaseQueFalha();

    await tester.runAsync(() => Nuvem.instancia.iniciar(estado));
    await montarNotas(tester, estado);

    expect(Nuvem.instancia.carregandoConta, isFalse);
    expect(Nuvem.instancia.logado, isFalse);
    expect(find.text('Entre para ver favoritos e notas'), findsOneWidget);
    expect(find.byType(TabernaculoVerificandoConta), findsNothing);
  });

  testWidgets('Firebase que não responde: a espera acaba no prazo', (
    tester,
  ) async {
    final estado = await abrirCom({Nuvem.chaveDaUltimaSessao: 'conta-a'});
    final nunca = Completer<void>();
    Nuvem.instancia.iniciarFirebaseForcado = () => nunca.future;

    unawaited(Nuvem.instancia.iniciar(estado));
    await montarNotas(tester, estado);
    expect(find.byType(TabernaculoVerificandoConta), findsOneWidget);

    await tester.pump(Nuvem.prazoDaSessao);
    // A leitura da última sessão nas prefs é assíncrona.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(Nuvem.instancia.carregandoConta, isFalse);
    expect(find.byType(TabernaculoVerificandoConta), findsNothing);
    expect(find.text('Favoritos (1)'), findsOneWidget);
  });

  test('sem Firebase, o Sair falha e nada sai do aparelho', () async {
    final estado = await abrirCom({Nuvem.chaveDaUltimaSessao: 'conta-a'});
    firebaseQueFalha();
    await Nuvem.instancia.iniciar(estado);

    await expectLater(
      Nuvem.instancia.sair(),
      throwsA(isA<SairDaContaFalhou>()),
    );

    expect(estado.ehFavorito('joao', 3, 16), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Nuvem.chaveDaUltimaSessao), 'conta-a');
  });

  test('a inicialização do Firebase é pedida uma vez só', () async {
    var chamadas = 0;
    final nunca = Completer<void>();
    Nuvem.instancia.iniciarFirebaseForcado = () {
      chamadas++;
      return nunca.future;
    };

    unawaited(Nuvem.instancia.iniciarFirebase());
    unawaited(Nuvem.instancia.iniciarFirebase());

    expect(chamadas, 1);
  });
}
