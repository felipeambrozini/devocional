import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// O defeito que este widget existe para impedir: `FutureBuilder` escrito com
/// `future:` chamando o carregamento dentro do `build` recebia um future novo a
/// cada redesenho e voltava para `waiting`. Como toda tela lê o Estado, favoritar
/// um versículo redesenhava a tela da Bíblia e o capítulo virava spinner.
void main() {
  testWidgets(
    'redesenhar com a mesma chave não refaz o future nem volta a carregar',
    (tester) async {
      var carregamentos = 0;
      final estados = <ConnectionState>[];
      late void Function() redesenhar;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              redesenhar = () => setState(() {});
              return CarregaUmaVez<String>(
                chave: 'fixa',
                carregar: () async {
                  carregamentos++;
                  return 'texto';
                },
                construir: (context, snap) {
                  estados.add(snap.connectionState);
                  return Text(snap.data ?? '...');
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(carregamentos, 1);
      expect(find.text('texto'), findsOneWidget);

      estados.clear();
      redesenhar();
      await tester.pump();

      expect(carregamentos, 1, reason: 'o future não deve ser refeito');
      expect(estados, isNotEmpty, reason: 'o teste só vale se houve redesenho');
      expect(
        estados,
        everyElement(equals(ConnectionState.done)),
        reason: 'não pode voltar para waiting: é isso que fazia a tela piscar',
      );
      expect(find.text('texto'), findsOneWidget);
    },
  );

  testWidgets('mudar a chave refaz o future', (tester) async {
    var carregamentos = 0;
    var chave = 'a';
    late void Function() trocarChave;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            trocarChave = () => setState(() => chave = 'b');
            return CarregaUmaVez<String>(
              chave: chave,
              carregar: () async {
                carregamentos++;
                return chave;
              },
              construir: (context, snap) => Text(snap.data ?? '...'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(carregamentos, 1);
    expect(find.text('a'), findsOneWidget);

    trocarChave();
    await tester.pumpAndSettle();

    expect(carregamentos, 2, reason: 'chave nova é pedido novo');
    expect(find.text('b'), findsOneWidget);
  });

  // Nenhuma tela olhava `hasError`, e o teste era `if (!snap.hasData)`: um asset
  // corrompido ou ausente deixava o spinner girando para sempre. As seis telas
  // agora distinguem os três estados, e todas dependem do erro chegar aqui.
  testWidgets('um carregamento que falha chega ao construtor como erro', (
    tester,
  ) async {
    final vistos = <(ConnectionState, bool)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CarregaUmaVez<String>(
          chave: 'quebra',
          carregar: () async => throw Exception('asset ausente'),
          construir: (context, snap) {
            vistos.add((snap.connectionState, snap.hasError));
            if (snap.hasError) return const AvisoDeErro();
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(vistos.last, (ConnectionState.done, true));
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'girar é promessa de que algo vai chegar; aqui não vai',
    );
    expect(find.text('Não foi possível carregar'), findsOneWidget);
  });
}
