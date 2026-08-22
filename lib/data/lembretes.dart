import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as banco_de_fusos;
import 'package:timezone/timezone.dart' as tz;

import 'estado.dart';
import 'modelos.dart' show ModoDoTema;
import 'registro.dart';

/// Chave pública do Web Push (Console do Firebase > Cloud Messaging > Web
/// configuration > Generate key pair). Não é segredo — é a chave pública do
/// par VAPID — mas segue o mesmo padrão de `--dart-define` das outras chaves
/// em `lib/data/nuvem.dart`. Vazia (não configurada) faz `getToken` falhar só
/// na web; Android não depende dela.
const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Se o aparelho tem como receber o lembrete.
///
/// Android e web: os dois recebem por push data-only
/// (`tool/enviar_lembretes.dart` decide o horário e manda via FCM — ver
/// README.md); quem exibe é cada plataforma por conta própria — aqui no
/// Android é a notificação local deste arquivo, na web é o service worker
/// (`web/firebase-messaging-sw.js`). iOS fica de fora por ora: precisaria da
/// chave APNs cadastrada no Console, que não foi configurada.
bool get lembretesSuportados =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android;

bool get _ehAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Minutos entre o horário escolhido e o alarme local de reserva: se às 6h
/// nada chegou, às 6h05 o próprio aparelho avisa. O mesmo valor serve de
/// régua do outro lado — um push que chega mais de [atrasoDoFallbackMinutos]
/// depois do horário já foi coberto pelo alarme e vira duplicata (ver
/// [pushAindaVale]).
const atrasoDoFallbackMinutos = 5;

// Dois ids por slot: um para o alarme pendente (`zonedSchedule`) e outro para
// a notificação exibida na hora (`show`). Não podem ser iguais — `cancel`
// derruba tanto a pendente quanto a que está na gaveta, então cancelar o
// alarme com o id da notificação recém-exibida apagaria ela mesma.
const _idAlarmeManha = 1001;
const _idAlarmeNoite = 2002;
const _idExibidaManha = 3001;
const _idExibidaNoite = 4002;

const _canalLembretes = 'lembretes_devocional';

int _idDoAlarme(String chave) =>
    chave == 'noite' ? _idAlarmeNoite : _idAlarmeManha;

int _idDaExibida(String chave) =>
    chave == 'noite' ? _idExibidaNoite : _idExibidaManha;

/// Minutos de atraso de [agoraMinuto] sobre [alvoMinuto], considerando a
/// virada da meia-noite (alvo 23:55, agora 00:03 → 8). Réplica da função de
/// mesmo papel em `tool/enviar_lembretes.dart` — este arquivo importa
/// Flutter, e o script roda em Dart puro, então não há como partilhar.
int _atrasoEmMinutos(int agoraMinuto, int alvoMinuto) {
  final diferenca = (agoraMinuto - alvoMinuto) % 1440;
  return diferenca < 0 ? diferenca + 1440 : diferenca;
}

/// Se um push que chegou agora ainda deve virar notificação. Depois de
/// [atrasoDoFallbackMinutos] do horário cadastrado, o alarme de reserva já
/// avisou o usuário — exibir o push tardio seria segunda notificação para a
/// mesma leitura. Público para o teste poder cobrir a regra sem Firebase.
bool pushAindaVale({required int minutoAgora, required int minutoAlvo}) =>
    _atrasoEmMinutos(minutoAgora, minutoAlvo) <= atrasoDoFallbackMinutos;

/// O small icon da notificação conforme o tema escolhido no app: no claro,
/// um glifo escuro; no escuro, um claro. No "Automático" devolve null — e aí
/// quem escolhe é o próprio Android pelos qualifiers `drawable`/
/// `drawable-night` de `ic_lembete`, o único jeito de acertar quando o app
/// está morto e ninguém pode ler a preferência.
///
/// Lê direto do `SharedPreferences`, não do [Estado]: o handler de fundo
/// roda num isolate sem árvore de widgets nem instância de estado. Falhar
/// aqui (prefs indisponível num isolate recém-nascido) custa só cair no
/// ícone padrão — por isso engolido.
Future<String?> _iconeDoTema() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final gravado = prefs.getString(Estado.chaveModoDoTema);
    final modo = ModoDoTema.values.firstWhere(
      (m) => m.chave == gravado,
      orElse: () => ModoDoTema.sistema,
    );
    return switch (modo) {
      ModoDoTema.claro => 'ic_lembete_claro',
      ModoDoTema.escuro => 'ic_lembete_escuro',
      ModoDoTema.sistema => null,
    };
  } catch (_) {
    return null;
  }
}

