import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/telas/meu_plano.dart';
import 'package:felipe_ambrozini/widgets/faixa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regressão do achado "índice nunca aquece ao abrir um plano existente":
/// [Conteudo] é um singleton de vida do processo, e por muito tempo só
/// `TelaNovoPlano.initState` chamava `aquecerIndiceDeDevocionais`. Quem abria
/// direto um plano já criado (ou por link) nunca aquecia o índice, e
/// `devocionaisDoCapitulo` ficava devolvendo `[]` a sessão toda.
///
/// Este arquivo é deliberadamente separado de planos_test.dart: aquele tem um
/// `setUpAll` que aquece o índice para todo o arquivo (necessário para os
/// outros testes), o que tornaria um teste de "abriu frio" sempre verde,
/// aquecido ou não pela própria tela. Aqui, dentro do processo/isolate deste
/// arquivo, nada além de [TelaDeUmPlano] chama `aquecerIndiceDeDevocionais`.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'abrir um plano existente aquece o índice e os devocionais aparecem',
    (tester) async {
      final estado = Estado(await SharedPreferences.getInstance());
      final plano = await estado.criarPlano(
        titulo: '',
        livros: ['genesis'],
        dias: 50,
        incluirDevocionais: true,
      );

      // O aquecimento que o initState da tela dispara é I/O real (leitura de
      // asset), que nunca avança com o relógio falso do teste — daí montar
      // dentro de runAsync, como as demais telas que carregam asset fazem.
      // A tela mesma é quem chama aquecerIndiceDeDevocionais aqui dentro;
      // nada neste teste chama isso por fora, senão o teste passaria mesmo
      // sem a tela fazer sua parte.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: EscopoDoEstado(
              estado: estado,
              child: TelaDeUmPlano(
                estado: estado,
                planoId: plano.id,
                plano: plano,
              ),
            ),
          ),
        );
        final relogio = Stopwatch()..start();
        while (Conteudo.instancia.devocionaisDoCapitulo('genesis', 1).isEmpty &&
            relogio.elapsed < const Duration(seconds: 5)) {
          await Future.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();

      // Gênesis 1 é citado por devocionais reais de Manhã e Noite de 05-01
      // (ver test/conteudo_test.dart); se a tela não aquecesse o índice,
      // nenhum BotaoDeDevocional apareceria mesmo depois do índice global
      // estar pronto, porque a tela nunca reconstruiria para lê-lo de novo.
      expect(find.byType(BotaoDeDevocional), findsWidgets);
    },
  );
}
