import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/dados/personas.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Os widgets que juntaram duas ou mais cópias num só: o cartão de nota (Bíblia
/// e livros), o item de achado (as duas abas da busca), a fala da persona
/// (resposta, "pensando" e erro), o botão de entrar, a caixa de citação e os
/// avisos. O comportamento que cada cópia tinha, e as diretrizes de
/// acessibilidade do `flutter_test` nos dois temas.

const _temas = {'claro': Brightness.light, 'escuro': Brightness.dark};

final _diretrizes = <String, AccessibilityGuideline>{
  'o alvo de toque de 48 dp': androidTapTargetGuideline,
  'o rótulo em todo alvo de toque': labeledTapTargetGuideline,
  'o contraste de texto': textContrastGuideline,
};

Future<void> _montar(
  WidgetTester tester,
  Brightness brilho,
  List<Widget> filhos,
) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final estado = Estado(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    EscopoDoEstado(
      estado: estado,
      child: MaterialApp(
        theme: construirTema(brilho: brilho),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final filho in filhos) ...[
                  filho,
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

DevocionalCartaoDeNota _cartao({
  VoidCallback? aoAbrir,
  Future<void> Function(String)? aoSalvarNota,
  Future<void> Function()? aoRemover,
  Future<String> Function()? carregarTexto,
  int? maxLinhas,
}) => DevocionalCartaoDeNota(
  referencia: 'João 3:16',
  chaveDoTexto: 'joao-3-16',
  carregarTexto:
      carregarTexto ?? () async => 'Porque Deus amou o mundo de tal maneira.',
  nota: 'Lembrar disto de manhã.',
  mostrarNota: true,
  maxLinhas: maxLinhas,
  aoAbrir: aoAbrir ?? () {},
  aoSalvarNota: aoSalvarNota ?? (_) async {},
  aoRemover: aoRemover ?? () async {},
);

Mensagem _mensagem(String papel, String texto) => Mensagem(
  id: texto,
  papel: papel,
  texto: texto,
  momento: DateTime(2026, 11, 17).millisecondsSinceEpoch,
);

List<Widget> _todos() => [
  _cartao(),
  DevocionalItemDeAchado(
    titulo: 'Manhã · 17 de novembro',
    subtitulo: 'A graça que basta',
    texto: 'A minha graça te basta, porque o meu poder se aperfeiçoa.',
    termo: 'graça',
    aoAbrir: () {},
  ),
  DevocionalBalcaoDeMensagem(
    mensagem: _mensagem(Mensagem.papelUsuario, 'Como orar melhor?'),
    persona: personaSpurgeon,
  ),
  DevocionalBalcaoDeMensagem(
    mensagem: _mensagem(Mensagem.papelAssistente, 'Ore com as Escrituras.'),
    persona: personaSpurgeon,
  ),
  DevocionalErroDeResposta(
    persona: personaSpurgeon,
    mensagem: 'A resposta não veio.',
    aoTentarDeNovo: () async {},
  ),
  const DevocionalCaixaDeCitacao(
    expandir: true,
    child: Text('Uma frase de abertura.'),
  ),
  const DevocionalComentarioNoCapitulo(texto: 'O amor de Deus é o começo.'),
  const DevocionalCartaoLeituraProgressoAviso(mensagem: 'Carregando...'),
  const DevocionalBotaoDeEntrar(),
  const DevocionalBotaoDeEntrar(rotulo: 'Entrar', discreto: true),
  SizedBox(height: 320, child: DevocionalAvisoDeErro(aoTentarDeNovo: () {})),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Nuvem.instancia.logadoForcado = false;
  });
  tearDown(() => Nuvem.instancia.logadoForcado = null);

  group('DevocionalCartaoDeNota', () {
    testWidgets('mostra referência, texto carregado e a nota', (tester) async {
      await _montar(tester, Brightness.dark, [_cartao()]);
      expect(find.text('João 3:16'), findsOneWidget);
      expect(
        find.text('Porque Deus amou o mundo de tal maneira.'),
        findsOneWidget,
      );
      expect(find.text('Lembrar disto de manhã.'), findsOneWidget);
    });

    testWidgets('texto que não carrega vira a linha de falha', (tester) async {
      await _montar(tester, Brightness.dark, [
        _cartao(carregarTexto: () async => throw StateError('sem asset')),
      ]);
      expect(
        find.text('Não foi possível carregar este texto.'),
        findsOneWidget,
      );
    });

    testWidgets('o toque abre e a lixeira remove depois de confirmar', (
      tester,
    ) async {
      var abriu = false;
      var removeu = false;
      await _montar(tester, Brightness.dark, [
        _cartao(
          aoAbrir: () => abriu = true,
          aoRemover: () async => removeu = true,
        ),
      ]);
      await tester.tap(find.text('João 3:16'));
      expect(abriu, isTrue);

      await tester.tap(find.byTooltip('Remover João 3:16 dos favoritos'));
      await tester.pumpAndSettle();
      expect(removeu, isFalse);
      await tester.tap(find.widgetWithText(DevocionalBotaoPrimario, 'Remover'));
      await tester.pumpAndSettle();
      expect(removeu, isTrue);
    });

    testWidgets('a lista vazia mostra o vazio', (tester) async {
      await _montar(tester, Brightness.dark, [
        SizedBox(
          height: 200,
          child: DevocionalListaDeNotas(
            quantidade: 0,
            construir: (_, _) => _cartao(),
            vazio: const Text('Nenhum favorito'),
          ),
        ),
      ]);
      expect(find.text('Nenhum favorito'), findsOneWidget);
    });
  });

  group('DevocionalItemDeAchado', () {
    testWidgets('sem subtítulo, só título e trecho; o toque abre', (
      tester,
    ) async {
      var abriu = false;
      await _montar(tester, Brightness.dark, [
        DevocionalItemDeAchado(
          titulo: 'João 3:16',
          texto: 'Porque Deus amou o mundo',
          termo: 'amou',
          aoAbrir: () => abriu = true,
        ),
      ]);
      expect(find.text('João 3:16'), findsOneWidget);
      await tester.tap(find.text('João 3:16'));
      expect(abriu, isTrue);
    });

    testWidgets('com subtítulo, mostra o título do devocional', (tester) async {
      await _montar(tester, Brightness.dark, [_todos()[1]]);
      expect(find.text('A graça que basta'), findsOneWidget);
    });
  });

  group('DevocionalFalaDaPersona', () {
    testWidgets('a resposta da persona é selecionável e traz a foto', (
      tester,
    ) async {
      await _montar(tester, Brightness.dark, [_todos()[3]]);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(DevocionalRetratoDePersona), findsOneWidget);
    });

    testWidgets('a pergunta do visitante não leva foto', (tester) async {
      await _montar(tester, Brightness.dark, [_todos()[2]]);
      expect(find.byType(DevocionalRetratoDePersona), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
    });
  });

  group('DevocionalAvisoDeErro', () {
    testWidgets('usa o detalhe padrão ou o passado', (tester) async {
      await _montar(tester, Brightness.dark, [
        SizedBox(
          height: 300,
          child: DevocionalAvisoDeErro(aoTentarDeNovo: () {}),
        ),
        SizedBox(
          height: 300,
          child: DevocionalAvisoDeErro(
            detalhe: 'A busca falhou. Tente de novo.',
            aoTentarDeNovo: () {},
          ),
        ),
      ]);
      expect(find.text('Verifique a conexão e tente de novo.'), findsOneWidget);
      expect(find.text('A busca falhou. Tente de novo.'), findsOneWidget);
    });
  });

  group('DevocionalBotaoDeEntrar', () {
    testWidgets('primário por padrão, secundário quando discreto', (
      tester,
    ) async {
      await _montar(tester, Brightness.dark, [
        const DevocionalBotaoDeEntrar(),
        const DevocionalBotaoDeEntrar(rotulo: 'Entrar', discreto: true),
      ]);
      expect(
        find.widgetWithText(DevocionalBotaoPrimario, 'Entrar com Google'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DevocionalBotaoSecundario, 'Entrar'),
        findsOneWidget,
      );
    });
  });

  group('acessibilidade dos widgets unificados', () {
    for (final MapEntry(key: nomeDoTema, value: brilho) in _temas.entries) {
      for (final MapEntry(key: nomeDaDiretriz, value: diretriz)
          in _diretrizes.entries) {
        testWidgets('no tema $nomeDoTema, atende $nomeDaDiretriz', (
          tester,
        ) async {
          final semantica = tester.ensureSemantics();
          await _montar(tester, brilho, _todos());
          await expectLater(tester, meetsGuideline(diretriz));
          semantica.dispose();
        });
      }
    }
  });
}
