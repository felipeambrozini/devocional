import 'dart:async';
import 'dart:ui';

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
import 'data/espelho_do_tema.dart';
import 'data/lembretes.dart';
import 'data/modelos.dart';
import 'data/nuvem.dart';
import 'data/personas.dart';
import 'data/planos_nuvem.dart';
import 'data/recursos.dart';
import 'data/registro.dart';
import 'data/voz.dart';
import 'telas/biblia.dart';
import 'telas/chat.dart';
import 'telas/comuns.dart';
import 'telas/conversas.dart';
import 'telas/devocional.dart';
import 'telas/hoje.dart';
import 'telas/historico.dart';
import 'telas/faq.dart';
import 'telas/meu_plano.dart';
import 'telas/notas.dart';
import 'telas/plano.dart';
import 'telas/privacidade.dart';
import 'telas/sobre.dart';
import 'telas/termos.dart';
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

/// Abre a leitura do parâmetro `lembrete` da URL (`?lembrete=manha`) — como o
/// toque na notificação chega na web: o service worker
/// (`web/firebase-messaging-sw.js`) abre essa URL ao ser tocado, em vez de
/// passar pelo SDK nativo do FCM (que [Lembretes.chaveQueAbriuOApp] usa só no
/// Android). Mesmo destino de [_abrirLeituraDoLembrete], só a origem muda.
void _abrirLeituraDoLembreteDoLink() {
  final chave = Uri.base.queryParameters['lembrete'];
  if (chave != null) _abrirLeituraDoLembrete(chave);
}

/// Abre o plano compartilhado do parâmetro `plano` da URL — `?plano=<id>` ou
/// `?plano=<slug-legível>-<id>`, ver [linkDoPlano] — para quem chega por um
/// link divulgado por outra pessoa. Como [_abrirLeituraDoLink], é uma
/// sobreposição por cima de qualquer aba.
void _abrirPlanoDoLink(Estado estado) {
  final parametro = Uri.base.queryParameters['plano'];
  if (parametro == null) return;
  final planoId = idDoParametroDePlano(parametro);
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => TelaDeUmPlano(estado: estado, planoId: planoId),
    ),
  );
}

/// Tudo dentro de uma zona só, para [Registro] pegar também o que escapa de
/// um `try`/`catch` — inclusive o que os `unawaited(...)` abaixo derrubam
/// depois do primeiro quadro, já fora da pilha de chamada do `main`.
Future<void> main() async {
  runZonedGuarded(
    _iniciar,
    (erro, pilha) => Registro.erro('Zona', erro, pilha),
  );
}

