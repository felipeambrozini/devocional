import 'dart:async';
import 'dart:ui' show DartPluginRegistrant, PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter/material.dart' show Brightness, Color, TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as banco_de_fusos;
import 'package:timezone/timezone.dart' as tz;

import 'estado.dart';
import 'modelos.dart' show ModoDoTema;
import 'registro.dart';

/// Chave pública do Web Push (Console do Firebase > Cloud Messaging > Web
/// configuration > Generate key pair). Não é segredo — é a metade pública do
/// par VAPID — mas segue o padrão `--dart-define` das outras chaves em
/// `lib/data/nuvem.dart`. Vazia faz `getToken` falhar só na web.
const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Service worker que o SDK do FCM usa para receber o push na web.
///
/// Precisa ser passado à mão: sem ele o SDK registra por conta própria
/// `/firebase-messaging-sw.js` **na raiz do domínio**, e o app mora em
/// `/devocional/` — na raiz o Hosting devolve a página 404 em HTML, o
/// registro falha por tipo MIME e `getToken` lança. Resultado: nenhum token
/// web chegava ao Firestore, e a Function não tinha para quem enviar.
///
/// Relativo de propósito: resolve contra o `<base href>` de `web/index.html`,
/// o mesmo caminho que o registro manual de lá já usa — então o navegador
/// reaproveita aquele registro em vez de criar um segundo.
const _caminhoDoServiceWorker = 'firebase-messaging-sw.js';

/// Se o aparelho/ambiente tem como receber o lembrete: **Android e web**.
///
/// Híbrido: o push vem da Cloud Function agendada
/// (`functions/src/index.ts`, infra do Google — sem os atrasos do cron do
/// GitHub que matou a primeira versão) via FCM data-only, e cada lado exibe
/// por conta própria — aqui no Android, notificação local deste arquivo; na
/// web, o service worker (`web/firebase-messaging-sw.js`). No Android ainda
/// há um lembrete local recorrente em T+5 min, para o caso de a Function
/// falhar — `flutter_local_notifications_web` não implementa `zonedSchedule`
/// (lança `UnsupportedError`), então a web não tem como ter o mesmo reforço
/// e depende inteiramente do push. iOS fica de fora: precisaria da chave
/// APNs cadastrada no Console.
bool get lembretesSuportados =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android;

bool get _ehAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const _canalLembretes = 'lembretes_devocional';

/// Minutos entre o horário escolhido e o lembrete local de reserva: se às 6h
/// nada chegou do servidor, às 6h05 o próprio aparelho avisa. O mesmo valor
/// é a régua de corte do outro lado — um push mais de
/// [atrasoDoFallbackMinutos] atrasado já foi coberto pela reserva daquele dia
/// e seria só ruído (ver [pushAindaVale]).
const atrasoDoFallbackMinutos = 5;

// Um id por slot, recorrente (ver `_armar`/`matchDateTimeComponents`): o
// próprio Android reagenda a próxima ocorrência ao disparar, sem depender do
// app reabrir. Exibidas pelo push usam outra faixa de id (`_idDaExibida`).
const _idAlarmeManha = 1101;
const _idAlarmePromessas = 1501;
const _idAlarmeLeitura = 1701;
const _idAlarmeNoite = 2101;

int _idDaExibida(String chave) => switch (chave) {
  'noite' => 3201,
  'promessas' => 3401,
  'leitura' => 3701,
  _ => 3101,
};

/// Mesma família de `_idDaExibida`, mas para o alarme de reserva — precisa
/// mapear de volta da chave para o id correndo em [_pularReservaDeHoje].
int? _idDoAlarme(String chave) => switch (chave) {
  'manha' => _idAlarmeManha,
  'promessas' => _idAlarmePromessas,
  'leitura' => _idAlarmeLeitura,
  'noite' => _idAlarmeNoite,
  _ => null,
};

