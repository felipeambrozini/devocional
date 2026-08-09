import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/canon.dart';
import 'data/estado.dart';
import 'data/lembretes.dart';
import 'data/modelos.dart';
import 'data/nuvem.dart';
import 'telas/biblia.dart';
import 'telas/comuns.dart';
import 'telas/devocional.dart';
import 'telas/hoje.dart';
import 'telas/notas.dart';
import 'telas/plano.dart';
import 'theme.dart';

/// De módulo, e não de um State: o toque numa notificação chega por um
/// callback do plugin que não tem `BuildContext` de tela nenhuma, e pode
/// acontecer com o app em qualquer lugar da árvore.
final navigatorKey = GlobalKey<NavigatorState>();

/// Abre a leitura da notificação por cima do que estiver na tela, igual ao
/// "Continuar leitura" da tela Hoje. `chave` é "manha", "promessas" ou
/// "noite" — ver o contrato em `lib/data/lembretes.dart`.
void _abrirLeituraDoLembrete(String chave) {
  final leitura = Leitura.values.where((l) => l.name == chave).firstOrNull;
  if (leitura == null) return;
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => TelaDevocional(leituraInicial: leitura)),
  );
}

/// Abre o versículo ou capítulo do parâmetro `ler` da URL (`?ler=joao.3.16`),
/// para quem chega por um link compartilhado. Fora da web `Uri.base` é o
/// diretório de trabalho, sem esse parâmetro, então não precisa de `kIsWeb`
/// para não fazer nada nas outras plataformas.
void _abrirLeituraDoLink() {
  final parametro = Uri.base.queryParameters['ler'];
  if (parametro == null) return;
  final alvo = alvoDoLink(parametro);
  if (alvo == null) return;
  final (slug, capitulo, versiculo) = alvo;
  final versaoParametro = Uri.base.queryParameters['versao'];
  final versao = Versao.values
      .where((v) => v.pasta == versaoParametro)
      .firstOrNull;
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => TelaBiblia(
        livroInicial: slug,
        capituloInicial: capitulo,
        destacar: versiculo == null ? null : (versiculo, versiculo),
        versaoInicial: versao,
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final estado = await Estado.abrir();

  // Sem await: o firebase_core_web busca o SDK JS do gstatic, e esperar isso
  // antes do runApp poria uma ida à rede na frente do primeiro quadro, num
  // app que hoje abre sem depender de rede nenhuma. Fora da web não chama.
  if (nuvemSuportada) unawaited(Nuvem.instancia.iniciar(estado));

  await Lembretes.instancia.inicializar(
    aoTocarNotificacao: _abrirLeituraDoLembrete,
  );
  await reagendarLembretesSeNecessario(estado);
  // Precisa vir antes do runApp: depois dele o plugin já não sabe dizer que
  // toque abriu o app, só qual chegou com o app já aberto.
  final chaveDeAbertura = await Lembretes.instancia.chaveQueAbriuOApp();

  runApp(AppDevocional(estado: estado));

  if (chaveDeAbertura != null) {
    // O Navigator só existe depois do primeiro quadro.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _abrirLeituraDoLembrete(chaveDeAbertura),
    );
  } else {
    // Um link e um toque de notificação nunca chegam juntos: o link só existe
    // na web, e lembrete só em Android e iOS. O `else` é só para não empurrar
    // duas telas por cima uma da outra se algum dia os dois coincidirem.
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirLeituraDoLink());
  }
}

class AppDevocional extends StatefulWidget {
  const AppDevocional({super.key, required this.estado});

  final Estado estado;

  @override
  State<AppDevocional> createState() => _AppDevocionalState();
}

class _AppDevocionalState extends State<AppDevocional> {
  late double _escala = widget.estado.escalaDeLeitura;
  late ModoDoTema _modo = widget.estado.modoDoTema;

  @override
  void initState() {
    super.initState();
    widget.estado.addListener(_conferirTema);
  }

  @override
  void dispose() {
    widget.estado.removeListener(_conferirTema);
    super.dispose();
  }

  /// O tema precisa ser refeito quando o tamanho do texto ou o modo mudam, mas o
  /// [Estado] avisa a árvore inteira a cada favorito. Sem esta comparação, marcar
  /// um versículo reconstruiria os dois ThemeData e, com eles, toda tela que
  /// depende do tema. Aqui só se redesenha quando algo do tema muda de fato.
  void _conferirTema() {
    final estado = widget.estado;
    if (estado.escalaDeLeitura == _escala && estado.modoDoTema == _modo) return;
    setState(() {
      _escala = estado.escalaDeLeitura;
      _modo = estado.modoDoTema;
    });
  }