Future<void> _iniciar() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (detalhes) {
    Registro.erro('Flutter', detalhes.exception, detalhes.stack);
    FlutterError.presentError(detalhes);
  };
  PlatformDispatcher.instance.onError = (erro, pilha) {
    Registro.erro('Dispatcher', erro, pilha);
    return true;
  };
  await Registro.inicializar();

  // Sem isto a web usa "/#/biblia" (estratégia padrão do Flutter): o # nunca
  // vai ao servidor, então nunca dá 404, mas também não é o link limpo que se
  // quer compartilhar. Com o caminho limpo, quem abre "/biblia" direto cai no
  // rewrite do Firebase Hosting para o index.html (firebase.json) — por isso
  // nada disto tem efeito fora da web.
  if (kIsWeb) usePathUrlStrategy();

  final estado = await Estado.abrir();

  if (nuvemSuportada) {
    // Awaited, ao contrário do resto da Nuvem abaixo: `Lembretes.instancia`
    // usa FirebaseMessaging.instance, que lança se chamado antes do app
    // default do Firebase estar registrado. Sem isto, a linha de baixo
    // quebra com "FirebaseException" toda vez — não uma corrida ocasional,
    // já que ela roda sempre antes do unawaited abaixo terminar.
    try {
      await Nuvem.instancia.iniciarFirebase();
    } catch (erro, pilha) {
      Registro.erro('Nuvem.iniciar', erro, pilha);
    }
    // Sem await: o resto (App Check, listener de login) não bloqueia nada
    // que dependa só do núcleo já pronto acima, e poria uma ida a mais à
    // rede na frente do primeiro quadro.
    unawaited(Nuvem.instancia.iniciar(estado));
    unawaited(PlanosNaNuvem.instancia.iniciar(estado));
  }

  // Numa zona só (comentário acima de `main`) uma falha aqui não impediria
  // o `runApp` de rodar, mas o catch evita depender disso: mesma regra de
  // nunca deixar o Firebase travar a abertura do app.
  String? chaveDeAbertura;
  try {
    await Lembretes.instancia.inicializar(
      aoTocarNotificacao: _abrirLeituraDoLembrete,
    );
    // Sem await: desde a migração para FCM isto envolve rede (Firestore e
    // getToken), e travar o primeiro quadro numa notificação que o usuário
    // nem pediu ainda (só reagendando a de antes) é pior que atrasar por um
    // instante o registro do novo token.
    unawaited(reagendarLembretesSeNecessario(estado));
    // Precisa vir antes do runApp: depois dele o plugin já não sabe dizer que
    // toque abriu o app, só qual chegou com o app já aberto.
    chaveDeAbertura = await Lembretes.instancia.chaveQueAbriuOApp();
  } catch (erro, pilha) {
    Registro.erro('Lembretes.inicializar', erro, pilha);
  }

  runApp(AppDevocional(estado: estado));

  final chave = chaveDeAbertura;
  if (chave != null) {
    // O Navigator só existe depois do primeiro quadro.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _abrirLeituraDoLembrete(chave),
    );
  } else {
    // `chaveDeAbertura` só cobre o toque via SDK nativo do FCM (Android); o
    // toque na notificação da web chega como parâmetro de URL, então cai
    // aqui, no mesmo grupo dos outros links. `?plano`, `?ler` e `?lembrete`
    // não chegam juntos na mesma URL, mas a ordem importa se algum dia
    // coincidirem: plano primeiro, leitura só quando não há plano.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _abrirPlanoDoLink(estado),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirLeituraDoLink());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _abrirLeituraDoLembreteDoLink(),
    );
  }
}

class _Destino {
  const _Destino(
    this.rotulo,
    this.caminho,
    this.icone,
    this.iconeAtivo,
    this.tela, {
    this.mostrarNoRail = true,
  });

  final String rotulo;

  /// Sem acento de propósito, ainda que o rótulo tenha ("Bíblia"): é o que
  /// vira caminho na URL, e o resto do app (canon.dart, chaves de Leitura)
  /// também evita acento em identificador para não depender de como cada
  /// camada decide escapar.
  final String caminho;
  final IconData icone;
  final IconData iconeAtivo;
  final Widget tela;

  /// Em telas largas os balões de conversa substituem a aba: esconder este
  /// destino do NavigationRail mantém a navegação limpa.
  final bool mostrarNoRail;
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
  _Destino(
    'Conversas',
    'conversas',
    Icons.forum_outlined,
    Icons.forum,
    TelaConversas(),
    mostrarNoRail: false,
  ),
];

/// Um nó de foco por aba, criados uma vez para o app inteiro, não por
/// instância da Moldura: as rotas de cada aba são estáticas em [_router], e
/// tanto o `builder` da rota quanto o toque na barra de navegação (em
/// `Moldura._irParaAba`) precisam do mesmo nó.
///
/// Existem porque o shell mantém as abas vivas ao mesmo tempo (para
/// preservar rolagem e capítulo aberto ao trocar de aba) escondendo as
/// inativas com `Offstage`, que não exclui foco — o teclado não saberia a
/// quem obedecer sem um escopo por aba. Mesmo problema, mesma solução de
/// quando isto vivia dentro de `_MolduraState` com um `IndexedStack` cru.
final _escoposDasAbas = [
  for (final d in _destinos) FocusScopeNode(debugLabel: d.rotulo),
];