String? _tituloDoAlarme(String chave) => switch (chave) {
  'manha' => 'Devocional da Manhã',
  'promessas' => 'Promessas de Deus',
  'leitura' => 'Leitura do Dia',
  'noite' => 'Devocional da Noite',
  _ => null,
};

/// Texto de reserva quando o conteúdo do dia não carrega (asset ausente,
/// erro de leitura): melhor avisar genérico do que calar.
const _corpoGenerico = 'Está na hora da leitura de hoje. Toque para abrir.';

/// Minutos de atraso de [agoraMinuto] sobre [alvoMinuto], considerando a
/// virada da meia-noite (alvo 23:55, agora 00:03 → 8). Réplica da função de
/// mesmo papel em `functions/src/index.ts` — este arquivo importa Flutter, e
/// a Function roda em Node, então não há como partilhar.
int _atrasoEmMinutos(int agoraMinuto, int alvoMinuto) {
  final diferenca = (agoraMinuto - alvoMinuto) % 1440;
  return diferenca < 0 ? diferenca + 1440 : diferenca;
}

/// Se um push que chegou agora ainda deve ser exibido. Depois de
/// [atrasoDoFallbackMinutos] do horário cadastrado, o alarme local de
/// reserva já avisou o usuário — exibir o push tardio seria segunda
/// notificação para a mesma leitura. Público para o teste poder cobrir a
/// regra sem Firebase.
bool pushAindaVale({required int minutoAgora, required int minutoAlvo}) =>
    _atrasoEmMinutos(minutoAgora, minutoAlvo) <= atrasoDoFallbackMinutos;

/// Nome do drawable único do ícone pequeno da notificação. Um só arquivo,
/// sem variante clara/escura: desde o Android 5 (API 21) o ícone da barra de
/// status é tratado como máscara alfa — a cor do PNG é sempre descartada e
/// repintada pelo sistema — então trocar de arquivo por tema não muda nada
/// visível e só era uma fonte a mais de `PlatformException(invalid_icon)`.
const _iconeLembrete = 'ic_lembete';

/// Mesmo par de destaque de `lib/estilo/theme.dart` (`Cores.dourado`/
/// `Cores.bronze`), duplicado aqui em vez de importado: `lib/data` não
/// depende do pacote de estilo, e são só dois inteiros — a duplicação vale
/// menos que o acoplamento entre camadas.
const _douradoDoTemaEscuro = Color(0xFFC9A227);
const _bronzeDoTemaClaro = Color(0xFF7A5C12);

/// Cor do círculo de destaque atrás do ícone na gaveta de notificações
/// expandida (`AndroidNotificationDetails.color`). Ao contrário do ícone,
/// não é um recurso de drawable — é só um inteiro ARGB, então não tem como
/// falhar com "recurso não encontrado"; pode variar por tema com segurança.
/// Falha ao ler a preferência cai no dourado do tema escuro, o padrão do app.
Future<Color> _corDoTema() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final gravado = prefs.getString(Estado.chaveModoDoTema);
    final modo = ModoDoTema.values.firstWhere(
      (m) => m.chave == gravado,
      orElse: () => ModoDoTema.sistema,
    );
    final ehClaro = switch (modo) {
      ModoDoTema.claro => true,
      ModoDoTema.escuro => false,
      ModoDoTema.sistema =>
        PlatformDispatcher.instance.platformBrightness == Brightness.light,
    };
    return ehClaro ? _bronzeDoTemaClaro : _douradoDoTemaEscuro;
  } catch (_) {
    return _douradoDoTemaEscuro;
  }
}

NotificationDetails _detalhesLocais(String icone, Color cor) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        _canalLembretes,
        'Lembretes diários',
        channelDescription: 'Aviso no horário escolhido para o devocional.',
        icon: icone,
        color: cor,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