NotificationDetails _detalhesLocais(String? icone) => NotificationDetails(
  android: AndroidNotificationDetails(
    _canalLembretes,
    'Lembretes diários',
    channelDescription: 'Aviso no horário escolhido para o devocional.',
    // Nome do drawable (v22 trocou o tipo para String); null usa o padrão
    // do initialize, que é o par com qualifier -night.
    icon: icone,
    importance: Importance.high,
    priority: Priority.high,
  ),
);

/// Exibe o push data-only via notificação local, com a regra de duplicata de
/// [pushAindaVale], e cancela o alarme de reserva do slot — o push chegou,
/// ele não serve mais. Roda nos dois mundos: no handler de fundo (isolate à
/// parte, app morto) e com o app aberto (`onMessage`, caso que antes ficava
/// sem notificação nenhuma).
Future<void> _mostrarPush(Map<String, dynamic> dados) async {
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
  await _prepararPlugin(locais);
  await locais.show(
    id: _idDaExibida(chave),
    title: titulo,
    body: corpo,
    notificationDetails: _detalhesLocais(await _iconeDoTema()),
    payload: chave,
  );
  await locais.cancel(id: _idDoAlarme(chave));
}

/// Idempotente: cada isolate precisa inicializar o plugin uma vez antes de
/// usar (o handler de fundo roda num isolate onde o `inicializar` do app não
/// rodou). O ícone padrão é o par com qualifier `-night`, para o modo
/// automático e como rede de segurança se `_iconeDoTema` falhar.
Future<void> _prepararPlugin(FlutterLocalNotificationsPlugin locais) async {
  await locais.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_lembrete'),
    ),
  );
}

/// Handler do push com o app morto ou em segundo plano. Precisa ser função de
/// topo com entry-point: o plugin nativo chama direto, sem passar pela árvore
/// do Flutter. O isolate nasce sem plugin nenhum registrado — o registrant é
/// quem dá acesso ao canal das notificações e ao SharedPreferences (ícone).
@pragma('vm:entry-point')
Future<void> _lembreteEmSegundoPlano(RemoteMessage mensagem) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await _mostrarPush(mensagem.data);
  } catch (_) {
    // Exibir o lembrete é melhor-esforço: se o isolate de fundo tropeçar, o
    // alarme de reserva continua armado para cobrir 5 minutos depois.
    // Engolir evita derrubar o serviço nativo do FCM em loop.
  }
}

/// Agenda o lembrete diário no servidor e navega quando a notificação é tocada.
///
/// Uma interface, e não só uma classe: a lógica de horário e de payload
/// precisa de teste, e testá-la contra o Firebase de verdade exigiria rede e
/// conta configurada que o ambiente de teste não tem. `Lembretes.instancia` é
/// trocável por uma implementação falsa no `setUp` do teste.
abstract class Lembretes {
  static Lembretes instancia = LembretesReais();

  /// Prepara o recebimento do push e liga [aoTocarNotificacao] ao toque, com
  /// o app aberto (em segundo plano) ou reaberto por ele. Chamar uma vez, no
  /// início do app. [aoTocarNotificacao] recebe a chave da leitura — "manha",
  /// "promessas" ou "noite", o mesmo nome de `Leitura.values.byName` em
  /// `lib/telas/devocional.dart`.
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  });

  /// Se o app foi aberto por um toque numa notificação (app fechado), a chave
  /// da leitura tocada. null se o app abriu de outro jeito. Só vale
  /// imediatamente após [inicializar], antes do primeiro quadro.
  ///
  /// Cobre os dois caminhos: o toque numa notificação local (fallback ou push
  /// exibido por este arquivo) volta pelo plugin local; o de uma mensagem do
  /// FCM antiga em trânsito, pelo SDK nativo. Na web o toque chega como
  /// parâmetro de URL (`?lembrete=`), tratado em `lib/main.dart`.
  Future<String?> chaveQueAbriuOApp();

  /// Pede a permissão de notificação. false se negada ou se a plataforma não
  /// suporta lembretes (ver [lembretesSuportados]).
  Future<bool> pedirPermissao();

  /// Grava no Firestore os horários escolhidos e o token deste aparelho, para
  /// `tool/enviar_lembretes.dart` decidir quem avisar a cada rodada, e arma
  /// os alarmes locais de reserva (horário + 5 min). Serve tanto para ligar
  /// quanto para mudar o horário ou rearmar no início do app — sempre
  /// substitui o registro anterior deste aparelho.
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  });

  Future<void> cancelar();

  /// Se já existe um registro deste aparelho no Firestore. Serve só para
  /// diagnóstico (`test/lembretes_test.dart` usa a versão falsa para outros
  /// fins) — o rearmamento dos alarmes locais acontece em todo
  /// `reagendarLembretesSeNecessario`, independente desta resposta.
  Future<bool> agendados();

  /// O fuso horário detectado neste aparelho (ex.: "America/Sao_Paulo"), o
  /// mesmo que vai para o Firestore em [agendar]. Só para depurar: se
  /// aparecer vazio depois de [agendar], a detecção falhou silenciosamente.
  String get fusoAtual;
}

