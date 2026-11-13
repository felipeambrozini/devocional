import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Não `flutter_web_plugins.dart` (o barril): ele também exporta o registro de
// plugins, que importa `dart:ui_web` sem condicional e quebra a compilação
// para a VM — é o que `flutter test` usa. Este arquivo é condicional de
// propósito: no-op fora da web, implementação de verdade só nela.
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'dados/canon.dart';
import 'dados/config_admin.dart';
import 'dados/estado.dart';
import 'dados/espelho_do_tema.dart';
import 'dados/lembretes.dart';
import 'dados/modelos.dart';
import 'dados/nuvem.dart';
import 'dados/personas.dart';
import 'dados/planos.dart';
import 'dados/planos_nuvem.dart';
import 'dados/recursos.dart';
import 'dados/registro.dart';
import 'dados/url_da_pagina.dart';
import 'dados/voz.dart';
import 'estilo/tema.dart';
import 'funcoes/lembretes_acoes.dart';
import 'telas/admin.dart';
import 'telas/biblia.dart';
import 'telas/biblioteca.dart';
import 'telas/chat.dart';
import 'telas/conversas.dart';
import 'telas/devocional.dart';
import 'telas/faq.dart';
import 'telas/historico.dart';
import 'telas/hoje.dart';
import 'telas/leitor_de_livro.dart';
import 'telas/livro.dart';
import 'telas/meu_plano.dart';
import 'telas/notas.dart';
import 'telas/novo_plano.dart';
import 'telas/plano.dart';
import 'telas/privacidade.dart';
import 'telas/sobre.dart';
import 'telas/termos.dart';
import 'widgets/widgets.dart';

/// Ponto de entrada do app: sem coleta remota (sem Sentry, sem Analytics).
/// Erro vai para console e arquivo local (ver `Registro`), nunca para rede.

/// De módulo, e não de um State: o toque numa notificação chega por um
/// callback do plugin que não tem `BuildContext` de tela nenhuma, e pode
/// acontecer com o app em qualquer lugar da árvore. Também é o
/// `navigatorKey` do próprio GoRouter (abaixo), então continua sendo o
/// Navigator raiz para os dois casos.
final navigatorKey = GlobalKey<NavigatorState>();