/// Exibe o push data-only via notificação local e, se a reserva de hoje
/// ainda não disparou, empurra só a ocorrência de hoje daquele slot para
/// amanhã (ver [_pularReservaDeHoje]) — sem isso, o slot avisaria duas
/// vezes nos dias em que o push funciona. Roda nos dois mundos: no handler
/// de fundo (isolate à parte, app morto) e com o app aberto (`onMessage`).
/// Na web quem exibe é o service worker, não aqui.
Future<void> _mostrarPush(Map<String, dynamic> dados) async {
  if (kDebugMode) {
    debugPrint('Lembretes.push recebido: $dados');
  }
  if (!_ehAndroid) return;
  final chave = dados['chave'] as String?;
  final titulo = dados['titulo'] as String?;
  final corpo = dados['corpo'] as String?;
  if (chave == null || titulo == null || corpo == null) return;

  final agora = DateTime.now();
  final alvo = int.tryParse('${dados['minutos']}');
  if (alvo != null &&
      !pushAindaVale(
        minutoAgora: agora.hour * 60 + agora.minute,
        minutoAlvo: alvo,
      )) {
    return;
  }

  final locais = FlutterLocalNotificationsPlugin();
  try {
    await locais.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_iconeLembrete),
      ),
    );
  } catch (erro, pilha) {
    // Ícone de inicialização ausente/corrompido não pode calar a notificação
    // inteira — mesma rede de segurança do `.show()` logo abaixo.
    Registro.erro('Lembretes.push/initialize', erro, pilha);
    await locais.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }
  final cor = await _corDoTema();
  try {
    await locais.show(
      id: _idDaExibida(chave),
      title: titulo,
      body: corpo,
      notificationDetails: _detalhesLocais(_iconeLembrete, cor),
      payload: chave,
    );
  } catch (_) {
    await locais.show(
      id: _idDaExibida(chave),
      title: titulo,
      body: corpo,
      notificationDetails: _detalhesLocais('@mipmap/ic_launcher', cor),
      payload: chave,
    );
  }
  if (alvo != null) unawaited(_pularReservaDeHoje(locais, chave, alvo, cor));
}

/// Reagenda só a ocorrência de hoje da reserva de [chave] para amanhã no
/// mesmo horário — pula o disparo de hoje sem tocar na recorrência dos
/// próximos dias. `zonedSchedule` substitui qualquer agendamento pendente
/// com o mesmo `id` (ver `_armar`), e é o único jeito de "pular hoje" sem
/// mexer em código nativo: o plugin não expõe cancelar só a próxima
/// ocorrência de um alarme recorrente. Falhar aqui (fuso indisponível,
/// plugin não registrado neste isolate) só devolve o comportamento de hoje
/// — a notificação da reserva já agendada continua valendo, no pior caso
/// como duplicata do push que acabou de mostrar; nunca "sem lembrete".
Future<void> _pularReservaDeHoje(
  FlutterLocalNotificationsPlugin locais,
  String chave,
  int alvoMinutos,
  Color cor,
) async {
  final id = _idDoAlarme(chave);
  final titulo = _tituloDoAlarme(chave);
  if (id == null || titulo == null) return;
  try {
    banco_de_fusos.initializeTimeZones();
    final nomeDoFuso = (await FlutterTimezone.getLocalTimezone()).identifier;
    final local = tz.getLocation(nomeDoFuso);
    final amanha = tz.TZDateTime.now(local).add(const Duration(days: 1));
    final quando = tz.TZDateTime(
      local,
      amanha.year,
      amanha.month,
      amanha.day,
      alvoMinutos ~/ 60,
      alvoMinutos % 60 + atrasoDoFallbackMinutos,
    );
    await locais.zonedSchedule(
      id: id,
      title: titulo,
      body: _corpoGenerico,
      scheduledDate: quando,
      notificationDetails: _detalhesLocais(_iconeLembrete, cor),
      payload: chave,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  } catch (erro, pilha) {
    Registro.erro('Lembretes.push/pularReserva', erro, pilha);
  }
}

/// Handler do push com o app morto ou em segundo plano. Precisa ser função
/// de topo com entry-point: o plugin nativo chama direto, sem passar pela
/// árvore do Flutter. O isolate nasce sem plugin nenhum registrado — o
/// registrant dá acesso ao canal das notificações e ao SharedPreferences.
@pragma('vm:entry-point')
Future<void> _lembreteEmSegundoPlano(RemoteMessage mensagem) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await _mostrarPush(mensagem.data);
  } catch (_) {
    // Exibir é melhor-esforço: se o isolate de fundo tropeçar, o alarme de
    // reserva continua armado para cobrir 5 minutos depois. Engolir evita
    // derrubar o serviço nativo do FCM em loop.
  }
}