/// Os destinos que aparecem na navegação nesta sessão: Conversas some
/// enquanto o recurso estiver restrito (ver [Recursos.conversas]) e a conta
/// aberta não for a autorizada. As rotas continuam existindo (ver
/// [_router]) para quem chega direto por link — só a entrada pela barra e
/// pelo trilho é que se esconde.
List<_Destino> get _destinosVisiveis => [
  for (final d in _destinos)
    if (d.caminho != 'conversas' || Recursos.conversas) d,
];

/// Cada aba com o próprio caminho (`/hoje`, `/biblia`, `/devocional`,
/// `/plano`, `/notas`, `/conversas`), para abrir direto por link e sobreviver
/// a um F5 — o Firebase Hosting devolve o index.html para qualquer caminho sob
/// `/devocional/` (rewrite em firebase.json). Sobre e as conversas também têm
/// URL própria, fora do shell: são telas empurradas por cima das abas, não
/// abas. "Conversas" tem `mostrarNoRail: false`: em telas largas os balões de
/// conversa substituem a aba no NavigationRail, mas a rota continua ativa.
///
/// `StatefulShellRoute.indexedStack`, não rotas soltas: rotas soltas
/// trocariam de aba reconstruindo a Moldura do zero, perdendo a rolagem e o
/// capítulo aberto que o antigo `IndexedStack` preservava. O shell preserva
/// isso da mesma forma (por baixo, também é um `Offstage`+`IndexedStack`),
/// só que agora cada aba também tem URL própria.
///
/// Sem `GoRouter.optionURLReflectsImperativeAPIs` (ligada no initState de
/// [AppDevocional]), um `push` a partir de dentro do shell abria a tela por
/// dentro do GoRouter mas deixava a barra de endereço presa na aba — o
/// go_router só reflete na URL as navegações por `go`/`goBranch`; imperativas
/// (push, pushReplacement, replace) ficam de fora por padrão, para trás.
/// Com ela ligada, o push do balão do chat também escreve a URL (e devolve
/// ao fechar), e as abas continuam no `goBranch` de sempre.
final _router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/hoje',
  redirect: (context, state) {
    if (state.uri.path == '/') return '/hoje';
    // Sem o recurso liberado, nem um link direto a Conversas ou a uma
    // persona deve abrir o chat — a mesma restrição que esconde a aba e
    // os balões.
    const caminhosDeConversas = [
      '/conversas',
      '/charles-spurgeon',
      '/felipe-ambrozini',
    ];
    if (!Recursos.conversas &&
        caminhosDeConversas.any((c) => state.uri.path.startsWith(c))) {
      return '/hoje';
    }
    return null;
  },
  observers: [_observadorDeCamadas, _observadorDaVoz],
  errorBuilder: (context, state) {
    // Rota desconhecida (link velho, digitado ou com caminho corrompido):
    // voltar para a primeira aba em vez da tela de erro padrão do go_router.
    WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/hoje'));
    return const SizedBox.shrink();
  },
  routes: [
    // Os chats não são abas: abrem por cima de tudo e merecem URL própria,
    // para sobreviver ao F5 e para um link compartilhado reabrir a conversa.
    // O balão empurra com `push`, não `go`: `go` trocaria a pilha inteira e
    // o chat ficaria sem o botão de voltar. A raiz abre o histórico da
    // persona (ver `lib/telas/historico.dart`); cada conversa é um filho,
    // `conversa` para uma nova e `conversa/:id` para uma específica.
    GoRoute(
      path: '/charles-spurgeon',
      builder: (context, state) => TelaHistorico(persona: personaSpurgeon),
      routes: [
        GoRoute(
          path: 'conversa',
          builder: (context, state) => TelaChat(persona: personaSpurgeon),
        ),
        GoRoute(
          path: 'conversa/:id',
          builder: (context, state) => TelaChat(
            persona: personaSpurgeon,
            conversaId: state.pathParameters['id'],
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/felipe-ambrozini',
      builder: (context, state) => TelaHistorico(persona: personaFelipe),
      routes: [
        GoRoute(
          path: 'conversa',
          builder: (context, state) => TelaChat(persona: personaFelipe),
        ),
        GoRoute(
          path: 'conversa/:id',
          builder: (context, state) => TelaChat(
            persona: personaFelipe,
            conversaId: state.pathParameters['id'],
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/sobre',
      // Sobre não é aba: a navegação inferior tem seis destinos, e o caminho
      // para os créditos fica no fim da folha de ajustes (ver comuns.dart).
      // A URL própria continua valendo para F5 e link compartilhado.
      builder: (context, state) => const TelaSobre(),
    ),
    GoRoute(path: '/faq', builder: (context, state) => const TelaFAQ()),
    GoRoute(
      path: '/privacidade',
      builder: (context, state) => const TelaPrivacidade(),
    ),
    GoRoute(path: '/termos', builder: (context, state) => const TelaTermos()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          Moldura(navigationShell: navigationShell),
      branches: [
        for (final (i, d) in _destinos.indexed)
          // O Devocional não é uma rota só: cada leitura tem a própria
          // (`/manha`, `/promessas`, `/noite`), para a URL dizer o que está
          // na tela e um link compartilhado reabrir a leitura certa. A rota
          // `/devocional` (a da aba) só redireciona para a leitura do
          // horário — sem ela, tocar na aba na primeira vez não teria para
          // onde ir, e links velhos para `/devocional` morreriam.
          if (d.caminho == 'devocional')
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/devocional',
                  redirect: (context, state) {
                    final data = state.uri.queryParameters['data'];
                    final leitura = Leitura.pelaHora(DateTime.now().hour).name;
                    return data == null ? '/$leitura' : '/$leitura?data=$data';
                  },
                ),
                // Sem transição entre as leituras: trocar /manha por
                // /promessas é mudar de conteúdo na mesma aba, não empilhar
                // uma tela sobre outra — a animação de push ficaria estranha.
                for (final l in Leitura.values)
                  GoRoute(
                    path: '/${l.name}',
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: FocusScope(
                        node: _escoposDasAbas[i],
                        child: TelaDevocional(
                          leituraInicial: l,
                          dataInicial: _dataDaRota(state),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          else
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

/// A data escolhida no calendário vem na URL como `?data=AAAA-MM-DD`, para o
/// F5 e um link compartilhado reabrirem o dia certo. `null` (sem parâmetro ou
/// valor inválido) deixa a tela cair no dia de hoje.
DateTime? _dataDaRota(GoRouterState state) {
  final texto = state.uri.queryParameters['data'];
  if (texto == null) return null;
  final data = DateTime.tryParse(texto);
  if (data == null) return null;
  return DateTime(data.year, data.month, data.day);
}

class AppDevocional extends StatefulWidget {
  const AppDevocional({super.key, required this.estado});

  final Estado estado;

  @override
  State<AppDevocional> createState() => _AppDevocionalState();
}

class _AppDevocionalState extends State<AppDevocional>
    with WidgetsBindingObserver {
  late double _escala = widget.estado.escalaDeLeitura;
  late ModoDoTema _modo = widget.estado.modoDoTema;

  @override
  void initState() {
    super.initState();
    // Opção estática do go_router, ligada aqui (e não na inicialização de
    // [_router], que seria preguiçosa): precisa valer desde o primeiro
    // reporte de rota, no app e nos testes. Ver o comentário de [_router].
    GoRouter.optionURLReflectsImperativeAPIs = true;
    widget.estado.addListener(_conferirTema);
    // Para [didChangePlatformBrightness]: no modo Automático, o sistema pode
    // virar o tema com o app aberto, e o espelho do ícone de notificação
    // (web) precisa acompanhar.
    WidgetsBinding.instance.addObserver(this);
    _espelharTema();
  }

  @override
  void didChangePlatformBrightness() {
    _espelharTema();
  }

  @override
  void dispose() {
    widget.estado.removeListener(_conferirTema);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Manda ao Cache Storage o tema efetivo da interface, para o service
  /// worker escolher o ícone da notificação (ver `espelho_do_tema.dart`).
  void _espelharTema() {
    unawaited(
      espelharTemaParaNotificacoes(
        escuro: switch (_modo) {
          ModoDoTema.sistema =>
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark,
          ModoDoTema.escuro => true,
          ModoDoTema.claro => false,
        },
      ),
    );
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
    _espelharTema();
  }

  @override
  Widget build(BuildContext context) {
    return EscopoDoEstado(
      estado: widget.estado,
      child: MaterialApp.router(
        routerConfig: _router,
        title: 'Devocional',
        debugShowCheckedModeBanner: false,
        builder: (context, child) => _ComBaloes(child: child!),
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
/// O corte em 720 px é onde seis rótulos deixam de caber com folga na horizontal.
///
/// Sem estado próprio: quem sabe a aba atual é o [navigationShell], do
/// GoRouter — duplicar isso num `_indice` local só criaria duas fontes de
/// verdade para a mesma coisa.
class Moldura extends StatelessWidget {
  const Moldura({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _irParaAba(int i) {
    // A leitura para ao sair da Bíblia: o shell mantém as abas vivas em
    // Offstage, e o botão de parar sai da tela junto com o leitor. A mesma
    // regra do _ObservadorDaVoz para as rotas empurradas por cima.
    //
    // Pausada de fora (chamada, perda de foco de áudio), a sessão sobrevive
    // à troca de aba: nada está tocando, a regra do botão à vista não se
    // aplica, e quem volta encontra o "Pausado. Toque para retomar." no
    // lugar exato em que a interrupção o deixou.
    if (i != navigationShell.currentIndex && !Voz.instancia.pausado) {
      Voz.instancia.parar();
    }
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
    // Reage ao login: Conversas pode aparecer ou sumir da navegação assim
    // que a conta autorizada entra ou sai, sem esperar uma troca de aba.
    return ListenableBuilder(
      listenable: Nuvem.instancia,
      builder: (context, _) => _conteudo(context),
    );
  }

  Widget _conteudo(BuildContext context) {
    final largo = MediaQuery.sizeOf(context).width >= 720;
    final destinosVisiveis = _destinosVisiveis;

    // A LarguraDeLeitura não fica aqui. Envolvendo o shell inteiro, ela prendia
    // também a AppBar e a régua de meses do Plano numa faixa de 720 px no meio da
    // janela, e deixava de fora as telas abertas por push (como "Sobre" e o
    // "Continuar leitura"), que nascem no Navigator raiz: o mesmo leitor ficava
    // com 720 px pela aba e com a janela inteira quando aberto por fora. Agora
    // cada tela limita o próprio corpo, e a moldura ocupa a janela como um app
    // da web deve.
    if (!largo) {
      // Em tela estreita não há faixa de retratos de conversa nem balões
      // flutuantes: as conversas moram na aba Conversas, e o texto de leitura
      // não disputa viewport com ninguém.
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex.clamp(
            0,
            destinosVisiveis.length - 1,
          ),
          onDestinationSelected: _irParaAba,
          destinations: [
            for (final d in destinosVisiveis)
              NavigationDestination(
                icon: Icon(d.icone),
                selectedIcon: Icon(d.iconeAtivo),
                label: d.rotulo,
              ),
          ],
        ),
      );
    }

    // Em telas largas os balões de conversa substituem a aba: o rail omite
    // Conversas para não duplicar a entrada do chat.
    final destinosDoRail = [
      for (final d in destinosVisiveis)
        if (d.mostrarNoRail) d,
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex.clamp(
              0,
              destinosDoRail.length - 1,
            ),
            onDestinationSelected: _irParaAba,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in destinosDoRail)
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

/// Conta as camadas que flutuam por cima das telas (folha de ajustes, diálogo,
/// seletor de horário) para [camadasFlutuantes] de `lib/telas/chat.dart`: são
/// rotas que não tapam a tela, e por cima delas os balões de conversa
/// atrapalham. Rota opaca (uma tela de verdade, como uma leitura) não mexe no
/// contador: é exatamente por cima dela que os balões devem aparecer. O
/// próprio chat cuida do próprio contador, por isso a [TelaChat] não passa
/// por aqui.
class _ObservadorDeCamadas extends NavigatorObserver {
  bool _eTransparente(Route route) => route is ModalRoute && !route.opaque;

  @override
  void didPush(Route route, Route? previousRoute) {
    if (_eTransparente(route)) camadasFlutuantes.value++;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    // O travamento é só defesa: um `didPop` órfão de um push que o observador
    // não viu (alguma rota criada antes dele) não pode deixar o contador no
    // negativo e esconder os balões para sempre.
    if (_eTransparente(route) && camadasFlutuantes.value > 0) {
      camadasFlutuantes.value--;
    }
  }
}

final _observadorDeCamadas = _ObservadorDeCamadas();

/// Para a voz de Spurgeon quando uma rota opaca cobre a leitura: busca, a
/// introdução, o chat, uma leitura aberta por link. O botão de parar fica
/// soterrado debaixo da tela nova, e a regra é não deixar um áudio tocando
/// sem o seu botão à vista.
///
/// Folha e diálogo (rotas transparentes) não passam por aqui: a tela de
/// leitura continua visível e o botão, alcançável.
class _ObservadorDaVoz extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is ModalRoute && route.opaque) Voz.instancia.parar();
  }
}

final _observadorDaVoz = _ObservadorDaVoz();

/// Pendura os dois balões de conversa por cima das telas largas: Spurgeon à
/// esquerda, Felipe à direita.
///
/// Em tela estreita não existem: as conversas entram pela aba Conversas, e um
/// balão flutuante por cima do texto de leitura não volta. Em telas largas os
/// balões substituem a aba no NavigationRail — que omite "Conversas" —, mas a
/// rota `/conversas` continua ativa para quem chega por link direto. Somem
/// quando [camadasFlutuantes] passa de zero, e reaparecem quando a camada
/// fecha. A preferência gravada (`estado.baloesVisiveis`) continua valendo.
class _ComBaloes extends StatelessWidget {
  const _ComBaloes({required this.child});

  final Widget child;

  void _abrirChat(Persona persona) {
    _router.push('/${persona.slug}');
  }

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    return ListenableBuilder(
      listenable: Listenable.merge([camadasFlutuantes, Nuvem.instancia]),
      builder: (context, _) {
        if (!estado.baloesVisiveis || !Recursos.conversas) return child;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Tela estreita: os retratos estão na faixa da Moldura, não aqui.
            // Este overlay só existe para as telas largas, onde os cantos de
            // baixo ficam vazios e o balão não tampa a leitura.
            if (constraints.maxWidth < 720) return child;
            return Stack(
              children: [
                child,
                if (camadasFlutuantes.value == 0) ...[
                  // O Tooltip do balão exige um Overlay por cima, e aqui
                  // estamos fora do Navigator (que é quem provê o Overlay do
                  // app). Este Overlay aninhado existe só para os balões e as
                  // suas dicas; nada de rota ou diálogo nasce aqui dentro.
                  Overlay(
                    initialEntries: [
                      OverlayEntry(
                        builder: (context) => Stack(
                          children: [
                            // Em tela larga quem ocupa o canto esquerdo é o
                            // trilho lateral: o balão dele pula para dentro do
                            // conteúdo, e o da direita fica na esquina.
                            Positioned(
                              left: 96,
                              bottom: 12,
                              child: BalaoDeChat(
                                persona: personaSpurgeon,
                                onTap: () => _abrirChat(personaSpurgeon),
                              ),
                            ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: BalaoDeChat(
                                persona: personaFelipe,
                                onTap: () => _abrirChat(personaFelipe),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
