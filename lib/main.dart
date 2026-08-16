import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Não `flutter_web_plugins.dart` (o barril): ele também exporta o registro de
// plugins, que importa `dart:ui_web` sem condicional e quebra a compilação
// para a VM — é o que `flutter test` usa. Este arquivo é condicional de
// propósito: no-op fora da web, implementação de verdade só nela.
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

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
import 'telas/sobre.dart';
import 'theme.dart';

/// De módulo, e não de um State: o toque numa notificação chega por um
/// callback do plugin que não tem `BuildContext` de tela nenhuma, e pode
/// acontecer com o app em qualquer lugar da árvore. Também é o
/// `navigatorKey` do próprio GoRouter (abaixo), então continua sendo o
/// Navigator raiz para os dois casos.
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
///
/// Independente das rotas de aba abaixo: é uma sobreposição por cima de
/// qualquer aba, lida direto de `Uri.base`, não do caminho que o GoRouter viu.
void _abrirLeituraDoLink() {
  final parametro = Uri.base.queryParameters['ler'];
  if (parametro == null) return;
  final alvo = alvoDoLink(parametro);
  if (alvo == null) return;
  final (slug, capitulo, versiculo) = alvo;
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => TelaBiblia(
        livroInicial: slug,
        capituloInicial: capitulo,
        destacar: versiculo == null ? null : (versiculo, versiculo),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sem isto a web usa "/#/biblia" (estratégia padrão do Flutter): o # nunca
  // vai ao servidor, então nunca dá 404, mas também não é o link limpo que se
  // quer compartilhar. Com o caminho limpo, quem abre "/biblia" direto passa
  // por web/404.html e web/index.html (ver os dois) antes do Flutter ler a
  // URL — por isso nada disto tem efeito fora da web.
  if (kIsWeb) usePathUrlStrategy();

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

class _Destino {
  const _Destino(
    this.rotulo,
    this.caminho,
    this.icone,
    this.iconeAtivo,
    this.tela,
  );

  final String rotulo;

  /// Sem acento de propósito, ainda que o rótulo tenha ("Bíblia"): é o que
  /// vira caminho na URL, e o resto do app (canon.dart, chaves de Leitura)
  /// também evita acento em identificador para não depender de como cada
  /// camada decide escapar.
  final String caminho;
  final IconData icone;
  final IconData iconeAtivo;
  final Widget tela;
}

const _destinos = <_Destino>[
  _Destino(
    'Hoje',
    'hoje',
    Icons.wb_twilight_outlined,
    Icons.wb_twilight,
    TelaHoje(),
  ),
  _Destino(
    'Bíblia',
    'biblia',
    Icons.menu_book_outlined,
    Icons.menu_book,
    TelaBiblia(),
  ),
  _Destino(
    'Devocional',
    'devocional',
    Icons.auto_stories_outlined,
    Icons.auto_stories,
    TelaDevocional(),
  ),
  _Destino(
    'Plano',
    'plano',
    Icons.event_note_outlined,
    Icons.event_note,
    TelaPlano(),
  ),
  _Destino(
    'Notas',
    'notas',
    Icons.bookmark_outline,
    Icons.bookmark,
    TelaNotas(),
  ),
  // Não é uma leitura como as outras cinco, mas ganhar uma URL própria pedia
  // isso — empurrar por cima com `Navigator.push`/`GoRouter.push` nunca
  // atualizava a barra de endereço ao sair de dentro de uma aba do shell, só
  // dentro do próprio GoRouter (confirmado num teste de widget: o estado
  // interno virava "/sobre" certinho, mas a URL do navegador não seguia).
  // Como aba, usa o mesmo `goBranch` que já as outras cinco já provam
  // funcionar. Ver a seção "Web" do README.
  _Destino('Sobre', 'sobre', Icons.info_outline, Icons.info, TelaSobre()),
];

/// Um nó de foco por aba, criados uma vez para o app inteiro, não por
/// instância da Moldura: as rotas de cada aba são estáticas em [_router], e
/// tanto o `builder` da rota quanto o toque na barra de navegação (em
/// `Moldura._irParaAba`) precisam do mesmo nó.
///
/// Existem porque o shell mantém as seis abas vivas ao mesmo tempo (para
/// preservar rolagem e capítulo aberto ao trocar de aba) escondendo as
/// inativas com `Offstage`, que não exclui foco — o teclado não saberia a
/// quem obedecer sem um escopo por aba. Mesmo problema, mesma solução de
/// quando isto vivia dentro de `_MolduraState` com um `IndexedStack` cru.
final _escoposDasAbas = [
  for (final d in _destinos) FocusScopeNode(debugLabel: d.rotulo),
];

/// Cada aba com o próprio caminho (`/hoje`, `/biblia`, ..., `/sobre`), para
/// abrir direto por link e sobreviver a um F5 — o GitHub Pages não tem regra
/// de reescrita, por isso o truque em web/404.html e web/index.html.
///
/// `StatefulShellRoute.indexedStack`, não rotas soltas: rotas soltas
/// trocariam de aba reconstruindo a Moldura do zero, perdendo a rolagem e o
/// capítulo aberto que o antigo `IndexedStack` preservava. O shell preserva
/// isso da mesma forma (por baixo, também é um `Offstage`+`IndexedStack`),
/// só que agora cada aba também tem URL própria.
final _router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/hoje',
  redirect: (context, state) => state.uri.path == '/' ? '/hoje' : null,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          Moldura(navigationShell: navigationShell),
      branches: [
        for (final (i, d) in _destinos.indexed)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/${d.caminho}',
                builder: (context, state) =>
                    FocusScope(node: _escoposDasAbas[i], child: d.tela),
              ),
            ],
          ),
      ],
    ),
  ],
);

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
      child: MaterialApp.router(
        routerConfig: _router,
        title: 'Devocional',
        debugShowCheckedModeBanner: false,
        // A escala de texto do aparelho (2x no Android, etc.) sempre foi
        // ignorada: o app respondia só com os cinco passos próprios, que
        // param em 1,5x. Aqui a escala do sistema passa a multiplicar tudo
        // por cima, limitada a 2x para não quebrar o layout da navegação.
        // Quem precisa de 2x no aparelho recebe 2x, somada à escala própria
        // de leitura (que continua multiplicando só o texto corrido).
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 2.0,
          child: child!,
        ),
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

/// Casca de navegação. Barra inferior no celular, trilho lateral em tela larga.
/// O corte em 720 px é onde cinco rótulos deixam de caber com folga na horizontal.
///
/// Sem estado próprio: quem sabe a aba atual é o [navigationShell], do
/// GoRouter — duplicar isso num `_indice` local só criaria duas fontes de
/// verdade para a mesma coisa.
class Moldura extends StatelessWidget {
  const Moldura({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _irParaAba(int i) {
    navigationShell.goBranch(
      i,
      initialLocation: i == navigationShell.currentIndex,
    );
    // Depois do frame: antes dele a aba de destino ainda não está na frente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final escopo = _escoposDasAbas[i];
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

    // A LarguraDeLeitura não fica aqui. Envolvendo o shell inteiro, ela prendia
    // também a AppBar e a régua de meses do Plano numa faixa de 720 px no meio da
    // janela, e deixava de fora as telas abertas por push (como "Sobre" e o
    // "Continuar leitura"), que nascem no Navigator raiz: o mesmo leitor ficava
    // com 720 px pela aba e com a janela inteira quando aberto por fora. Agora
    // cada tela limita o próprio corpo, e a moldura ocupa a janela como um app
    // de desktop deve.
    if (!largo) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
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
            selectedIndex: navigationShell.currentIndex,
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
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
