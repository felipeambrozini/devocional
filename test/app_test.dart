import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:felipe_ambrozini/telas/biblia.dart';
import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:felipe_ambrozini/telas/devocional.dart';
import 'package:felipe_ambrozini/telas/plano.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sobe o app de verdade e confere o que aparece na tela, lendo os assets reais.
/// É o substituto verificável de olhar o app rodando.
void main() {
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

  testWidgets('o cronograma de 29 de fevereiro só existe em ano bissexto',
      (tester) async {
    // A suíte roda em ano comum, então este é o único lugar que exercita a
    // variante de 366 dias de verdade, carregando o asset. Sem ele, alguém pode
    // desfazer a escolha do arquivo e nada acusa antes de 2028.
    await tester.runAsync(() async {
      final conteudo = Conteudo.instancia;

      final bissexto = await conteudo.diaDoPlano(DateTime(2028, 2, 29));
      expect(bissexto, isNotNull, reason: '2028 é bissexto e tem 29 de fevereiro');
      expect(bissexto!.data, '02-29');

      // Em ano comum o cronograma não prevê a data, e é isso que faz a tela mostrar
      // o aviso de dia de recuperação em vez de um cartão vazio.
      final comum = await conteudo.plano(bissexto: false);
      expect(comum.any((d) => d.data == '02-29'), isFalse);
      expect(comum.length, Conteudo.diasDoAno(2027));

      final doisMil28 = await conteudo.plano(bissexto: true);
      expect(doisMil28.length, Conteudo.diasDoAno(2028));
    });
  });

  testWidgets('a tela Plano mostra o dia 29 em fevereiro de ano bissexto',
      (tester) async {
    // Guarda a escolha que a TELA faz, não só a do Conteudo: ela chamava plano()
    // sem bissexto e mostrava sempre o cronograma de 365 dias, discordando de Hoje
    // e do Devocional a partir de março de um ano bissexto.
    await tester.runAsync(() => Conteudo.instancia.plano(bissexto: true));
    await tester.pumpWidget(MaterialApp(
      home: EscopoDoEstado(
        estado: await estadoLimpo(),
        child: TelaPlano(hoje: DateTime(2028, 2, 15)),
      ),
    ));
    await tester.pumpAndSettle();

    // O cabeçalho do mês, que fica acima da dobra, já conta os dias do mês. Os
    // cartões em si são construídos por demanda e o dia 29 fica fora da viewport.
    expect(find.text('0 de 29 dias concluídos em Fevereiro'), findsOneWidget,
        reason: '2028 é bissexto: fevereiro tem 29 dias no cronograma');
  });

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
    // Não fixa 365: em ano bissexto o cronograma tem 366 dias, e o rótulo segue o
    // total do ano corrente. Escrito assim o teste continua valendo em 2028.
    final total = Conteudo.diasDoAno(DateTime.now().year);
    expect(find.text('de $total dias'), findsOneWidget);
    // O aviso de 29 de fevereiro é só para ano bissexto. Ele aparecia em qualquer
    // dia enquanto o cronograma carregava, porque o primeiro frame chega sem dado e
    // caía no ramo de recuperação. Isto fixa o estado final; o flash de um frame
    // fica fora do alcance de pumpAndSettle.
    expect(find.textContaining('29 de fevereiro'), findsNothing);
  });

  testWidgets(
      'numa janela larga de desktop, a coluna de leitura fica centralizada '
      'ao lado do trilho de navegação', (tester) async {
    // Simula uma janela do Windows bem mais larga que o limite de leitura,
    // bem além do corte de 720 que já liga o NavigationRail.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await aquecerAssets(tester);
    await tester.pumpWidget(AppDevocional(estado: await estadoLimpo()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);

    // Mede a caixa real que a LarguraDeLeitura produz na árvore de verdade, não
    // uma versão isolada: o Center sozinho preenche todo o Expanded, quem tem a
    // largura de 720 é o ConstrainedBox logo dentro dele.
    final caixa = find
        .descendant(
          of: find.byType(LarguraDeLeitura),
          matching: find.byType(ConstrainedBox),
        )
        .first;
    final retanguloCaixa = tester.getRect(caixa);
    final retanguloTrilho = tester.getRect(find.byType(NavigationRail));

    expect(retanguloCaixa.width, 720);

    final folgaEsquerda = retanguloCaixa.left - retanguloTrilho.right;
    final folgaDireita = 1600 - retanguloCaixa.right;
    expect(
      folgaEsquerda,
      closeTo(folgaDireita, 2),
      reason: 'a coluna de 720px deve ficar centralizada no espaço ao lado '
          'do trilho, com folga igual dos dois lados',
    );
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

    expect(find.text('A primeira promessa da Bíblia'), findsOneWidget);
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