  @override
  Widget build(BuildContext context) {
    return EscopoDoEstado(
      estado: widget.estado,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Devocional',
        debugShowCheckedModeBanner: false,
        // Os dois temas vão sempre montados, e o `themeMode` escolhe. Assim
        // "Automático" funciona de verdade: o sistema pode virar o modo com o
        // app aberto, e o MaterialApp troca sozinho, sem passar pelo Estado.
        theme: construirTema(
          brilho: Brightness.light,
          escalaDeLeitura: _escala,
        ),
        darkTheme: construirTema(
          brilho: Brightness.dark,
          escalaDeLeitura: _escala,
        ),
        themeMode: switch (_modo) {
          ModoDoTema.sistema => ThemeMode.system,
          ModoDoTema.claro => ThemeMode.light,
          ModoDoTema.escuro => ThemeMode.dark,
        },
        home: const Moldura(),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [const Locale('pt', 'BR')],
      ),
    );
  }
}

class _Destino {
  const _Destino(this.rotulo, this.icone, this.iconeAtivo, this.tela);

  final String rotulo;
  final IconData icone;
  final IconData iconeAtivo;
  final Widget tela;
}

const _destinos = <_Destino>[
  _Destino('Hoje', Icons.wb_twilight_outlined, Icons.wb_twilight, TelaHoje()),
  _Destino('Bíblia', Icons.menu_book_outlined, Icons.menu_book, TelaBiblia()),
  _Destino(
    'Devocional',
    Icons.auto_stories_outlined,
    Icons.auto_stories,
    TelaDevocional(),
  ),
  _Destino('Plano', Icons.event_note_outlined, Icons.event_note, TelaPlano()),
  _Destino('Notas', Icons.bookmark_outline, Icons.bookmark, TelaNotas()),
];

/// Casca de navegação. Barra inferior no celular, trilho lateral em tela larga.
/// O corte em 720 px é onde cinco rótulos deixam de caber com folga na horizontal.
class Moldura extends StatefulWidget {
  const Moldura({super.key});

  @override
  State<Moldura> createState() => _MolduraState();
}

class _MolduraState extends State<Moldura> {
  int _indice = 0;

  /// Um escopo de foco por aba.
  ///
  /// O IndexedStack mantém as cinco telas vivas e interativas, então o teclado
  /// não sabe sozinho a quem obedecer: os atalhos do leitor não chegavam nem
  /// depois de abrir a aba Bíblia, porque o foco ficava no botão da barra de
  /// navegação, e a única forma de levar o foco ao texto seria clicar nele, o
  /// que abre a folha de ações do versículo. Com um escopo por aba, o
  /// `autofocus` de cada tela só vale quando o escopo dela recebe o foco, e
  /// trocar de aba entrega o foco a quem está na frente.
  late final List<FocusScopeNode> _escopos = [
    for (final d in _destinos) FocusScopeNode(debugLabel: d.rotulo),
  ];

  @override
  void dispose() {
    for (final escopo in _escopos) {
      escopo.dispose();
    }
    super.dispose();
  }

  void _irParaAba(int i) {
    setState(() => _indice = i);
    // Depois do frame: antes dele a aba de destino ainda não está na frente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final escopo = _escopos[i];
      // Pedir foco ao escopo deixava o foco no nó do próprio escopo, que fica
      // acima da tela: a tecla subia por fora dos atalhos dela e nada acontecia.
      // O foco precisa cair num nó de dentro.
      final dentro = escopo.traversalDescendants
          .where((n) => n.canRequestFocus)
          .firstOrNull;
      (dentro ?? escopo).requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 720;

    // IndexedStack preserva a posição de rolagem e o capítulo aberto ao alternar
    // de aba, que é o que se espera de um app de leitura.
    //
    // A LarguraDeLeitura não fica aqui. Envolvendo o stack inteiro, ela prendia
    // também a AppBar e a régua de meses do Plano numa faixa de 720 px no meio da
    // janela, e deixava de fora as telas abertas por MaterialPageRoute, que nascem
    // no Navigator raiz: o mesmo leitor ficava com 720 px pela aba e com a janela
    // inteira quando aberto pelo "Continuar leitura". Agora cada tela limita o
    // próprio corpo, e a moldura ocupa a janela como um app de desktop deve.
    final corpo = IndexedStack(
      index: _indice,
      children: [
        for (final (i, d) in _destinos.indexed)
          FocusScope(node: _escopos[i], child: d.tela),
      ],
    );

    if (!largo) {
      return Scaffold(
        body: corpo,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: _irParaAba,
          destinations: [
            for (final d in _destinos)
              NavigationDestination(
                icon: Icon(d.icone),
                selectedIcon: Icon(d.iconeAtivo),
                label: d.rotulo,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _indice,
            onDestinationSelected: _irParaAba,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinos)
                NavigationRailDestination(
                  icon: Icon(d.icone),
                  selectedIcon: Icon(d.iconeAtivo),
                  label: Text(d.rotulo),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: corpo),
        ],
      ),
    );
  }
}