/// Implementação real: push data-only do servidor exibido via notificação
/// local, com alarme de reserva armado no próprio aparelho.
///
/// Por que híbrido: o disparo vem de um cron do GitHub Actions
/// (`lembretes-push.yml`), que atrasa e sai da grade — o servidor agora
/// tolera até 60 min de atraso e garante um envio por dia (marcadores
/// `ultimoEnvio*` no documento). O alarme local cobre o resto: workflow fora
/// do ar, App Check falhando, qualquer silêncio além de 5 min. Mensagem
/// data-only (sem payload `notification`) é o que faz o handler rodar com o
/// app morto — e é também o que permite cancelar o alarme de reserva quando
/// o push chega, coisa impossível com a bolha do sistema.
class LembretesReais implements Lembretes {
  static const _colecao = 'lembretes';

  final _mensageria = FirebaseMessaging.instance;
  final _locais = FlutterLocalNotificationsPlugin();

  /// Horários do último [agendar] bem-sucedido, para regravar com o token
  /// novo quando o FCM o troca (`onTokenRefresh`) — sem isto, o lembrete
  /// silenciosamente para de chegar depois de uma renovação de token.
  TimeOfDay? _ultimaManha;
  TimeOfDay? _ultimaNoite;
  String _ultimoFuso = '';

  String? _vapidKeyOuNulo() => kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null;

