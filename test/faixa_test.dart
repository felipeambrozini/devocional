import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/telas/biblia.dart';
import 'package:felipe_ambrozini/telas/faixa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O botão do cronograma que abre a Bíblia na faixa pedida.
///
/// Dentro de testWidgets o tempo é falso, e leitura de asset é I/O real (ver
/// app_test.dart): o capítulo é aquecido de antemão para o TelaBiblia
/// empurrado responder sem esperar o disco no tempo do teste.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> aquecer(WidgetTester tester) => tester.runAsync(() async {
    await Conteudo.instancia.capitulo(Versao.bkj, 'salmos', 119);
  });

  Future<void> abrirComFaixa(WidgetTester tester, Faixa faixa) async {
    await aquecer(tester);
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: Estado(await SharedPreferences.getInstance()),
        child: MaterialApp(
          home: Scaffold(body: BotaoDeFaixa(faixa: faixa)),
        ),
      ),
    );
    await tester.tap(find.byType(BotaoDeFaixa));
    await tester.pumpAndSettle();
  }

  testWidgets('faixa por versículo abre o capítulo com o recorte', (
    tester,
  ) async {
    final faixa = Faixa(
      livro: 'salmos',
      deCapitulo: 119,
      ateCapitulo: 119,
      deVersiculo: 1,
      ateVersiculo: 56,
    );

    await abrirComFaixa(tester, faixa);

    expect(find.byType(TelaBiblia), findsOneWidget);
    // Aparece na barra do leitor e no cabeçalho do capítulo.
    expect(find.text('Salmos 119'), findsWidgets);
    // O versículo 1 é o alvo do recorte e aparece inteiro na tela.
    expect(
      find.textContaining('Bem-aventurados os irrepreensíveis'),
      findsOneWidget,
    );
  });

  testWidgets('faixa de capítulo abre o capítulo sem recorte', (tester) async {
    final faixa = Faixa(
      livro: 'salmos',
      deCapitulo: 119,
      ateCapitulo: 119,
    );

    await abrirComFaixa(tester, faixa);

    expect(find.byType(TelaBiblia), findsOneWidget);
    // Aparece na barra do leitor e no cabeçalho do capítulo.
    expect(find.text('Salmos 119'), findsWidgets);
  });
}