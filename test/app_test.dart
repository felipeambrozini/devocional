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
import 'package:flutter/services.dart';
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
  Future<void> aquecerAssets(
    WidgetTester tester, {
    List<String> livros = const [],
  }) async {
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

  testWidgets('o cronograma de 29 de fevereiro só existe em ano bissexto', (
    tester,
  ) async {
    // A suíte roda em ano comum, então este é o único lugar que exercita a
    // variante de 366 dias de verdade, carregando o asset. Sem ele, alguém pode
    // desfazer a escolha do arquivo e nada acusa antes de 2028.
    await tester.runAsync(() async {
      final conteudo = Conteudo.instancia;

      final bissexto = await conteudo.diaDoPlano(DateTime(2028, 2, 29));
      expect(
        bissexto,
        isNotNull,
        reason: '2028 é bissexto e tem 29 de fevereiro',
      );
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

  testWidgets('a tela Plano mostra o dia 29 em fevereiro de ano bissexto', (
    tester,
  ) async {
    // Guarda a escolha que a TELA faz, não só a do Conteudo: ela chamava plano()
    // sem bissexto e mostrava sempre o cronograma de 365 dias, discordando de Hoje
    // e do Devocional a partir de março de um ano bissexto.
    await tester.runAsync(() => Conteudo.instancia.plano(bissexto: true));
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          child: TelaPlano(hoje: DateTime(2028, 2, 15)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // O mês corrente monta inteiro, para a tela poder rolar até o dia de hoje,
    // então dá para checar o próprio cartão do dia 29 em vez de inferir pela
    // contagem do cabeçalho, que a rolagem automática tira da vista.
    //
    // skipOffstage: false porque o cartão está montado mas fora da viewport, e é
    // exatamente isso que se quer provar: que o dia 29 existe no cronograma.
    expect(
      find.text('29', skipOffstage: false),
      findsOneWidget,
      reason: '2028 é bissexto: fevereiro tem 29 dias no cronograma',
    );
  });

  testWidgets('o Plano abre rolado até o dia de hoje no mês corrente', (
    tester,
  ) async {
    await tester.runAsync(() => Conteudo.instancia.plano(bissexto: true));
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          child: TelaPlano(hoje: DateTime(2028, 2, 25)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Dia 25: sem a rolagem automática seriam vinte e quatro cartões de distância,
    // e o cartão estaria montado mas fora da tela. Aqui ele precisa estar visível.
    final tela = tester.getRect(find.byType(TelaPlano));
    final cartao = tester.getRect(
      find.ancestor(of: find.text('25'), matching: find.byType(Card)),
    );
    expect(cartao.top, greaterThanOrEqualTo(tela.top));
    expect(cartao.bottom, lessThanOrEqualTo(tela.bottom));
  });

  testWidgets('o Plano não trava no ano em que foi aberto', (tester) async {
    await tester.runAsync(() async {
      await Conteudo.instancia.plano(bissexto: false);
      await Conteudo.instancia.plano(bissexto: true);
    });
    final estado = await estadoLimpo();
    Widget tela(DateTime hoje) => MaterialApp(
      home: EscopoDoEstado(estado: estado, child: TelaPlano(hoje: hoje)),
    );

    await tester.pumpWidget(tela(DateTime(2027, 12, 31)));
    await tester.pumpAndSettle();

    // Redesenha o MESMO widget com uma data nova, simulando o relógio andando
    // enquanto a tela ficou viva no IndexedStack da moldura (didUpdateWidget,
    // não um novo State). Antes do conserto, "_hoje" ficava presa em 2027.
    await tester.pumpWidget(tela(DateTime(2028, 1, 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Fevereiro'));
    await tester.pumpAndSettle();

    // 29 dias e não 28: prova que carregou o cronograma bissexto de 2028, não
    // o de 2027 que a tela tinha aberto com. Presa em 2027, a contagem diria
    // 28 (fevereiro comum) mesmo com o chip de fevereiro selecionado.
    expect(find.textContaining('de 29 dias concluídos em Fevereiro'), findsOneWidget);
  });

  testWidgets('a moldura abre em Hoje e mostra as cinco seções', (
    tester,
  ) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(AppDevocional(estado: await estadoLimpo()));
    await tester.pumpAndSettle();

    for (final rotulo in ['Hoje', 'Bíblia', 'Devocional', 'Plano', 'Notas']) {
      expect(find.text(rotulo), findsWidgets, reason: rotulo);
    }
    // A saudação depende do relógio, então aceita as três formas.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data?.startsWith('Bom dia, Felipe') == true ||
                w.data?.startsWith('Boa tarde, Felipe') == true ||
                w.data?.startsWith('Boa noite, Felipe') == true),
      ),
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

  testWidgets('numa janela larga de desktop, a coluna de leitura fica centralizada '
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
      reason:
          'a coluna de 720px deve ficar centralizada no espaço ao lado '
          'do trilho, com folga igual dos dois lados',
    );
  });

  testWidgets(
    'numa janela larga, a barra do leitor ocupa a janela e só o texto fica em coluna',
    (tester) async {
      // A LarguraDeLeitura já envolveu o IndexedStack inteiro, e então a AppBar
      // de cada aba também ficava presa em 720 px no meio da janela, com fundo
      // vazio dos dois lados: cara de celular colado no meio de um monitor.
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await aquecerAssets(tester);
      await tester.pumpWidget(AppDevocional(estado: await estadoLimpo()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bíblia').last);
      await tester.pumpAndSettle();

      final trilho = tester.getRect(find.byType(NavigationRail));
      final barra = tester.getRect(find.byType(AppBar));
      final coluna = tester.getRect(
        find
            .descendant(
              of: find.byType(LarguraDeLeitura),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );

      expect(
        barra.width,
        closeTo(1600 - trilho.width, 2),
        reason: 'a barra deve ir do trilho até a borda da janela',
      );
      expect(
        coluna.width,
        720,
        reason: 'só o texto é limitado, e ele continua limitado',
      );
    },
  );

  testWidgets('o leitor tem a mesma largura pela aba e por uma rota empurrada', (
    tester,
  ) async {
    // As rotas empurradas nascem no Navigator raiz, fora da moldura. Com a
    // LarguraDeLeitura no lugar errado elas ficavam de fora dela, e o mesmo
    // leitor tinha 720 px pela aba e a janela inteira pelo "Continuar leitura".
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await aquecerAssets(tester);
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: await estadoLimpo(),
        child: const MaterialApp(home: TelaBiblia()),
      ),
    );
    await tester.pumpAndSettle();

    final coluna = tester.getRect(
      find
          .descendant(
            of: find.byType(LarguraDeLeitura),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(coluna.width, 720);
    expect(coluna.center.dx, closeTo(800, 2), reason: 'centralizada na janela');
  });

  testWidgets('o leitor abre Gênesis 1 e mostra o texto da BKJ', (
    tester,
  ) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          child: const TelaBiblia(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gênesis 1'), findsWidgets);
    // O texto vem do asset extraído do PDF, não de um dublê.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains(
              'No princípio criou Deus o céu e a terra',
            ),
      ),
      findsOneWidget,
    );
    // O alternador da barra mostra só a sigla em uso e troca pela outra ao ser
    // tocado, em vez de exibir as duas lado a lado ocupando uma linha inteira.
    expect(find.text('BKJ'), findsOneWidget);
    expect(find.text('NVT'), findsNothing);
  });

  testWidgets('alternar para NVT troca o texto do mesmo capítulo', (
    tester,
  ) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          child: const TelaBiblia(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // O botão mostra a versão em uso e leva para a outra, então quem se toca
    // para chegar na NVT é o "BKJ".
    await tester.tap(find.text('BKJ'));
    await tester.pumpAndSettle();

    // A NVT diz "os céus"; a BKJ diz "o céu". Serve para provar que trocou de fato.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('Deus criou os céus e a terra'),
      ),
      findsOneWidget,
    );
    // E continua no mesmo capítulo, agora com a outra sigla na barra.
    expect(find.text('Gênesis 1'), findsWidgets);
    expect(find.text('NVT'), findsOneWidget);
  });

  testWidgets('faixa por versículo destaca o recorte e mantém o contexto', (
    tester,
  ) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          child: const TelaBiblia(
            livroInicial: 'salmos',
            capituloInicial: 119,
            destacar: (1, 56),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Salmos 119'), findsWidgets);
    // O capítulo inteiro é carregado; o destaque é visual, não um corte no conteúdo.
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith('1 '),
      ),
      findsOneWidget,
    );
  });

  testWidgets('favoritar pelo toque no versículo persiste no estado', (
    tester,
  ) async {
    await aquecerAssets(tester);
    final estado = await estadoLimpo();
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(estado: estado, child: const TelaBiblia()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('No princípio criou Deus'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favoritar'), findsOneWidget);
    await tester.tap(find.text('Favoritar'));
    await tester.pumpAndSettle();

    expect(estado.ehFavorito(Versao.bkj, 'genesis', 1, 1), isTrue);
  });

  testWidgets(
    'a folha do versículo tem Compartilhar, e Copiar usa o mesmo texto formatado',
    (tester) async {
      await aquecerAssets(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: await estadoLimpo(),
            child: const TelaBiblia(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('No princípio criou Deus'),
        ),
      );
      await tester.pumpAndSettle();

      // Compartilhar existe na folha. Não é tocado: share_plus fala com um
      // canal de plataforma que o ambiente de teste não tem handler para, e
      // tocar de verdade lançaria MissingPluginException. O texto que ele
      // manda é o mesmo de Copiar, testado abaixo.
      expect(find.text('Compartilhar'), findsOneWidget);

      // Handler próprio no canal de plataforma, e não Clipboard.getData: o
      // ambiente de teste responde Clipboard.setData mas nunca responde
      // Clipboard.getData, e a chamada trava para sempre em vez de lançar.
      // Capturando o argumento aqui, o teste nem depende desse comportamento.
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (chamada) async {
          if (chamada.method == 'Clipboard.setData') {
            copiado = (chamada.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();
      expect(
        copiado,
        '"No princípio criou Deus o céu e a terra."\nGênesis 1:1 (BKJ)\n'
        'https://felipeambrozini.github.io/felipe_ambrozini/?ler=genesis.1.1',
      );
    },
  );

  testWidgets('Apresentar abre o versículo em tela cheia e fecha ao tocar', (
    tester,
  ) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          child: const TelaBiblia(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('No princípio criou Deus'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apresentar'));
    await tester.pumpAndSettle();

    expect(find.text('No princípio criou Deus o céu e a terra.'), findsOneWidget);
    expect(find.text('Gênesis 1:1'), findsOneWidget);

    // Fecha ao tocar em qualquer lugar da tela, sem precisar do botão de voltar.
    await tester.tap(find.text('No princípio criou Deus o céu e a terra.'));
    await tester.pumpAndSettle();

    // De volta ao leitor: lá o versículo é RichText, não Text (ver o find
    // acima, no início do teste), então a apresentação já não está na tela.
    expect(find.text('Apresentar'), findsNothing);
    expect(find.text('No princípio criou Deus o céu e a terra.'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('No princípio criou Deus'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'o devocional tem as três abas e Promessas traz o versículo da BKJ',
    (tester) async {
      await aquecerAssets(tester);
      // 1 de janeiro tem tradução pronta, então serve de caso concreto.
      await tester.runAsync(
        () => Conteudo.instancia.promessa(DateTime(2026, 1, 1)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: await estadoLimpo(),
            child: const TelaDevocional(
              dataInicial: null,
              leituraInicial: Leitura.promessas,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final rotulo in ['Manhã', 'Promessas de Deus', 'Noite']) {
        expect(find.text(rotulo), findsWidgets, reason: rotulo);
      }
    },
  );

  testWidgets(
    'Manhã e Noite mostra o nome do livro por extenso em maiúsculas e o '
    'versículo completo da BKJ, não só a referência abreviada',
    (tester) async {
      await aquecerAssets(tester);
      final data = DateTime(2026, 1, 1);
      await tester.runAsync(
        () => Conteudo.instancia.devocional(data, Periodo.manha),
      );
      // Pré-aquece a introdução de Josué: sem isso a Future do CarregaUmaVez
      // nunca completa dentro do tempo falso do teste.
      await tester.runAsync(() => Conteudo.instancia.introducao('josue'));
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: await estadoLimpo(),
            child: TelaDevocional(
              dataInicial: data,
              leituraInicial: Leitura.manha,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // O nome do livro por extenso fica ao lado do fim da citação, dentro do
      // mesmo Text.rich, no lugar da abreviação crua do asset ("Js 5:12").
      expect(
        find.textContaining('JOSUÉ 5:12', findRichText: true),
        findsOneWidget,
      );
      // O versículo é o texto de verdade da BKJ, não a citação embutida no comentário.
      expect(
        find.textContaining(
          'mas naquele ano eles comeram do fruto da terra de Canaã',
          findRichText: true,
        ),
        findsOneWidget,
      );
      // Regressão: a referência em maiúsculas não pode impedir a introdução do
      // livro de aparecer entre o seletor e o texto do devocional, com o título
      // formal do livro ao lado.
      expect(
        find.text('Introdução — ${livroPorSlug('josue')!.tituloFormal}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Promessas de Deus mostra título, referência e versículo da BKJ',
    (tester) async {
      await aquecerAssets(tester);
      final data = DateTime(2026, 1, 1);
      await tester.runAsync(() => Conteudo.instancia.promessa(data));
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: await estadoLimpo(),
            child: TelaDevocional(
              dataInicial: data,
              leituraInicial: Leitura.promessas,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A primeira promessa da Bíblia'), findsOneWidget);
      // O nome do livro também aparece em maiúsculas aqui, igual ao Manhã e
      // Noite, ao lado do fim da citação.
      expect(
        find.textContaining('GÊNESIS 3:15', findRichText: true),
        findsOneWidget,
      );
      // O versículo não é tradução minha: sai do asset da BKJ.
      expect(
        find.textContaining(
          'E eu colocarei inimizade entre ti e a mulher',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('o seletor de livro lista os 66 livros nos dois testamentos', (
    tester,
  ) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          child: const TelaBiblia(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // O título do capítulo aparece duas vezes: no corpo e no botão da AppBar.
    // Só o da AppBar abre o seletor.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Gênesis 1'),
      ),
    );
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