/// Agenda o lembrete diário no servidor e navega quando a notificação é
/// tocada.
///
/// Uma interface, e não só uma classe: a lógica de horário precisa de teste,
/// e testá-la contra Firebase de verdade exigiria rede e conta configurada
/// que o ambiente de teste não tem. `Lembretes.instancia` é trocável por uma
/// implementação falsa no `setUp` do teste.
abstract class Lembretes {
  static Lembretes instancia = LembretesReais();

  /// Prepara o recebimento do push (e do alarme de reserva) e liga
  /// [aoTocarNotificacao] ao toque na notificação. Chamar uma vez, no início
  /// do app. [aoTocarNotificacao] recebe a chave da leitura — "manha",
  /// "promessas" ou "noite", o mesmo nome de `Leitura.values.byName` em
  /// `lib/telas/devocional.dart`.
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  });

  /// Se o app foi aberto por um toque numa notificação (app fechado), a
  /// chave da leitura tocada. null se o app abriu de outro jeito. Só vale
  /// imediatamente após [inicializar], antes do primeiro quadro.
  Future<String?> chaveQueAbriuOApp();

  /// Pede a permissão de notificação (Android 13+ / navegador). false se
  /// negada ou se a plataforma não suporta lembretes (ver
  /// [lembretesSuportados]).
  Future<bool> pedirPermissao();

  /// Grava no Firestore os horários escolhidos e o token deste aparelho — a
  /// Cloud Function agendada (`functions/src/index.ts`) decide quem avisar —
  /// e arma o lembrete local recorrente de reserva (horário + 5 min, todo
  /// dia, sem precisar reabrir o app). Serve tanto para ligar quanto para
  /// mudar o horário: sempre substitui o registro anterior.
  Future<void> agendar({
    required TimeOfDay manha,
    required TimeOfDay promessas,
    required TimeOfDay leitura,
    required TimeOfDay noite,
  });

  Future<void> cancelar();

  /// Se já existe um registro deste aparelho no Firestore. Diagnóstico e
  /// teste — o armamento dos alarmes acontece em toda [agendar].
  Future<bool> agendados();

  /// O fuso horário detectado neste aparelho (ex.: "America/Sao_Paulo"), o
  /// mesmo que vai para o Firestore em [agendar] e que a Function usa para
  /// calcular a hora local. Só para depurar: vazio depois de [agendar]
  /// significa detecção falhada silenciosamente.
  String get fusoAtual;
}

/// Implementação real do híbrido: push data-only da Function agendada
/// exibido via notificação local (handler de fundo ou app aberto), com um
/// lembrete local recorrente de reserva para T+5 min, todo dia.
///
/// Divisão de papéis: o servidor tenta primeiro, com o conteúdo do dia
/// ("Devocional da Manhã | Gênesis 1:2"); a reserva cobre o pior caso
/// (Function fora do ar, App Check falhando, silêncio além de 5 min) com um
/// aviso genérico — sem conteúdo do dia, porque uma notificação recorrente
/// nativa não é recalculada pelo Dart a cada disparo. Quando o push chega a
/// tempo, [_pularReservaDeHoje] empurra só a ocorrência de hoje da reserva
/// daquele slot para amanhã — sem isso, o slot avisaria duas vezes nos dias
/// em que o push também funciona.
class LembretesReais implements Lembretes {
  static const _colecao = 'lembretes';

  final _mensageria = FirebaseMessaging.instance;
  final _locais = FlutterLocalNotificationsPlugin();

