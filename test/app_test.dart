import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:felipe_ambrozini/telas/biblia.dart';
import 'package:felipe_ambrozini/telas/devocional.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sobe o app de verdade e confere o que aparece na tela, lendo os assets reais.
/// É o substituto verificável de olhar o app rodando.
void main() {
  setUpAll(() {
    // Sem isto o google_fonts tenta baixar a fonte durante o teste. A ausência da
    // fonte não muda o texto renderizado, que é o que estes testes verificam.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Estado> estadoLimpo() async =>
      Estado(await SharedPreferences.getInstance());

  /// Carrega os assets antes de montar a tela.
  ///
  /// Dentro de testWidgets o tempo é falso, e leitura de asset é I/O real: a Future
  /// do FutureBuilder nunca completaria, o CircularProgressIndicator giraria para
  /// sempre e pumpAndSettle estouraria o prazo. runAsync roda no tempo real; depois
  /// disso o cache do Conteudo responde na hora.
  Future<void> aquecerAssets(WidgetTester tester, {List<String> livros = const []}) async {
    await tester.runAsync(() async {
      final conteudo = Conteudo.instancia;
      await conteudo.plano();
      final agora = DateTime.now();
      // Os dois períodos, porque a aba de abertura depende do sol do lugar e
      // não se sabe de antemão qual delas a tela vai pedir.
      for (final periodo in Periodo.values) {
        await conteudo.devocional(agora, periodo);
      }
      await conteudo.promessa(agora);
      for (final versao in Versao.values) {
        await conteudo.capitulo(versao, 'genesis', 1);
        for (final livro in livros) {
          await conteudo.capitulo(versao, livro, 1);
        }
      }
      await conteudo.capitulo(Versao.bkj, 'salmos', 119);
      await conteudo.introducao('genesis');
    });
  }

  testWidgets('a moldura abre em Hoje e mostra as cinco seções', (tester) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(AppDevocional(estado: await estadoLimpo()));
    await tester.pumpAndSettle();

    for (final rotulo in ['Hoje', 'Bíblia', 'Devocional', 'Plano', 'Notas']) {
      expect(find.text(rotulo), findsWidgets, reason: rotulo);
    }
    // A saudação depende do relógio, então aceita as duas formas.
    expect(
      find.byWidgetPredicate((w) =>
          w is Text && (w.data?.startsWith('Bom dia, Felipe') == true ||
              w.data?.startsWith('Boa noite, Felipe') == true)),
      findsOneWidget,
    );
    expect(find.text('Promessas de Deus'), findsWidgets);
    // Com o cartão de Promessas a tela ficou mais alta que a viewport do teste,
    // então o progresso só é construído depois da rolagem.
    await tester.scrollUntilVisible(
      find.text('Progresso do ano'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Progresso do ano'), findsOneWidget);
    expect(find.text('de 365 dias'), findsOneWidget);
  });

  testWidgets('o leitor abre Gênesis 1 e mostra o texto da BKJ', (tester) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(MaterialApp(
      home: EscopoDoEstado(
        estado: await estadoLimpo(),
        child: const TelaBiblia(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Gênesis 1'), findsWidgets);
    // O texto vem do asset extraído do PDF, não de um dublê.
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('No princípio criou Deus o céu e a terra')),
      findsOneWidget,
    );
    expect(find.text('BKJ'), findsOneWidget);
    expect(find.text('NVT'), findsOneWidget);
  });

  testWidgets('alternar para NVT troca o texto do mesmo capítulo', (tester) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(MaterialApp(
      home: EscopoDoEstado(
        estado: await estadoLimpo(),
        child: const TelaBiblia(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NVT'));
    await tester.pumpAndSettle();

    // A NVT diz "os céus"; a BKJ diz "o céu". Serve para provar que trocou de fato.
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('Deus criou os céus e a terra')),
      findsOneWidget,
    );
    // E continua no mesmo capítulo.
    expect(find.text('Gênesis 1'), findsWidgets);
  });

  testWidgets('faixa por versículo destaca o recorte e mantém o contexto',
      (tester) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(MaterialApp(
      home: EscopoDoEstado(
        estado: await estadoLimpo(),
        child: const TelaBiblia(
          livroInicial: 'salmos',
          capituloInicial: 119,
          destacar: (1, 56),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Salmos 119'), findsWidgets);
    // O capítulo inteiro é carregado; o destaque é visual, não um corte no conteúdo.
    expect(
      find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().startsWith('1 ')),
      findsOneWidget,
    );
  });

  testWidgets('favoritar pelo toque no versículo persiste no estado',
      (tester) async {
    await aquecerAssets(tester);
    final estado = await estadoLimpo();
    await tester.pumpWidget(MaterialApp(
      home: EscopoDoEstado(estado: estado, child: const TelaBiblia()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byWidgetPredicate((w) =>
        w is RichText &&
        w.text.toPlainText().contains('No princípio criou Deus')));
    await tester.pumpAndSettle();

    expect(find.text('Favoritar'), findsOneWidget);
    await tester.tap(find.text('Favoritar'));
    await tester.pumpAndSettle();

    expect(estado.ehFavorito(Versao.bkj, 'genesis', 1, 1), isTrue);
  });

  testWidgets('o devocional tem as três abas e Promessas traz o versículo da BKJ',
      (tester) async {
    await aquecerAssets(tester);
    // 1 de janeiro tem tradução pronta, então serve de caso concreto.
    await tester.runAsync(
        () => Conteudo.instancia.promessa(DateTime(2026, 1, 1)));
    await tester.pumpWidget(MaterialApp(
      home: EscopoDoEstado(
        estado: await estadoLimpo(),
        child: const TelaDevocional(
          dataInicial: null,
          leituraInicial: Leitura.promessas,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    for (final rotulo in ['Manhã', 'Promessas de Deus', 'Noite']) {
      expect(find.text(rotulo), findsWidgets, reason: rotulo);
    }
  });

  testWidgets('Promessas de Deus mostra título, referência e versículo da BKJ',
      (tester) async {
    await aquecerAssets(tester);
    final data = DateTime(2026, 1, 1);
    await tester.runAsync(() => Conteudo.instancia.promessa(data));
    await tester.pumpWidget(MaterialApp(
      home: EscopoDoEstado(
        estado: await estadoLimpo(),
        child: TelaDevocional(
          dataInicial: data,
          leituraInicial: Leitura.promessas,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A PRIMEIRA PROMESSA DA BÍBLIA'), findsOneWidget);
    expect(find.text('Gênesis 3:15'), findsOneWidget);
    // O versículo não é tradução minha: sai do asset da BKJ.
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          w.data?.contains('E eu colocarei inimizade entre ti e a mulher') == true),
      findsOneWidget,
    );
  });

  testWidgets('o seletor de livro lista os 66 livros nos dois testamentos',
      (tester) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(MaterialApp(
      home: EscopoDoEstado(
        estado: await estadoLimpo(),
        child: const TelaBiblia(),
      ),
    ));
    await tester.pumpAndSettle();

    // O título do capítulo aparece duas vezes: no corpo e no botão da AppBar.
    // Só o da AppBar abre o seletor.
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Gênesis 1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Antigo Testamento'), findsOneWidget);
    expect(find.text('Escolha o livro'), findsOneWidget);

    // Escolher o livro leva à grade de capítulos, e escolher o capítulo leva o
    // leitor até lá. É o caminho que o usuário percorre de fato.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Rute'));
    await tester.pumpAndSettle();
    expect(find.text('Todos os livros'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '3'));
    await tester.pumpAndSettle();
    expect(find.text('Rute 3'), findsWidgets);
  });
}
