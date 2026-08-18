import 'dart:async';
import 'dart:convert';

import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/personas.dart';
import 'package:felipe_ambrozini/data/voz.dart';
import 'package:felipe_ambrozini/main.dart';
import 'package:felipe_ambrozini/telas/biblia.dart';
import 'package:felipe_ambrozini/telas/chat.dart';
import 'package:felipe_ambrozini/telas/comuns.dart';
import 'package:felipe_ambrozini/telas/devocional.dart';
import 'package:felipe_ambrozini/telas/hoje.dart';
import 'package:felipe_ambrozini/telas/plano.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Leitor de áudio sem plataforma, para o teste do fluxo de voz: o teste
/// decide quando a leitura termina ([encerrar]), onde ela está
/// ([posicaoAtual]) e quando uma pausa de fora a interrompe ([pausarDeFora])
/// — o suficiente para provar que a barra de cima acompanha o estado e que o
/// "Desfazer" do deslize devolve a leitura de onde parou.
class _LeitorFalsoDoApp implements LeitorDeAudio {
  int toques = 0;

  /// A posição pedida no último [tocar]: o que a retomada do "Desfazer"
  /// precisa entregar.
  Duration? ultimoDe;

  @override
  Duration? posicaoAtual;

  @override
  bool concluida = true;

  @override
  bool pausadoDeFora = false;

  Completer<void>? _fim;

  @override
  Future<void> tocar(Uint8List bytes, {Duration? de}) {
    pausadoDeFora = false;
    toques++;
    ultimoDe = de;
    final fim = Completer<void>();
    _fim = fim;
    return fim.future;
  }

  @override
  Future<void> silenciar() async {
    final fim = _fim;
    if (fim != null && !fim.isCompleted) fim.complete();
  }

  /// O áudio chegou ao fim: completa o tocar pendente.
  void encerrar() {
    final fim = _fim;
    if (fim != null && !fim.isCompleted) fim.complete();
  }

  /// Uma chamada ou a perda de foco de áudio pausou a leitura: o player de
  /// verdade completa o play() pausado, e é assim que a pausa é marcada.
  void pausarDeFora() {
    pausadoDeFora = true;
    encerrar();
  }

  @override
  Stream<Duration> get posicao => Stream<Duration>.value(Duration.zero);