  @override
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  }) async {
    if (!lembretesSuportados) return;

    FirebaseMessaging.onMessageOpenedApp.listen((mensagem) {
      final chave = mensagem.data['chave'];
      if (chave != null) aoTocarNotificacao(chave);
    });

    // Push com o app ABERTO: data-only não vira bolha sozinho — exibimos por
    // aqui, com a mesma regra do handler de fundo. É o caso antigo em que o
    // lembrete simplesmente não aparecia.
    FirebaseMessaging.onMessage.listen((mensagem) {
      unawaited(_mostrarPush(mensagem.data));
    });

    // Push com o app morto/em fundo: [_lembreteEmSegundoPlano] num isolate à
    // parte. Registro único por execução — por isso dentro de [inicializar],
    // que main.dart chama uma vez antes do primeiro quadro.
    FirebaseMessaging.onBackgroundMessage(_lembreteEmSegundoPlano);

    // Toque numa notificação local (reserva ou push exibido por nós), com o
    // app vivo. O toque com o app morto volta por [chaveQueAbriuOApp].
    await _locais.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_lembrete'),
      ),
      onDidReceiveNotificationResponse: (resposta) {
        final chave = resposta.payload;
        if (chave != null) aoTocarNotificacao(chave);
      },
    );
    final android = _locais
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _canalLembretes,
        'Lembretes diários',
        description: 'Aviso no horário escolhido para o devocional.',
        importance: Importance.high,
      ),
    );

    _mensageria.onTokenRefresh.listen((tokenNovo) {
      final manha = _ultimaManha;
      final noite = _ultimaNoite;
      if (manha != null && noite != null) {
        unawaited(_gravar(tokenNovo, manha, noite));
      }
    });
  }

  @override
  Future<String?> chaveQueAbriuOApp() async {
    if (!lembretesSuportados) return null;
    if (!kIsWeb) {
      final abertura = await _locais.getNotificationAppLaunchDetails();
      final chave = abertura?.notificationResponse?.payload;
      if (abertura?.didNotificationLaunchApp == true && chave != null) {
        return chave;
      }
    }
    // Caminho legado: mensagens com bolha do sistema (enviadas por uma
    // versão antiga do script ainda em trânsito) continuam abrindo a leitura.
    final mensagem = await _mensageria.getInitialMessage();
    return mensagem?.data['chave'] as String?;
  }

  @override
  Future<bool> pedirPermissao() async {
    if (!lembretesSuportados) return false;
    final config = await _mensageria.requestPermission();
    return config.authorizationStatus == AuthorizationStatus.authorized ||
        config.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  }) async {
    if (!lembretesSuportados) return;
    _ultimaManha = manhaEPromessas;
    _ultimaNoite = noite;
    await _armarReservas(manhaEPromessas, noite);
    final token = await _mensageria.getToken(vapidKey: _vapidKeyOuNulo());
    if (token == null) return;
    await _gravar(token, manhaEPromessas, noite);
  }

  /// Arma os dois alarmes locais de reserva (horário escolhido +
  /// [atrasoDoFallbackMinutos]) para a próxima ocorrência. Um tiro só, de
  /// propósito: alarme recorrente não pode ser cancelado para o dia atual
  /// sem matar os próximos também, e é justamente o cancelamento do dia que
  /// evita duplicata quando o push chega em cima do horário. Quem rearma:
  /// todo início do app ([reagendarLembretesSeNecessario]), troca de horário
  /// e renovação de token — todos passam por [agendar]. Se o usuário não
  /// abrir o app por dias e o servidor ficar mudo nesse período, a reserva
  /// cobre só o primeiro dia; documentado no README.
  Future<void> _armarReservas(TimeOfDay manha, TimeOfDay noite) async {
    if (!_ehAndroid) return;
    try {
      banco_de_fusos.initializeTimeZones();
      final nomeDoFuso = (await FlutterTimezone.getLocalTimezone()).identifier;
      final local = tz.getLocation(nomeDoFuso);
      final agora = tz.TZDateTime.now(local);
      await _armarUma(_idAlarmeManha, 'manha', manha, agora, local);
      await _armarUma(_idAlarmeNoite, 'noite', noite, agora, local);
    } catch (erro, pilha) {
      // A reserva é rede de segurança, não caminho principal: falhar aqui
      // (fuso estranho, alarme bloqueado pelo fabricante) não pode impedir o
      // cadastro do push nem derrubar o app.
      Registro.erro('Lembretes.reserva', erro, pilha);
    }
  }

  Future<void> _armarUma(
    int id,
    String chave,
    TimeOfDay hora,
    tz.TZDateTime agora,
    tz.Location local,
  ) async {
    var quando = tz.TZDateTime(
      local,
      agora.year,
      agora.month,
      agora.day,
      hora.hour,
      hora.minute + atrasoDoFallbackMinutos,
    );
    if (!quando.isAfter(agora)) quando = quando.add(const Duration(days: 1));
    await _locais.zonedSchedule(
      id: id,
      title: 'Devocional',
      body: 'Está na hora da leitura de hoje. Toque para abrir.',
      scheduledDate: quando,
      notificationDetails: _detalhesLocais(await _iconeDoTema()),
      payload: chave,
      androidScheduleMode: await _modoDeAlarme(),
    );
  }

  /// Alarme exato quando o sistema deixa (Android 12+ pede permissão nas
  /// Configurações — declarada no manifesto, concedida fora do app);
  /// inexato caso contrário, que o Doze pode atrasar alguns minutos. Melhor
  /// reserva imperfeita do que exceção travando o agendamento.
  Future<AndroidScheduleMode> _modoDeAlarme() async {
    final pode = await _locais
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
    return pode
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _gravar(String token, TimeOfDay manha, TimeOfDay noite) async {
    final fuso = await FlutterTimezone.getLocalTimezone();
    _ultimoFuso = fuso.identifier;
    await FirebaseFirestore.instance.collection(_colecao).doc(token).set({
      'token': token,
      'minutosManha': manha.hour * 60 + manha.minute,
      'minutosNoite': noite.hour * 60 + noite.minute,
      'fuso': _ultimoFuso,
    });
  }

  @override
  Future<void> cancelar() async {
    if (!lembretesSuportados) return;
    _ultimaManha = null;
    _ultimaNoite = null;
    if (_ehAndroid) {
      for (final id in [
        _idAlarmeManha,
        _idAlarmeNoite,
        _idExibidaManha,
        _idExibidaNoite,
      ]) {
        unawaited(_locais.cancel(id: id));
      }
    }
    final token = await _mensageria.getToken(vapidKey: _vapidKeyOuNulo());
    if (token == null) return;
    await FirebaseFirestore.instance.collection(_colecao).doc(token).delete();
  }

  @override
  Future<bool> agendados() async {
    if (!lembretesSuportados) return false;
    final token = await _mensageria.getToken(vapidKey: _vapidKeyOuNulo());
    if (token == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(token)
        .get();
    return doc.exists;
  }

  @override
  String get fusoAtual => _ultimoFuso.isEmpty ? 'ainda não detectado' : _ultimoFuso;
}