  /// Horários do último [agendar] bem-sucedido, para regravar o documento
  /// com o token novo quando o FCM o troca (`onTokenRefresh`) — sem isto, o
  /// lembrete silenciosamente para de chegar depois de uma renovação.
  TimeOfDay? _ultimaManha;
  TimeOfDay? _ultimaPromessas;
  TimeOfDay? _ultimaLeitura;
  TimeOfDay? _ultimaNoite;
  String _ultimoFuso = '';

  String? _vapidKeyOuNulo() =>
      kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null;

  String? _servicoWebOuNulo() => kIsWeb ? _caminhoDoServiceWorker : null;

  @override
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  }) async {
    if (!lembretesSuportados) return;

    // Push com o app ABERTO: data-only não vira bolha sozinho — exibimos por
    // aqui (Android), com a mesma regra do handler de fundo.
    FirebaseMessaging.onMessage.listen((mensagem) {
      unawaited(_mostrarPush(mensagem.data));
    });

    // Push com o app morto/em fundo (Android): isolate à parte.
    FirebaseMessaging.onBackgroundMessage(_lembreteEmSegundoPlano);

    if (_ehAndroid) {
      void aoReceberResposta(NotificationResponse resposta) {
        final chave = resposta.payload;
        if (chave != null) aoTocarNotificacao(chave);
      }

      try {
        await _locais.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings(_iconeLembrete),
          ),
          onDidReceiveNotificationResponse: aoReceberResposta,
        );
      } catch (erro, pilha) {
        // Ícone de inicialização ausente/corrompido não pode travar o
        // agendamento inteiro — mesma rede de segurança do `.show()`/
        // `.zonedSchedule()` em outros pontos deste arquivo. Sem isto, uma
        // falha aqui aborta antes de criar o canal e antes de
        // `reagendarLembretesSeNecessario` armar a reserva local.
        Registro.erro('Lembretes.inicializar/icone', erro, pilha);
        await _locais.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
          onDidReceiveNotificationResponse: aoReceberResposta,
        );
      }
      await _locais
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _canalLembretes,
              'Lembretes diários',
              description: 'Aviso no horário escolhido para o devocional.',
              importance: Importance.high,
            ),
          );
    }

    _mensageria.onTokenRefresh.listen((tokenNovo) {
      final manha = _ultimaManha;
      final promessas = _ultimaPromessas;
      final leitura = _ultimaLeitura;
      final noite = _ultimaNoite;
      if (manha != null &&
          promessas != null &&
          leitura != null &&
          noite != null) {
        unawaited(_gravar(tokenNovo, manha, promessas, leitura, noite));
      }
    });
  }

  @override
  Future<String?> chaveQueAbriuOApp() async {
    if (!lembretesSuportados) return null;
    if (_ehAndroid) {
      final abertura = await _locais.getNotificationAppLaunchDetails();
      final chave = abertura?.notificationResponse?.payload;
      if (abertura?.didNotificationLaunchApp == true && chave != null) {
        return chave;
      }
    }
    // Caminho legado: mensagens com bolha do sistema em trânsito de uma
    // versão antiga continuam abrindo a leitura certa.
    final mensagem = await _mensageria.getInitialMessage();
    return mensagem?.data['chave'] as String?;
  }

  @override
  Future<bool> pedirPermissao() async {
    if (!lembretesSuportados) return false;
    try {
      final config = await _mensageria.requestPermission();
      return config.authorizationStatus == AuthorizationStatus.authorized ||
          config.authorizationStatus == AuthorizationStatus.provisional;
    } catch (erro, pilha) {
      // Na web, sobretudo em Safari, o navegador pode rejeitar a inscrição
      // no Push API (VAPID, gesto do usuário, iOS fora do modo instalado) e
      // lançar em vez de simplesmente negar — sem isto, o interruptor da
      // folha de ajustes parava sem nenhum aviso.
      Registro.erro('Lembretes.pedirPermissao', erro, pilha);
      return false;
    }
  }

  @override
  Future<void> agendar({
    required TimeOfDay manha,
    required TimeOfDay promessas,
    required TimeOfDay leitura,
    required TimeOfDay noite,
  }) async {
    if (!lembretesSuportados) return;
    _ultimaManha = manha;
    _ultimaPromessas = promessas;
    _ultimaLeitura = leitura;
    _ultimaNoite = noite;

    await _armarReservas(manha, promessas, leitura, noite);

    // _tokenOuNulo() já registra o erro se getToken() lançar (comum na web,
    // sobretudo Safari) — aqui só falta o caso "devolveu nulo sem lançar". A
    // reserva local já foi armada acima; perder só o registro no servidor.
    final token = await _tokenOuNulo();
    if (token == null) {
      Registro.erro(
        'Lembretes.token',
        StateError('getToken veio nulo'),
        StackTrace.current,
      );
      return;
    }
    try {
      await _gravar(token, manha, promessas, leitura, noite);
    } catch (erro, pilha) {
      Registro.erro('Lembretes.gravar', erro, pilha);
    }
  }

  /// Grava o cadastro que a Function consulta. O `.set()` substitui tudo —
  /// inclusive apaga `ultimoEnvio*` da Function, o que é desejado: reagendar
  /// vale um reenvio no mesmo dia.
  Future<void> _gravar(
    String token,
    TimeOfDay manha,
    TimeOfDay promessas,
    TimeOfDay leitura,
    TimeOfDay noite,
  ) async {
    final fuso = await FlutterTimezone.getLocalTimezone();
    _ultimoFuso = fuso.identifier;
    await FirebaseFirestore.instance.collection(_colecao).doc(token).set({
      'token': token,
      'minutosManha': manha.hour * 60 + manha.minute,
      'minutosPromessas': promessas.hour * 60 + promessas.minute,
      'minutosLeitura': leitura.hour * 60 + leitura.minute,
      'minutosNoite': noite.hour * 60 + noite.minute,
      'fuso': _ultimoFuso,
    });
  }

  /// Arma o lembrete local recorrente de reserva nos slots escolhidos, + 5
  /// min, com aviso genérico (sem conteúdo do dia — uma notificação nativa
  /// recorrente não é recalculada pelo Dart a cada disparo).
  ///
  /// Recorrente de propósito, não um tiro por dia: o Android reagenda a
  /// própria ocorrência de amanhã ao disparar a de hoje
  /// (`matchDateTimeComponents`), então o lembrete sobrevive mesmo que o app
  /// não seja reaberto por semanas. Falhas são isoladas por slot — nada
  /// aborta o conjunto nem derruba o app.
  Future<void> _armarReservas(
    TimeOfDay manha,
    TimeOfDay promessas,
    TimeOfDay leitura,
    TimeOfDay noite,
  ) async {
    if (!_ehAndroid) return;
    tz.Location? local;
    tz.TZDateTime? agora;
    try {
      banco_de_fusos.initializeTimeZones();
      final nomeDoFuso = (await FlutterTimezone.getLocalTimezone()).identifier;
      _ultimoFuso = nomeDoFuso;
      local = tz.getLocation(nomeDoFuso);
      agora = tz.TZDateTime.now(local);
    } catch (erro, pilha) {
      Registro.erro('Lembretes.reserva/fuso', erro, pilha);
      return;
    }

    // Limpa TODOS os alarmes pendentes do app antes de armar — inclusive os
    // de versões anteriores (ids/recorrência antigos), que sobrevivem à
    // atualização por cima e virariam fantasma disparando em duplicata.
    // Seguro porque o plugin não é usado para nada além dos lembretes.
    try {
      await _locais.cancelAllPendingNotifications();
    } catch (erro, pilha) {
      Registro.erro('Lembretes.reserva/limpar', erro, pilha);
    }

    tz.TZDateTime as(TimeOfDay hora) => tz.TZDateTime(
      local!,
      agora!.year,
      agora.month,
      agora.day,
      hora.hour,
      hora.minute + atrasoDoFallbackMinutos,
    );

    await _armar(
      id: _idAlarmeManha,
      chave: 'manha',
      titulo: 'Devocional da Manhã',
      quando: as(manha),
    );
    await _armar(
      id: _idAlarmePromessas,
      chave: 'promessas',
      titulo: 'Promessas de Deus',
      quando: as(promessas),
    );
    await _armar(
      id: _idAlarmeLeitura,
      chave: 'leitura',
      titulo: 'Leitura do Dia',
      quando: as(leitura),
    );
    await _armar(
      id: _idAlarmeNoite,
      chave: 'noite',
      titulo: 'Devocional da Noite',
      quando: as(noite),
    );
  }

  Future<void> _armar({
    required int id,
    required String chave,
    required String titulo,
    required tz.TZDateTime quando,
  }) async {
    const corpo = _corpoGenerico;
    try {
      final cor = await _corDoTema();
      try {
        await _locais.zonedSchedule(
          id: id,
          title: titulo,
          body: corpo,
          scheduledDate: quando,
          notificationDetails: _detalhesLocais(_iconeLembrete, cor),
          payload: chave,
          // Sempre inexato, de propósito: é só a reserva, e exato pede a
          // permissão "Alarmes e lembretes" nas Configurações — assustadora
          // e desnecessária para o que é, no fim, apenas uma notificação. O
          // Doze pode atrasar alguns minutos; o push do servidor continua
          // sendo o caminho no horário certo.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          // Recorrência diária nativa: o próprio Android reagenda a
          // ocorrência de amanhã ao disparar a de hoje, sem o app rodar.
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {
        await _locais.zonedSchedule(
          id: id,
          title: titulo,
          body: corpo,
          scheduledDate: quando,
          notificationDetails: _detalhesLocais('@mipmap/ic_launcher', cor),
          payload: chave,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (erro, pilha) {
      // Um alarme recusado pelo sistema não pode abortar os irmãos — cada
      // slot falha sozinho.
      Registro.erro('Lembretes.armar/$chave', erro, pilha);
    }
  }

  @override
  Future<void> cancelar() async {
    if (!lembretesSuportados) return;
    _ultimaManha = null;
    _ultimaPromessas = null;
    _ultimaLeitura = null;
    _ultimaNoite = null;
    if (_ehAndroid) {
      // Mesma limpeza total do armamento: não deixar alarme de nenhuma
      // versão sobreviver a um "desligar lembretes".
      try {
        await _locais.cancelAllPendingNotifications();
      } catch (erro, pilha) {
        Registro.erro('Lembretes.cancelar', erro, pilha);
      }
      for (final id in [3101, 3201, 3401, 3701]) {
        unawaited(_locais.cancel(id: id));
      }
    }
    final token = await _tokenOuNulo();
    if (token == null) return;
    await FirebaseFirestore.instance.collection(_colecao).doc(token).delete();
  }

  @override
  Future<bool> agendados() async {
    if (!lembretesSuportados) return false;
    final token = await _tokenOuNulo();
    if (token == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(token)
        .get();
    return doc.exists;
  }

  /// `getToken()` sem exceção: na web (sobretudo Safari) o navegador pode
  /// lançar em vez de devolver nulo — mesmo motivo do try/catch em
  /// [pedirPermissao] e [agendar]. `null` aqui já é um caso tratado por todo
  /// chamador, então engolir a exceção e devolver `null` reaproveita esse
  /// caminho em vez de duplicar tratamento em cada método.
  Future<String?> _tokenOuNulo() async {
    try {
      return await _mensageria.getToken(
        vapidKey: _vapidKeyOuNulo(),
        serviceWorkerScriptPath: _servicoWebOuNulo(),
      );
    } catch (erro, pilha) {
      Registro.erro('Lembretes.token', erro, pilha);
      return null;
    }
  }

  @override
  String get fusoAtual =>
      _ultimoFuso.isEmpty ? 'ainda não detectado' : _ultimoFuso;
}