  @override
  Stream<Duration?> get duracao =>
      Stream<Duration?>.value(const Duration(minutes: 20));
}

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
      expect(bissexto!.data, '29-02');

      // Em ano comum o cronograma não prevê a data — o dia não existe. Em ano
      // bissexto a variante de 366 dias o inclui como dia próprio (acima).
      final comum = await conteudo.plano(bissexto: false);
      expect(comum.any((d) => d.data == '29-02'), isFalse);
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
      home: EscopoDoEstado(
        estado: estado,
        child: TelaPlano(hoje: hoje),
      ),
    );

    await tester.pumpWidget(tela(DateTime(2027, 12, 31)));
    await tester.pumpAndSettle();

    // Redesenha o MESMO widget com uma data nova, simulando o relógio andando
    // enquanto a tela ficou viva no IndexedStack da moldura (didUpdateWidget,
    // não um novo State). Antes do conserto, "_hoje" ficava presa em 2027.
    await tester.pumpWidget(tela(DateTime(2028, 1, 1)));
    await tester.pumpAndSettle();

    // O mês aberto fica centralizado na régua (dezembro, no segundo frame);
    // rolar o chip de volta para a tela antes de tocar, como um dedo faria.
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Fevereiro'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Fevereiro'));
    await tester.pumpAndSettle();

    // 29 dias e não 28: prova que carregou o cronograma bissexto de 2028, não
    // o de 2027 que a tela tinha aberto com. Presa em 2027, a contagem diria
    // 28 (fevereiro comum) mesmo com o chip de fevereiro selecionado.
    expect(
      find.textContaining('de 29 dias concluídos em Fevereiro'),
      findsOneWidget,
    );
  });

  testWidgets('a moldura abre em Hoje e mostra as cinco seções', (
    tester,
  ) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(AppDevocional(estado: await estadoLimpo()));
    await tester.pumpAndSettle();

    // Sobre não é mais aba: a navegação inferior tem cinco destinos, e os
    // créditos moram na folha de ajustes (ver o teste seguinte).
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
    // O cartão de ajuda da primeira visita empurra a prévia de Promessas para
    // baixo da área que a lista realiza; rolar até ela antes de conferir.
    await tester.scrollUntilVisible(
      find.text('Promessas de Deus'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
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
    // Não existe aviso de 29 de fevereiro: em ano comum o dia não existe, e em
    // ano bissexto o cronograma o inclui como dia próprio. O finder guarda que
    // o antigo cartão de "dia de recuperação" não volte.
    expect(find.textContaining('29 de fevereiro'), findsNothing);
  });

  testWidgets('Sobre abre da folha de ajustes e atualiza a URL', (
    tester,
  ) async {
    // Sobre voltou a viver dentro da folha de ajustes (ver comuns.dart), e o
    // caminho até ele agora é um `GoRouter.push` feito por fora do shell.
    // Sem `optionURLReflectsImperativeAPIs`, ligada no main.dart, esse push
    // abriria a tela mas deixaria a barra de endereço presa na aba — este
    // teste prova as duas partes: o conteúdo abre e a URL interna segue.
    await aquecerAssets(tester);
    await tester.pumpWidget(AppDevocional(estado: await estadoLimpo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BotaoDeAjustes));
    await tester.pumpAndSettle();

    // A folha cresce até quase a tela inteira e rola; o tile de Sobre é o
    // último item e pode nascer fora da área visível.
    await tester.ensureVisible(find.text('Sobre'));
    await tester.tap(find.text('Sobre'));
    await tester.pumpAndSettle();

    expect(find.text('Fontes do texto'), findsOneWidget);
    // O parágrafo de créditos e o da voz empurram os canais para fora da
    // área que a lista realiza de saída; sem rolar até eles, o finder não
    // os encontra.
    await tester.scrollUntilVisible(find.text('YouTube'), 200);
    expect(find.text('YouTube'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Instagram'), 200);
    expect(find.text('Instagram'), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path,
      '/sobre',
    );
  });

  testWidgets('o balão do chat abre o histórico e atualiza a URL', (
    tester,
  ) async {
    // O balão empurra a TelaHistorico pelo GoRouter (não por um Navigator
    // cru): além de abrir o conteúdo, a barra de endereço precisa acompanhar
    // e voltar junto quando o histórico fecha.
    await aquecerAssets(tester);
    await tester.pumpWidget(AppDevocional(estado: await estadoLimpo()));
    await tester.pumpAndSettle();

    // O router é global e os testes rodam no mesmo processo: a URL de partida
    // é a que o teste anterior deixou, então se compara com ela, não com uma
    // aba fixa.
    final partida = GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).state.uri.path;

    await tester.tap(find.byType(BalaoDeChat).first);
    await tester.pumpAndSettle();

    expect(find.text('Charles Spurgeon'), findsWidgets);
    expect(find.text('Conversas'), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path,
      '/charles-spurgeon',
    );

    // O botão de voltar da AppBar desta versão do Flutter é um IconButton
    // com o BackButtonIcon, não o widget BackButton que o pageBack() procura.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path,
      partida,
      reason: 'fechar o histórico devolve a URL à localização de origem',
    );
  });

  testWidgets(
    'reabrir o chat com uma resposta interrompida oferece tentar de novo',
    (tester) async {
      // Sair da tela no meio da geração deixa a pergunta pendente; o reabrir
      // tem de oferecer a resposta em vez de deixá-la respondida pelo
      // silêncio.
      final estado = await estadoLimpo();
      final conversa = await estado.novaConversa(
        'spurgeon',
        titulo: 'Como vencer a ansiedade?',
      );
      await estado.registrarMensagem(
        'spurgeon',
        conversa.id,
        Mensagem(
          id: '1',
          papel: 'user',
          texto: 'Como vencer a ansiedade?',
          momento: 1,
          pendente: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(
            estado: estado,
            child: TelaChat(persona: personaSpurgeon, conversaId: conversa.id),
          ),
        ),
      );
      // O aviso chega no primeiro frame, depois do postFrameCallback do
      // initState; um pump a mais renderiza o setState dele.
      await tester.pump();
      await tester.pump();

      expect(find.text('A resposta anterior não chegou.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      // A pergunta continua no histórico, esperando a resposta.
      expect(find.text('Como vencer a ansiedade?'), findsOneWidget);

      // O balão de erro não fica fixo: dois segundos depois ele some sozinho.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('A resposta anterior não chegou.'), findsNothing);
      expect(find.text('Tentar de novo'), findsNothing);
    },
  );

  testWidgets('conversa que passou do teto mostra o aviso quieto do corte', (
    tester,
  ) async {
    // O corte acontece no Estado, na hora de registrar a mensagem que
    // estoura o teto; a tela só mostra a nota quando a conversa foi cortada.
    final estado = await estadoLimpo();
    final conversa = await estado.novaConversa('spurgeon', titulo: 'm0');
    for (var i = 0; i < 121; i++) {
      await estado.registrarMensagem(
        'spurgeon',
        conversa.id,
        Mensagem(id: 'm$i', papel: 'user', texto: 'fala $i', momento: i),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: estado,
          child: TelaChat(persona: personaSpurgeon, conversaId: conversa.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // O segundo salto roda no post-frame do pump anterior; o frame que
    // desenha a última fala é o seguinte.
    await tester.pump();

    // A conversa reabre na última fala, não no Filete: a última mensagem
    // está visível e o aviso do corte (que mora no topo) ainda não foi
    // construído.
    expect(find.text('fala 120'), findsOneWidget);
    expect(
      find.textContaining('As falas mais antigas saíram'),
      findsNothing,
    );

    // O aviso de corte existe e aparece quando a lista volta ao topo.
    await tester.scrollUntilVisible(
      find.textContaining('As falas mais antigas saíram'),
      -200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.textContaining('As falas mais antigas saíram'), findsOneWidget);

    // Desmonta o chat da conversa cortada antes de abrir a curta: sem isto o
    // framework reusa o State (mesmo tipo de widget) e o conversador da
    // conversa anterior continua no ar.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    // Uma conversa curta não leva o aviso.
    final curta = await estado.novaConversa('spurgeon', titulo: 'curta');
    await estado.registrarMensagem(
      'spurgeon',
      curta.id,
      Mensagem(id: 'c1', papel: 'user', texto: 'oi', momento: 999),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: estado,
          child: TelaChat(persona: personaSpurgeon, conversaId: curta.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('As falas mais antigas saíram'), findsNothing);
    expect(find.text('oi'), findsOneWidget);
  });

  Future<void> abrirHistorico(WidgetTester tester, Estado estado) async {
    await tester.pumpWidget(AppDevocional(estado: estado));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BalaoDeChat).first);
    await tester.pumpAndSettle();
  }

  Future<void> voltarParaCasa(WidgetTester tester) async {
    // O router é global e os testes rodam no mesmo processo: devolve a
    // navegação ao ponto de partida para não contaminar o teste seguinte.
    while (tester.any(find.byIcon(Icons.arrow_back))) {
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('o histórico lista as conversas, da mais recente à mais antiga', (
    tester,
  ) async {
    final estado = await estadoLimpo();
    final antiga = await estado.novaConversa('spurgeon', titulo: 'Primeira');
    await estado.registrarMensagem(
      'spurgeon',
      antiga.id,
      Mensagem(id: '1', papel: 'user', texto: 'Primeira', momento: 1),
    );
    final recente = await estado.novaConversa('spurgeon', titulo: 'Segunda');
    await estado.registrarMensagem(
      'spurgeon',
      recente.id,
      Mensagem(id: '2', papel: 'user', texto: 'Segunda', momento: 2),
    );

    await aquecerAssets(tester);
    await abrirHistorico(tester, estado);

    expect(find.text('Primeira'), findsOneWidget);
    expect(find.text('Segunda'), findsOneWidget);
    // A mais recente vem primeiro: a Segunda fica acima da Primeira.
    expect(
      tester.getTopLeft(find.text('Segunda')).dy,
      lessThan(tester.getTopLeft(find.text('Primeira')).dy),
    );

    await voltarParaCasa(tester);
  });

  testWidgets('apagar uma conversa remove só ela, com confirmação', (
    tester,
  ) async {
    final estado = await estadoLimpo();
    final uma = await estado.novaConversa('spurgeon', titulo: 'Uma');
    await estado.registrarMensagem(
      'spurgeon',
      uma.id,
      Mensagem(id: '1', papel: 'user', texto: 'Uma', momento: 1),
    );
    final outra = await estado.novaConversa('spurgeon', titulo: 'Outra');
    await estado.registrarMensagem(
      'spurgeon',
      outra.id,
      Mensagem(id: '2', papel: 'user', texto: 'Outra', momento: 2),
    );

    await aquecerAssets(tester);
    await abrirHistorico(tester, estado);

    // Apaga a "Uma" pelo botão da própria linha.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Uma'),
        matching: find.byTooltip('Apagar conversa'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apagar esta conversa?'), findsOneWidget);
    expect(
      find.textContaining('As outras conversas ficam.'),
      findsOneWidget,
      reason: 'o aviso promete que as demais não são tocadas',
    );

    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(find.text('Uma'), findsNothing);
    expect(find.text('Outra'), findsOneWidget);
    expect(estado.conversasDe('spurgeon'), hasLength(1));

    await voltarParaCasa(tester);
  });

  testWidgets('apagar tudo remove todas as conversas, com confirmação', (
    tester,
  ) async {
    final estado = await estadoLimpo();
    for (final (titulo, momento) in [('Uma', 1), ('Outra', 2)]) {
      final c = await estado.novaConversa('spurgeon', titulo: titulo);
      await estado.registrarMensagem(
        'spurgeon',
        c.id,
        Mensagem(
          id: '$momento',
          papel: 'user',
          texto: titulo,
          momento: momento,
        ),
      );
    }

    await aquecerAssets(tester);
    await abrirHistorico(tester, estado);

    await tester.tap(find.byTooltip('Apagar todas as conversas'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar todas as conversas?'), findsOneWidget);

    await tester.tap(find.text('Apagar tudo'));
    await tester.pumpAndSettle();

    expect(find.text('Uma'), findsNothing);
    expect(find.text('Outra'), findsNothing);
    expect(
      find.textContaining('Nenhuma conversa com Charles Spurgeon ainda'),
      findsOneWidget,
    );
    expect(estado.conversasDe('spurgeon'), isEmpty);

    await voltarParaCasa(tester);
  });

  testWidgets('tocar numa conversa abre o chat e atualiza a URL', (
    tester,
  ) async {
    final estado = await estadoLimpo();
    final c = await estado.novaConversa('spurgeon', titulo: 'Minha pergunta');
    await estado.registrarMensagem(
      'spurgeon',
      c.id,
      Mensagem(id: '1', papel: 'user', texto: 'Minha pergunta', momento: 1),
    );

    await aquecerAssets(tester);
    await abrirHistorico(tester, estado);

    await tester.tap(find.text('Minha pergunta'));
    await tester.pumpAndSettle();

    // A conversa abre com a pergunta no histórico.
    expect(find.text('Minha pergunta'), findsWidgets);
    final uri = GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).state.uri;
    expect(
      uri.pathSegments,
      ['charles-spurgeon', 'conversa', c.id],
      reason: 'o F5 e um link compartilhado reabrem esta conversa, não outra',
    );

    await voltarParaCasa(tester);
  });

  testWidgets('numa janela larga, a coluna de leitura fica centralizada '
      'ao lado do trilho de navegação', (tester) async {
    // Simula uma janela de navegador bem mais larga que o limite de leitura,
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
              'No princípio, Deus criou os céus e a terra',
            ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'faixa por versículo destaca o recorte e mantém o contexto',
    (tester) async {
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
    },
    skip: false, // salmos.json foi traduzido
  );

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
            w.text.toPlainText().contains('No princípio, Deus criou'),
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
              w.text.toPlainText().contains('No princípio, Deus criou'),
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
        '"No princípio, Deus criou os céus e a terra."\nGênesis 1:1 (BKJ)\n'
        'https://felipeambrozini.com.br/devocional/?ler=genesis.1.1',
      );
    },
  );

  testWidgets('Tela cheia abre o versículo e fecha pelo botão de fechar', (
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
            w.text.toPlainText().contains('No princípio, Deus criou'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tela cheia'));
    await tester.pumpAndSettle();

    expect(
      find.text('No princípio, Deus criou os céus e a terra.'),
      findsOneWidget,
    );
    expect(find.text('Gênesis 1:1'), findsOneWidget);

    // Um toque no texto não fecha: durante uma transmissão, um toque
    // acidental não pode encerrar a apresentação. Fecha só pelo botão.
    await tester.tap(find.text('No princípio, Deus criou os céus e a terra.'));
    await tester.pumpAndSettle();
    expect(find.text('Gênesis 1:1'), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    // De volta ao leitor: lá o versículo é RichText, não Text (ver o find
    // acima, no início do teste), então a apresentação já não está na tela.
    expect(find.text('Gênesis 1:1'), findsNothing);
    expect(
      find.text('No princípio, Deus criou os céus e a terra.'),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('No princípio, Deus criou'),
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

  testWidgets('Manhã e Noite mostra o nome do livro por extenso em maiúsculas '
      'e a referência abreviada do devocional, não o versículo completo', (
    tester,
  ) async {
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

    // A referência da citação vem do próprio devocional (field `referencia`),
    // exibida em caixa alta — não é o versículo completo da BKJ.
    expect(
      find.textContaining('JOSUÉ 5:12', findRichText: true),
      findsOneWidget,
    );
    // O versículo completo da BKJ não aparece: só a referência abreviada.
    expect(
      find.textContaining(
        'Elas comeram do fruto da terra de Canaã',
        findRichText: true,
      ),
      findsNothing,
    );
    // Regressão: a referência em maiúsculas não pode impedir a introdução do
    // livro de aparecer entre o seletor e o texto do devocional, com o título
    // formal do livro ao lado.
    expect(
      find.text('Introdução: ${livroPorSlug('josue')!.tituloFormal}'),
      findsOneWidget,
    );
  });

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
          'E porei inimizade entre ti e a mulher',
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

  testWidgets('o seletor de livro busca por nome sem acento nem caixa', (
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

    await tester.tap(find.widgetWithText(TextButton, 'Gênesis 1'));
    await tester.pumpAndSettle();

    // Digitar sem acento nem maiúscula ainda encontra Josué.
    await tester.enterText(find.byType(TextField), 'josue');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Josué'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Juízes'), findsNothing);

    // Apagar a busca devolve a lista completa de 66 livros.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Josué'), findsOneWidget);
    // Apocalipse é o último dos 66: desce a lista até ele, como um dedo
    // faria, antes de conferir que a lista inteira voltou.
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Apocalipse'),
      300,
      scrollable: find.ancestor(
        of: find.widgetWithText(ChoiceChip, 'Josué'),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.widgetWithText(ChoiceChip, 'Apocalipse'), findsOneWidget);
  });

  testWidgets('o leitor aberto por link rola até o versículo pedido', (
    tester,
  ) async {
    await aquecerAssets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          // O link ?ler=genesis.1.4 abre o capítulo 1 e pede o versículo 4:
          // no app, "destacar" é (4, 4) nesse caso (ver main.dart).
          child: const TelaBiblia(destacar: (4, 4)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // O versículo pedido fica em cima, visível — e não existe rótulo
    // "Gênesis 1:4" no leitor: o número vive dentro do próprio RichText.
    final versiculo4 = find.byWidgetPredicate(
      (w) =>
          w is RichText &&
          w.text.toPlainText().contains('E viu Deus que a luz era boa'),
    );
    final posicao = tester.getRect(versiculo4);
    expect(posicao.top, greaterThanOrEqualTo(0));
    expect(posicao.bottom, lessThanOrEqualTo(600));

    // E sem o recuo apagado que a faixa aplica aos versículos de fora:
    // quem veio por link pediu este versículo, não uma leitura de cronograma.
    // O recuo funciona acrescentando uma cor (0,7 de opacidade); a ausência
    // dela no alvo é o que prova que ele não veio apagado.
    List<TextSpan> achatar(TextSpan raiz, List<TextSpan> saida) {
      if (raiz.text != null) saida.add(raiz);
      for (final filho in raiz.children ?? const <InlineSpan>[]) {
        achatar(filho as TextSpan, saida);
      }
      return saida;
    }

    final span = tester.widget<RichText>(versiculo4).text as TextSpan;
    final doAlvo = achatar(
      span,
      [],
    ).firstWhere((s) => s.text!.contains('E viu Deus'));
    expect(
      doAlvo.style?.color?.a,
      1.0,
      reason: 'o versículo pedido no link não pode vir com o texto apagado',
    );

    // E o primeiro versículo do capítulo, que ficou fora da faixa, veio
    // apagado: é a outra metade da mesma promessa.
    final versiculo1 = find.byWidgetPredicate(
      (w) =>
          w is RichText &&
          w.text.toPlainText().contains('No princípio, Deus criou'),
    );
    final doLadoDeFora = achatar(
      tester.widget<RichText>(versiculo1).text as TextSpan,
      [],
    ).firstWhere((s) => s.text!.contains('No princípio'));
    expect(doLadoDeFora.style?.color?.a, 0.7);
  });

  testWidgets(
    'deslizar com dominância vertical não vira capítulo; o deslize horizontal '
    'vira e oferece desfazer',
    (tester) async {
      await aquecerAssets(tester);
      final estado = await estadoLimpo();
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(estado: estado, child: const TelaBiblia()),
        ),
      );
      await tester.pumpAndSettle();

      // Leitura com a mão em diagonal: o arrasto é vertical de verdade, e o
      // pouco de horizontal não pode trocar de capítulo no meio dela. Numa
      // leitura recém-aberta ainda não há capítulo anterior, então nada muda.
      await tester.timedDrag(
        find.byType(ListView),
        const Offset(60, 140),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();
      expect(
        estado.ultimaLeitura,
        isNull,
        reason: 'a dominância vertical bloqueia o deslize de capítulo',
      );

      // O deslize horizontal de verdade vira o capítulo e deixa o desfazer
      // à mão.
      await tester.fling(find.byType(ListView), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(estado.ultimaLeitura, ('genesis', 2));
      expect(find.text('Desfazer'), findsOneWidget);
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(estado.ultimaLeitura, ('genesis', 1));
    },
  );

  testWidgets(
    'a barra de cima mostra o preparo e o tocar; deslizar derruba a leitura '
    'e o desfazer a devolve de onde parou',
    (tester) async {
      await aquecerAssets(tester);
      final estado = await estadoLimpo();
      final leitor = _LeitorFalsoDoApp();
      Voz.instancia.injetarLeitor = leitor;
      addTearDown(() async {
        await Voz.instancia.parar();
        Voz.instancia.injetarLeitor = null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(estado: estado, child: const TelaBiblia()),
        ),
      );
      await tester.pumpAndSettle();

      // A leitura começa; o preparo é lento (o cliente só responde quando o
      // teste deixa) e a barra de cima tem de mostrá-lo — senão quem rolou
      // não saberia que o toque pegou nem como cancelar.
      final resposta = Completer<http.Response>();
      final cliente = MockClient((_) => resposta.future);
      final leitura = Voz.instancia.alternar(
        'capitulo:genesis.1',
        texto: 'No princípio.',
        cliente: cliente,
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await tester.pump();
      expect(Voz.instancia.carregando, isTrue);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Cancelar o preparo'),
        ),
        findsOneWidget,
        reason: 'o preparo não pode ser invisível na barra de cima',
      );

      resposta.complete(
        http.Response(
          json.encode({'audioContent': base64.encode([1, 2, 3])}),
          200,
        ),
      );
      // Deixa o fluxo da resposta chegar ao tocar. pumpEventQueue não serve
      // aqui: em testWidgets o relógio é falso, e o Future.delayed dele é um
      // timer que nunca dispara sem pump.
      await tester.pumpAndSettle();
      expect(Voz.instancia.tocando, isTrue);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Encerrar a leitura'),
        ),
        findsOneWidget,
        reason: 'tocando, a barra de cima vira o botão de parar',
      );
      expect(
        find.descendant(
          of: find.byType(BotaoDeVoz),
          matching: find.byType(Image),
        ),
        findsNothing,
        reason: 'o retrato é o convite; tocando, ele sai da pílula',
      );

      // O deslize troca de capítulo e derruba a leitura: não se deixa um
      // áudio tocando sem o botão de parar à vista.
      leitor.posicaoAtual = const Duration(minutes: 3);
      await tester.fling(find.byType(ListView), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(estado.ultimaLeitura, ('genesis', 2));
      expect(Voz.instancia.tocando, isFalse,
          reason: 'o deslize não pode deixar áudio no ar');
      await leitura;

      // O "Desfazer" devolve a página e a leitura, da posição em que estava:
      // desfazer o deslize sem devolver o áudio seria desfazer pela metade.
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(estado.ultimaLeitura, ('genesis', 1));
      expect(Voz.instancia.tocandoChave, 'capitulo:genesis.1');
      expect(
        leitor.ultimoDe,
        const Duration(minutes: 3),
        reason: 'a leitura retoma de onde parou, não do começo',
      );
      leitor.encerrar();
    },
  );

  testWidgets(
    'uma pausa de fora vira "Pausado" na pílula; o toque retoma de onde parou',
    (tester) async {
      await aquecerAssets(tester);
      final estado = await estadoLimpo();
      // Gênesis 2, e não o 1 do teste anterior: o teste da barra parou a
      // chave "capitulo:genesis.1" há menos de 400 ms, e o debounce do
      // reinício engoliria o toque desta sessão.
      await estado.registrarLeitura('genesis', 2);
      final leitor = _LeitorFalsoDoApp();
      Voz.instancia.injetarLeitor = leitor;
      addTearDown(() async {
        await Voz.instancia.parar();
        Voz.instancia.injetarLeitor = null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(estado: estado, child: const TelaBiblia()),
        ),
      );
      await tester.pumpAndSettle();

      final resposta = Completer<http.Response>();
      final cliente = MockClient((_) => resposta.future);
      final leitura = Voz.instancia.alternar(
        'capitulo:genesis.2',
        texto: 'No princípio.',
        cliente: cliente,
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await tester.pump();
      resposta.complete(
        http.Response(
          json.encode({'audioContent': base64.encode([1, 2, 3])}),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(Voz.instancia.tocando, isTrue);

      // Tocando, a barra de cima mostra o anel de progresso junto do parar:
      // quem rolou para longe do botão continua vendo quanto falta.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'tocando, a barra de cima mostra o progresso no anel do parar',
      );

      // A chamada chega: o player pausa sozinho, e a UI tem de dizer a
      // verdade em vez de congelar em "O pregador está lendo…".
      leitor.posicaoAtual = const Duration(minutes: 3);
      leitor.pausarDeFora();
      await tester.pumpAndSettle();
      expect(Voz.instancia.tocando, isFalse);
      expect(Voz.instancia.pausado, isTrue);
      expect(
        find.descendant(
          of: find.byType(BotaoDeVoz),
          matching: find.text('Pausado. Toque para retomar.'),
        ),
        findsOneWidget,
        reason: 'pausada, a pílula oferece retomar em vez de mentir o estado',
      );
      // O retomar agora mora nos dois lugares: na pílula e no anel da barra
      // (quem rolou para longe do topo não pode ter de voltar).
      expect(
        find.byTooltip('Retomar a leitura'),
        findsNWidgets(2),
        reason: 'pílula e barra oferecem o retomar da sessão pausada',
      );

      // O toque no anel da barra retoma da posição da pausa, do áudio da
      // memória — sem voltar ao topo do capítulo.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Retomar a leitura'),
        ),
      );
      await tester.pumpAndSettle();
      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocando, isTrue,
          reason: 'o toque na sessão pausada retoma a leitura');
      expect(leitor.toques, 2);
      expect(
        leitor.ultimoDe,
        const Duration(minutes: 3),
        reason: 'o retomar começa de onde a leitura parou, não do zero',
      );

      // Pausada de novo, o deslize também devolve a voz no "Desfazer": a
      // sessão pausada ainda é "em curso", e desfazer a página sem a voz
      // seria desfazer pela metade.
      leitor.posicaoAtual = const Duration(minutes: 4);
      leitor.pausarDeFora();
      await tester.pumpAndSettle();
      expect(Voz.instancia.pausado, isTrue);
      await tester.fling(find.byType(ListView), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(estado.ultimaLeitura, ('genesis', 3));
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(estado.ultimaLeitura, ('genesis', 2));
      expect(Voz.instancia.tocandoChave, 'capitulo:genesis.2',
          reason: 'o desfazer devolve a sessão pausada junto com a página');
      expect(
        leitor.ultimoDe,
        const Duration(minutes: 4),
        reason: 'a sessão pausada retoma de onde a chamada a pegou',
      );

      // Pausada a terceira vez: a pílula agora oferece descartar, não só
      // retomar. Sem um jeito de encerrar a pausa da própria tela, ela vira uma
      // gaiola — e um descarte precisa ser mais perto que subir ao topo.
      leitor.posicaoAtual = const Duration(minutes: 3, seconds: 30);
      leitor.pausarDeFora();
      await tester.pumpAndSettle();
      expect(Voz.instancia.pausado, isTrue);
      expect(
        find.descendant(
          of: find.byType(BotaoDeVoz),
          matching: find.byTooltip('Encerrar a leitura pausada'),
        ),
        findsOneWidget,
        reason: 'a pausa precisa de um jeito de ser encerrada da própria tela',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(BotaoDeVoz),
          matching: find.byTooltip('Encerrar a leitura pausada'),
        ),
      );
      await tester.pumpAndSettle();
      expect(Voz.instancia.pausado, isFalse);
      expect(Voz.instancia.tocandoChave, isNull,
          reason: 'o descarte encerra a sessão pausada de vez');
      expect(leitor.toques, 3, reason: 'o descarte não toca — só encerra');
      leitor.encerrar();
      await leitura;
    },
  );

  testWidgets(
    'o Desfazer devolve a voz que ficou pronta no preparo, não o silêncio',
    (tester) async {
      await aquecerAssets(tester);
      final estado = await estadoLimpo();
      // Gênesis 4: o teste anterior parou a chave genesis.2 há menos de 400 ms,
      // e o debounce do reinício engoliria um toque de genesis.2 aqui.
      await estado.registrarLeitura('genesis', 4);
      final leitor = _LeitorFalsoDoApp();
      Voz.instancia.injetarLeitor = leitor;
      addTearDown(() async {
        await Voz.instancia.parar();
        Voz.instancia.injetarLeitor = null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoDoEstado(estado: estado, child: const TelaBiblia()),
        ),
      );
      await tester.pumpAndSettle();

      final resposta = Completer<http.Response>();
      final cliente = MockClient((_) => resposta.future);
      final leitura = Voz.instancia.alternar(
        'capitulo:genesis.4',
        texto: 'No princípio.',
        cliente: cliente,
        chaveTts: 'teste',
        tipo: TipoConteudoAudio.biblia,
      );
      await tester.pump();
      expect(Voz.instancia.carregando, isTrue);

      // O deslize troca de capítulo (4→5) com a síntese ainda no ar: o Desfazer
      // tem de devolver a voz, não só a página — e a síntese não pode ser
      // engolida pelo novo capítulo (ele cai no discard por versão, mas entra
      // na cache: a quota não se perde).
      await tester.fling(find.byType(ListView), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(estado.ultimaLeitura, ('genesis', 5));

      // A síntese conclui DENTRO da janela do Desfazer (4s): o áudio está na
      // cache, e o Desfazer retoma — não morre no silêncio do preparo.
      resposta.complete(
        http.Response(
          json.encode({'audioContent': base64.encode([1, 2, 3])}),
          200,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();
      expect(estado.ultimaLeitura, ('genesis', 4));
      expect(Voz.instancia.tocandoChave, 'capitulo:genesis.4');
      expect(leitor.ultimoDe, isNull,
          reason: 'preparo sem pausa: retoma do zero (sem posição)');
      expect(leitor.toques, 2,
          reason: 'o desfazer re-sintetizou (ou retomou da cache) a voz');
      leitor.encerrar();
      await leitura;
    },
  );

  testWidgets('o cartão de ajuda da primeira visita some ao tocar Entendi', (
    tester,
  ) async {
    // A tela Hoje direto, e não o AppDevocional inteiro: o GoRouter do app é
    // um singleton global, e um teste anterior pode deixar a aba ativa longe
    // da Hoje. O cartão não tem nada a ver com a moldura.
    await aquecerAssets(tester);
    final estado = await estadoLimpo();
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(estado: estado, child: const TelaHoje()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Como usar'), findsOneWidget);
    expect(find.text('Entendi'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Como usar'), findsNothing);

    // E não volta: a escolha fica gravada no estado, como em qualquer
    // primeira visita depois desta.
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(estado: estado, child: const TelaHoje()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Como usar'), findsNothing);
  });

  testWidgets('o chip do mês escolhido fica à vista na régua do Plano', (
    tester,
  ) async {
    // Em agosto, o chip de agosto começava fora da tela (a régua abria em
    // janeiro) enquanto a lista já mostrava agosto.
    await tester.runAsync(() => Conteudo.instancia.plano(bissexto: false));
    await tester.pumpWidget(
      MaterialApp(
        home: EscopoDoEstado(
          estado: await estadoLimpo(),
          child: TelaPlano(hoje: DateTime(2027, 8, 15)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final agosto = tester.getRect(find.widgetWithText(ChoiceChip, 'Agosto'));
    expect(agosto.left, greaterThanOrEqualTo(0));
    expect(agosto.right, lessThanOrEqualTo(800));

    // E o mês escolhido à mão também volta para dentro da tela: a régua
    // centraliza o chip escolhido, e rolar até ele antes do toque é o que um
    // dedo de verdade faria.
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Dezembro'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dezembro'));
    await tester.pumpAndSettle();
    final dezembro = tester.getRect(
      find.widgetWithText(ChoiceChip, 'Dezembro'),
    );
    expect(dezembro.left, greaterThanOrEqualTo(0));
    expect(dezembro.right, lessThanOrEqualTo(800));
  });
}


