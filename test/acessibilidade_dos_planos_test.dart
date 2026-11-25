import 'package:devocional/dados/estado.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Diretrizes de toque, rótulo e contraste, nos dois temas, para os widgets
/// de plano mexidos junto com a revisão do plano compartilhado e o aviso de
/// plano concluído: o cartão do plano na Hoje e a lista de participantes.

/// Um plano compartilhado já editado: a Ana está na revisão atual, o Bruno
/// ficou numa anterior (aparece zerado) e marcou um dia além do total.
Map<String, dynamic> _plano() => {
  'dias': 2,
  'revisao': 7,
  'criadoPor': 'ana',
  'participantes': {
    'ana': {
      'nome': 'Ana',
      'lidos': [1],
      'revisao': 7,
    },
    'bruno': {
      'nome': 'Bruno',
      'lidos': [1, 2, 3],
    },
  },
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brilho in Brightness.values) {
    testWidgets('cartão do plano e participantes no tema ${brilho.name}', (
      tester,
    ) async {
      final estado = Estado(await SharedPreferences.getInstance());
      final plano = await estado.criarPlano(
        titulo: 'Cartas',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      await estado.alternarLidoNoPlano(plano.id, 1);

      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            theme: construirTema(brilho: brilho),
            home: Scaffold(
              body: ListView(
                children: [
                  ListenableBuilder(
                    listenable: estado,
                    builder: (_, _) =>
                        TabernaculoPlanosEmAndamento(estado: estado),
                  ),
                  TabernaculoSecaoDeParticipantes(
                    dados: _plano(),
                    meuUid: 'ana',
                    totalDeDias: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TabernaculoBotaoDeLido), findsOneWidget);
      // O Bruno é de uma revisão anterior: seus dias não contam, e ninguém
      // passa do total.
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
      expect(find.text('3/2'), findsNothing);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
