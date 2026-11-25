import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/personas.dart';
import 'package:devocional/telas/chat.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O aviso de plano concluído e os avisos com "Desfazer": o cartão da Hoje, o
/// cronograma e o chat.

void main() {
  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // O cronograma só existe com conta.
    Nuvem.instancia.logadoForcado = true;
  });
  tearDown(() => Nuvem.instancia.logadoForcado = null);

  Future<Estado> abrir() async => Estado(await SharedPreferences.getInstance());

  group('cartão do plano na Hoje', () {
    Future<(Estado, String)> montar(WidgetTester tester) async {
      final estado = await abrir();
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
            home: Scaffold(
              body: SingleChildScrollView(
                child: ListenableBuilder(
                  listenable: estado,
                  builder: (_, _) =>
                      TabernaculoPlanosEmAndamento(estado: estado),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return (estado, plano.id);
    }

    testWidgets('marcar o último dia avisa que o plano foi concluído', (
      tester,
    ) async {
      final (estado, id) = await montar(tester);
      expect(find.byType(TabernaculoBotaoDeLido), findsOneWidget);
      expect(find.text('Você concluiu o plano Cartas'), findsNothing);

      await tester.tap(find.byType(TabernaculoBotaoDeLido));
      await tester.pump();
      await tester.pump();

      expect(estado.foiLidoNoPlano(id, 2), isTrue);
      // O plano deixou de estar em andamento e o cartão saiu da tela, mas o
      // aviso continua.
      expect(find.byType(TabernaculoBotaoDeLido), findsNothing);
      expect(find.text('Você concluiu o plano Cartas'), findsOneWidget);
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('plano ainda em andamento não mostra o cartão nem o aviso', (
      tester,
    ) async {
      final estado = await abrir();
      await estado.criarPlano(
        titulo: 'Parado',
        livros: ['2joao', '3joao'],
        dias: 2,
      );
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Scaffold(body: TabernaculoPlanosEmAndamento(estado: estado)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TabernaculoBotaoDeLido), findsNothing);
      expect(find.text('Você concluiu o plano Parado'), findsNothing);
    });
  });

  group('aba do cronograma', () {
    testWidgets('tocar marca o dia com Desfazer, e o Desfazer desmarca', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => Conteudo.instancia.plano(bissexto: false));
      final estado = await abrir();
      final hoje = DateTime(2026, 3, 1);
      final chave = Estado.chaveDeLeitura(2026, '01-03');

      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Scaffold(body: TabernaculoAbaDoCronograma(hoje: hoje)),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump();
      expect(estado.foiLido(chave), isFalse);

      await tester.tap(find.text('Marcar como lido').first);
      await tester.pump();
      await tester.pump();

      expect(estado.foiLido(chave), isTrue);
      expect(find.text('Dia marcado como lido'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Desfazer'));
      await tester.pump();

      expect(estado.foiLido(chave), isFalse);
      await tester.pump(const Duration(seconds: 12));
    });
  });

  group('apagar a conversa pelo chat', () {
    testWidgets('mostra "Conversa apagada" e o Desfazer restaura', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'maior_de_idade': true});
      final estado = await abrir();
      final conversa = await estado.novaConversa(
        personaSpurgeon.id,
        titulo: 'O que é fé?',
      );
      await estado.registrarMensagem(
        personaSpurgeon.id,
        conversa.id,
        Mensagem(
          id: 'm1',
          papel: Mensagem.papelUsuario,
          texto: 'O que é fé?',
          momento: 1,
        ),
      );
      await estado.registrarMensagem(
        personaSpurgeon.id,
        conversa.id,
        Mensagem(
          id: 'm2',
          papel: Mensagem.papelAssistente,
          texto: 'Fé é a certeza das coisas.',
          momento: 2,
        ),
      );

      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TelaChat(
                        persona: personaSpurgeon,
                        conversaId: conversa.id,
                      ),
                    ),
                  ),
                  child: const Text('Abrir chat'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir chat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      await tester.tap(find.byTooltip('Apagar esta conversa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Apagar'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(estado.conversasDe(personaSpurgeon.id), isEmpty);
      // O chat saiu da tela e o aviso ficou na de baixo.
      expect(find.byType(TelaChat), findsNothing);
      expect(find.text('Conversa apagada'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Desfazer'));
      await tester.pump();
      await tester.pump();

      final restauradas = estado.conversasDe(personaSpurgeon.id);
      expect(restauradas.map((c) => c.id), [conversa.id]);
      expect(estado.mensagensDe(personaSpurgeon.id, conversa.id), hasLength(2));
      await tester.pump(const Duration(seconds: 12));
    });
  });
}