/// Leva à aba certa para a notificação tocada: Plano para "leitura" (que já
/// abre no dia de hoje sozinho) e Devocional, na leitura certa, para as
/// outras três. `chave` é "manha", "promessas", "leitura" ou "noite" — ver o
/// contrato em `lib/dados/lembretes.dart`.
///
/// Respeita os interruptores do painel: tocar num lembrete de leitura
/// desligada não abre a tela desativada (que mostra o cartão de
/// "desativada temporariamente" em `TelaDevocional`) — cai na Hoje, como se
/// o lembrete não existisse, em vez de levar a um beco sem conteúdo.
void _abrirLeituraDoLembrete(String chave) {
  if (chave == 'leitura') {
    if (!Recursos.cronograma) {
      _router.go('/hoje');
      return;
    }
    _router.go('/plano');
    return;
  }
  final leitura = Leitura.values.where((l) => l.name == chave).firstOrNull;
  if (leitura == null) return;
  if (!leituraAtiva(leitura)) {
    _router.go('/hoje');
    return;
  }
  _router.go('/${leitura.name}');
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
  // O push acima é direto no Navigator, não no GoRouter: a barra de
  // endereço nunca seria atualizada por ele (ver `url_da_pagina_web.dart`),
  // e ficaria com `?ler=` presa mesmo depois de sair da tela.
  removerParametroDaUrl('ler');
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
  // Mesmo motivo de `_abrirLeituraDoLink`: este push não passa pelo
  // GoRouter, então a barra de endereço ficaria com `?plano=` presa.
  removerParametroDaUrl('plano');
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

/// O convite do chat é da conta aberta: cada mudança na [Nuvem] (entrar, sair,
/// trocar de conta) refaz a escuta, que ignora a chamada se o e-mail é o mesmo.
void _ouvirConviteDaConta() =>
    ConfigAdmin.instancia.ouvirConvite(Nuvem.instancia.email);

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
  Voz.instancia
    ..restaurarVelocidade(estado.velocidadeDaVoz)
    ..aoMudarVelocidade = estado.definirVelocidadeDaVoz;

  // Awaited, ao contrário do resto da Nuvem abaixo: Auth e Firestore lançam
  // se chamados antes do app default do Firebase estar registrado. Sem
  // isto, a sincronia quebra com "FirebaseException" toda vez — não uma
  // corrida ocasional, já que ela roda sempre antes do unawaited abaixo
  // terminar.
  try {
    await Nuvem.instancia.iniciarFirebase();
  } catch (erro, pilha) {
    Registro.erro('Nuvem.iniciar', erro, pilha);
  }
  // Sem await: o resto (App Check, listener de login, config remota) não
  // bloqueia nada que dependa só do núcleo já pronto acima, e poria uma ida
  // a mais à rede na frente do primeiro quadro. PlanosNaNuvem, ConfigAdmin
  // e o reagendamento dos lembretes só entram depois de Nuvem.iniciar
  // terminar (App Check incluso): sem isto, com uma sessão já em cache, o
  // listener de cada um — e a escrita anônima em `lembretes/{token}` —
  // dispara a consulta ao Firestore antes de o App Check ter o token
  // pronto, e o Firestore recusa com o mesmo PERMISSION_DENIED genérico de
  // uma regra, sem outra tentativa.
  unawaited(
    Nuvem.instancia.iniciar(estado).then((_) {
      unawaited(PlanosNaNuvem.instancia.iniciar(estado));
      unawaited(ConfigAdmin.instancia.iniciar());
      _ouvirConviteDaConta();
      Nuvem.instancia.addListener(_ouvirConviteDaConta);
      unawaited(reagendarLembretesSeNecessario(estado));
    }),
  );

  // Numa zona só (comentário acima de `main`) uma falha aqui não impediria
  // o `runApp` de rodar, mas o catch evita depender disso: mesma regra de
  // nunca deixar o Firebase travar a abertura do app.
  String? chaveDeAbertura;
  try {
    await Lembretes.instancia.inicializar(
      aoTocarNotificacao: _abrirLeituraDoLembrete,
    );
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
    // `chaveDeAbertura` só cobre o toque na notificação local (Android); o
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

/// Abre a leitura do parâmetro `lembrete` da URL (`?lembrete=manha`) — como o
/// toque na notificação chega na web: o service worker
/// (`web/firebase-messaging-sw.js`) abre essa URL ao ser tocado. Mesmo
/// destino de [_abrirLeituraDoLembrete], só a origem muda.
void _abrirLeituraDoLembreteDoLink() {
  final chave = Uri.base.queryParameters['lembrete'];
  if (chave == null) return;
  _abrirLeituraDoLembrete(chave);
  // Mesmo motivo de `_abrirLeituraDoLink`: [_abrirLeituraDoLembrete] empurra
  // direto no Navigator, não no GoRouter, e a barra de endereço ficaria com
  // `?lembrete=` presa — reabrir a mesma notificação de novo (o service
  // worker reaproveita a aba, `web/firebase-messaging-sw.js`) precisa achar
  // a URL limpa, não um link já consumido.
  removerParametroDaUrl('lembrete');
}

const _destinos = <DestinoDaMoldura>[
  DestinoDaMoldura(
    'Hoje',
    'hoje',
    FontAwesomeIcons.sun,
    FontAwesomeIcons.solidSun,
    TelaHoje(),
  ),
  DestinoDaMoldura(
    'Bíblia',
    'biblia',
    FontAwesomeIcons.bookBible,
    FontAwesomeIcons.bookBible,
    TelaBiblia(),
  ),
  DestinoDaMoldura(
    'Devocional',
    'devocional',
    FontAwesomeIcons.featherPointed,
    FontAwesomeIcons.featherPointed,
    TelaDevocional(),
  ),
  DestinoDaMoldura(
    'Biblioteca',
    'biblioteca',
    FontAwesomeIcons.bookBookmark,
    FontAwesomeIcons.bookBookmark,
    TelaBiblioteca(),
  ),
  DestinoDaMoldura(
    'Plano',
    'plano',
    FontAwesomeIcons.calendarDays,
    FontAwesomeIcons.solidCalendarDays,
    TelaPlano(),
  ),
  DestinoDaMoldura(
    'Conversas',
    'conversas',
    FontAwesomeIcons.comments,
    FontAwesomeIcons.solidComments,
    TelaConversas(),
  ),
];

/// Um nó de foco por aba, criados uma vez para o app inteiro, não por
/// instância da DevocionalMoldura: as rotas de cada aba são estáticas em [_router], e
/// tanto o `builder` da rota quanto o toque na barra de navegação (em
/// `DevocionalMoldura._irParaAba`) precisam do mesmo nó.
///
/// Existem porque o shell mantém as abas vivas ao mesmo tempo (para
/// preservar rolagem e capítulo aberto ao trocar de aba) escondendo as
/// inativas com `Offstage`, que não exclui foco — o teclado não saberia a
/// quem obedecer sem um escopo por aba. Mesmo problema, mesma solução de
/// quando isto vivia dentro de `_MolduraState` com um `IndexedStack` cru.
final _escoposDasAbas = [
  for (final d in _destinos) FocusScopeNode(debugLabel: d.rotulo),
];

/// Cada aba com o próprio caminho (`/hoje`, `/biblia`, `/devocional`,
/// `/plano`, `/biblioteca`, `/conversas`), para abrir direto por link e sobreviver
/// a um F5 — o Firebase Hosting devolve o index.html para qualquer caminho sob
/// `/devocional/` (rewrite em firebase.json). Sobre e as conversas também têm
/// URL própria, fora do shell: são telas empurradas por cima das abas, não
/// abas.
///
/// `StatefulShellRoute.indexedStack`, não rotas soltas: rotas soltas
/// trocariam de aba reconstruindo a DevocionalMoldura do zero, perdendo a rolagem e o
/// capítulo aberto que o antigo `IndexedStack` preservava. O shell preserva
/// isso da mesma forma (por baixo, também é um `Offstage`+`IndexedStack`),
/// só que agora cada aba também tem URL própria.
///
/// Sem `GoRouter.optionURLReflectsImperativeAPIs` (ligada no initState de
/// [AppDevocional]), um `push` a partir de dentro do shell abria a tela por
/// dentro do GoRouter mas deixava a barra de endereço presa na aba — o
/// go_router só reflete na URL as navegações por `go`/`goBranch`; imperativas
/// (push, pushReplacement, replace) ficam de fora por padrão, para trás.
/// Com ela ligada, o push do chat também escreve a URL (e devolve
/// ao fechar), e as abas continuam no `goBranch` de sempre.
final _router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/hoje',
  // Reavalia o redirect quando a configuração remota chega ou quando a
  // Nuvem fica pronta: sem a Nuvem aqui, um link de chat aberto antes do App
  // Check terminar (`Nuvem.email` some até `_pronta` virar true) seria
  // devolvido para /hoje mesmo com o e-mail já na allowlist, e o `notifyListeners`
  // de `authStateChanges` que chega depois não reavaliaria a rota.
  refreshListenable: Listenable.merge([ConfigAdmin.instancia, Nuvem.instancia]),
  redirect: (context, state) {
    if (state.uri.path == '/') return '/hoje';
    // O painel admin é só web e só do dono: link direto fora disso volta
    // para a Hoje em vez de mostrar o motivo (a tela também se defende).
    if (state.uri.path.startsWith('/admin') && !Recursos.adminNaWeb) {
      return '/hoje';
    }
    // Biblioteca desligada no painel: a aba mostra o aviso, e o link direto
    // para um livro volta para a estante.
    if (state.uri.path.startsWith('/biblioteca/') && !Recursos.biblioteca) {
      return '/biblioteca';
    }
    // A aba Conversas é livre para todo mundo (ver TelaConversas, que troca
    // as cartas pelo convite ao WhatsApp sem o recurso). Só o chat de cada
    // persona continua trancado por link direto — é ele que chama a API
    // paga.
    if (!Recursos.conversas &&
        todasAsPersonas.any((p) => state.uri.path.startsWith('/${p.slug}'))) {
      return '/hoje';
    }
    return null;
  },
  observers: [_observadorDaVoz],
  errorBuilder: (context, state) {
    // Rota desconhecida (link velho, digitado ou com caminho corrompido):
    // voltar para a primeira aba em vez da tela de erro padrão do go_router.
    WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/hoje'));
    return const SizedBox.shrink();
  },
  routes: [
    // Os chats não são abas: abrem por cima de tudo e merecem URL própria,
    // para sobreviver ao F5 e para um link compartilhado reabrir a conversa.
    // A carta empurra com `push`, não `go`: `go` trocaria a pilha inteira e
    // o chat ficaria sem o botão de voltar. A raiz abre o histórico da
    // persona (ver `lib/telas/historico.dart`); cada conversa é um filho,
    // `conversa` para uma nova e `conversa/:id` para uma específica.
    for (final persona in todasAsPersonas)
      GoRoute(
        path: '/${persona.slug}',
        builder: (context, state) => TelaHistorico(persona: persona),
        routes: [
          GoRoute(
            path: 'conversa',
            builder: (context, state) => TelaChat(persona: persona),
          ),
          GoRoute(
            path: 'conversa/:id',
            builder: (context, state) => TelaChat(
              persona: persona,
              conversaId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
    GoRoute(
      path: '/sobre',
      // Sobre não é aba: a navegação inferior tem seis destinos, e o caminho
      // para os créditos fica no fim da folha de ajustes (ver
      // widgets/folha_de_ajustes.dart).
      // A URL própria continua valendo para F5 e link compartilhado.
      builder: (context, state) => const TelaSobre(),
    ),
    GoRoute(path: '/faq', builder: (context, state) => const TelaFAQ()),
    // Notas não é aba (a barra de baixo tem seis destinos): abre por cima, pelo
    // ícone de marcador da barra de cima do Devocional e da Bíblia.
    GoRoute(path: '/notas', builder: (context, state) => const TelaNotas()),
    GoRoute(path: '/admin', builder: (context, state) => const TelaAdmin()),
    GoRoute(
      path: '/privacidade',
      builder: (context, state) => const TelaPrivacidade(),
    ),
    GoRoute(path: '/termos', builder: (context, state) => const TelaTermos()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => DevocionalMoldura(
        navigationShell: navigationShell,
        destinos: _destinos,
        escoposDasAbas: _escoposDasAbas,
      ),
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
                        child: DevocionalAncoraDeFoco(
                          child: TelaDevocional(
                            leituraInicial: l,
                            dataInicial: _dataDaRota(state),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          else if (d.caminho == 'biblioteca')
            // O sumário e o capítulo moram dentro da aba, cada um com URL própria:
            // a barra de baixo continua à vista e o F5 reabre o capítulo.
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/${d.caminho}',
                  builder: (context, state) => FocusScope(
                    node: _escoposDasAbas[i],
                    child: DevocionalAncoraDeFoco(child: d.tela),
                  ),
                  routes: [
                    GoRoute(
                      path: ':slug',
                      builder: (context, state) => DevocionalAncoraDeFoco(
                        child: TelaDoLivro(slug: state.pathParameters['slug']!),
                      ),
                      routes: [
                        GoRoute(
                          path: ':capitulo',
                          builder: (context, state) => TelaLeitorDeLivro(
                            slug: state.pathParameters['slug']!,
                            capitulo:
                                int.tryParse(
                                  state.pathParameters['capitulo']!,
                                ) ??
                                0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            )
          else if (d.caminho == 'plano')
            // Novo plano e o detalhe de um plano viram rotas próprias (não um
            // Navigator.push avulso): é o que faz `goBranch(initialLocation:
            // true)` descartar o plano aberto ao voltar para esta aba (ver
            // `DevocionalMoldura._irParaAba`) — uma rota empurrada por fora do
            // go_router sobrevive ao reset, porque o go_router não sabe que
            // ela existe.
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/${d.caminho}',
                  builder: (context, state) => FocusScope(
                    node: _escoposDasAbas[i],
                    child: DevocionalAncoraDeFoco(child: d.tela),
                  ),
                  routes: [
                    GoRoute(
                      path: 'novo',
                      builder: (context, state) => DevocionalAncoraDeFoco(
                        child: TelaNovoPlano(
                          estado: EscopoDoEstado.de(context),
                        ),
                      ),
                    ),
                    GoRoute(
                      path: ':id',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        final estado = EscopoDoEstado.de(context);
                        return DevocionalAncoraDeFoco(
                          child: TelaDeUmPlano(
                            estado: estado,
                            planoId: id,
                            plano: estado.planoDoUsuario(id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            )
          else
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/${d.caminho}',
                  builder: (context, state) => FocusScope(
                    node: _escoposDasAbas[i],
                    child: DevocionalAncoraDeFoco(child: d.tela),
                  ),
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
    Nuvem.instancia.addListener(_conferirBoasVindas);
    // Sessão já em cache: o Nuvem pode ter avisado antes de esta tela existir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _conferirBoasVindas());
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
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    switch (estado) {
      // Sem forçar: o SDK só renova o token do App Check se ele expirou.
      case AppLifecycleState.resumed:
        unawaited(Nuvem.instancia.revalidarAppCheck(forcar: false));
      // O app pode ser fechado em seguida e levar junto o debounce de 2 s.
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        unawaited(Nuvem.instancia.despejarSincronias());
      default:
    }
  }

  @override
  void dispose() {
    widget.estado.removeListener(_conferirTema);
    Nuvem.instancia.removeListener(_conferirBoasVindas);
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

  /// Na primeira vez que há conta aberta neste aparelho, dá as boas-vindas e
  /// apresenta o plano fixo "A Vida de Jesus em 30 dias". Marca como visto antes de
  /// mostrar: fechar o diálogo de qualquer jeito não o traz de volta.
  ///
  /// Antes delas, o consentimento da LGPD, se ainda não há um neste aparelho.
  void _conferirBoasVindas() {
    final estado = widget.estado;
    final contexto = navigatorKey.currentContext;
    if (!Nuvem.instancia.logado || contexto == null) return;
    if (!estado.consentimentoDaNuvem) return _pedirConsentimento(contexto);
    if (estado.boasVindasVistas) return;
    unawaited(estado.marcarBoasVindasVistas());
    showDialog<bool>(
      context: contexto,
      builder: (_) => const DevocionalBoasVindasDialogo(),
    ).then((verPlano) {
      if (verPlano != true) return;
      _router.go('/plano');
      _router.push('/plano/$idDoPlanoDeJesus');
    });
  }

  bool _pedindoConsentimento = false;

  /// Conta aberta sem consentimento registrado neste aparelho: quem entrou
  /// antes de o pedido existir, ou num aparelho onde a sessão já estava
  /// aberta. Quem recusa sai da conta, e a cópia na nuvem continua apagável
  /// em Sobre.
  void _pedirConsentimento(BuildContext contexto) {
    if (_pedindoConsentimento) return;
    _pedindoConsentimento = true;
    showDialog<void>(
      context: contexto,
      barrierDismissible: false,
      // Sem fechar pelo voltar do Android nem pelo gesto do leitor de tela:
      // a conta ficaria aberta sem consentimento e sem escolha feita.
      builder: (_) => PopScope(
        canPop: false,
        child: DevocionalConsentimentoDaNuvem(
          rotuloDeConcordar: 'Concordo',
          rotuloDeRecusar: 'Sair da conta',
          aoConcordar: () {
            unawaited(widget.estado.registrarConsentimentoDaNuvem());
            _conferirBoasVindas();
          },
          aoRecusar: () => unawaited(Nuvem.instancia.sair()),
        ),
      ),
    ).whenComplete(() => _pedindoConsentimento = false);
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
        builder: (context, child) => DevocionalEsconderMovimento(child: child!),
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
