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
import 'conteudo.dart';
import 'modelos.dart' show Devocional, DiaDoPlano, ModoDoTema, Periodo;
import 'registro.dart';

/// Chave pública do Web Push (Console do Firebase > Cloud Messaging > Web
/// configuration > Generate key pair). Não é segredo — é a metade pública do
/// par VAPID — mas segue o padrão `--dart-define` das outras chaves em
/// `lib/data/nuvem.dart`. Vazia faz `getToken` falhar só na web.
const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Se o aparelho/ambiente tem como receber o lembrete: **Android e web**.
///
/// Híbrido: o push vem da Cloud Function agendada
/// (`functions/src/index.ts`, infra do Google — sem os atrasos do cron do
/// GitHub que matou a primeira versão) via FCM data-only, e cada lado exibe
/// por conta própria — aqui no Android, notificação local deste arquivo; na
/// web, o service worker (`web/firebase-messaging-sw.js`). No Android ainda
/// há alarme local de reserva em T+5 min para o caso de a Function falhar.
/// iOS fica de fora: precisaria da chave APNs cadastrada no Console.
bool get lembretesSuportados =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android;

bool get _ehAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const _canalLembretes = 'lembretes_devocional';

/// Minutos entre o horário escolhido e o alarme local de reserva: se às 6h
/// nada chegou do servidor, às 6h05 o próprio aparelho avisa. O mesmo valor
/// é a régua anti-duplicata do outro lado — um push mais de
/// [atrasoDoFallbackMinutos] atrasado já foi coberto pelo alarme e viraria
/// segunda notificação (ver [pushAindaVale]).
const atrasoDoFallbackMinutos = 5;

// Alarmes: 4 slots x 2 dias (janela rearmeda a cada abertura do app).
// Exibidas pelo push: uma por slot. Os ids são base + deslocamento do dia.
const _idAlarmeManhaHoje = 1101;
const _idAlarmeManhaAmanha = 1102;
const _idAlarmePromessasHoje = 1501;
const _idAlarmePromessasAmanha = 1502;
const _idAlarmeLeituraHoje = 1701;
const _idAlarmeLeituraAmanha = 1702;
const _idAlarmeNoiteHoje = 2101;
const _idAlarmeNoiteAmanha = 2102;

int _idDaExibida(String chave) => switch (chave) {
      'noite' => 3201,
      'promessas' => 3401,
      'leitura' => 3701,
      _ => 3101,
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

/// O small icon da notificação conforme o tema escolhido no app: no claro,
/// um glifo escuro; no escuro, um claro. No "Automático" devolve null — e aí
/// quem escolhe é o próprio Android pelos qualifiers `drawable`/
/// `drawable-night` de `ic_lembete`, o único jeito de acertar quando o app
/// está morto e ninguém pode ler a preferência.
///
/// Lê direto do `SharedPreferences`, não do [Estado]: o handler de fundo
/// roda num isolate sem árvore de widgets nem instância de estado. Falhar
/// aqui custa só cair no ícone padrão — por isso engolido.
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
        // Nome do drawable; null usa o padrão do initialize, que é o par
        // com qualifier -night.
        icon: icone,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

/// Exibe o push data-only via notificação local e cancela os alarmes de
/// reserva do slot — o push chegou, eles não servem mais. Roda nos dois
/// mundos: no handler de fundo (isolate à parte, app morto) e com o app
/// aberto (`onMessage`). Na web quem exibe é o service worker, não aqui.
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
  await locais.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_lembete'),
    ),
  );
  await locais.show(
    id: _idDaExibida(chave),
    title: titulo,
    body: corpo,
    notificationDetails: _detalhesLocais(await _iconeDoTema()),
    payload: chave,
  );
  // Cancela os dois dias possíveis do slot: hoje e amanhã da janela.
  final doSlot = switch (chave) {
    'noite' => [_idAlarmeNoiteHoje, _idAlarmeNoiteAmanha],
    'promessas' => [_idAlarmePromessasHoje, _idAlarmePromessasAmanha],
    'leitura' => [_idAlarmeLeituraHoje, _idAlarmeLeituraAmanha],
    _ => [_idAlarmeManhaHoje, _idAlarmeManhaAmanha],
  };
  for (final id in doSlot) {
    unawaited(locais.cancel(id: id));
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
  /// e arma os alarmes locais de reserva (horário + 5 min, janela de dois
  /// dias) com a referência do dia no corpo. Serve tanto para ligar quanto
  /// para mudar o horário: sempre substitui o registro anterior.
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

  /// Mostra uma notificação de teste imediatamente e devolve o diagnóstico do
  /// caminho de exibição: permissão do app, estado do canal, alarme exato e
  /// quantos alarmes de reserva estão armados. Para o botão "Testar" da folha
  /// de ajustes — é o que separa "o aparelho bloqueou" de "o servidor não
  /// mandou" sem depender de adb.
  Future<String> diagnosticar();

  /// O fuso horário detectado neste aparelho (ex.: "America/Sao_Paulo"), o
  /// mesmo que vai para o Firestore em [agendar] e que a Function usa para
  /// calcular a hora local. Só para depurar: vazio depois de [agendar]
  /// significa detecção falhada silenciosamente.
  String get fusoAtual;
}

/// Implementação real do híbrido: push data-only da Function agendada
/// exibido via notificação local (handler de fundo ou app aberto), com
/// alarme de reserva armado no aparelho para T+5 min.
///
/// Divisão de papéis: o servidor garante o horário certo com conteúdo do dia
/// ("Devocional da Manhã | Gênesis 1:2"); o alarme cobre o pior caso
/// (Function fora do ar, App Check falhando, silêncio além de 5 min) com o
/// mesmo formato, calculado dos assets na hora de armar. Quem chega primeiro
/// cancela o outro — sem duplicata nem buraco.
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

  String? _vapidKeyOuNulo() => kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null;

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
      await _locais.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_lembete'),
        ),
        onDidReceiveNotificationResponse: (resposta) {
          final chave = resposta.payload;
          if (chave != null) aoTocarNotificacao(chave);
        },
      );
      await _locais
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
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
      if (manha != null && promessas != null && leitura != null && noite != null) {
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
    final config = await _mensageria.requestPermission();
    return config.authorizationStatus == AuthorizationStatus.authorized ||
        config.authorizationStatus == AuthorizationStatus.provisional;
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

    final token = await _mensageria.getToken(vapidKey: _vapidKeyOuNulo());
    if (token == null) {
      Registro.erro('Lembretes.token', StateError('getToken veio nulo'), StackTrace.current);
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

  /// Arma os alarmes locais de reserva nos slots escolhidos + 5 min, janela
  /// de dois dias (hoje, o que ainda não passou, e amanhã), com o conteúdo
  /// do dia calculado dos assets ([Conteudo]) — o mesmo formato do push.
  ///
  /// Um tiro por ocorrência, de propósito: alarme recorrente não pode ser
  /// cancelado para o dia atual sem matar os próximos, e é justamente o
  /// cancelamento do dia que evita duplicata quando o push chega em cima do
  /// horário. Falhas são isoladas por alarme e por conteúdo — nada aborta o
  /// conjunto nem derruba o app.
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

    for (var deslocamento = 0; deslocamento < 2; deslocamento++) {
      final dia = DateTime(agora.year, agora.month, agora.day)
          .add(Duration(days: deslocamento));
      final ehHoje = deslocamento == 0;

      tz.TZDateTime as(TimeOfDay hora) => tz.TZDateTime(
            local!,
            dia.year,
            dia.month,
            dia.day,
            hora.hour,
            hora.minute + atrasoDoFallbackMinutos,
          );

      final manhaDt = as(manha);
      if (!ehHoje || manhaDt.isAfter(agora)) {
        await _armar(
          id: _idAlarmeManhaHoje + deslocamento,
          chave: 'manha',
          titulo: 'Devocional da Manhã',
          corpo: await _corpoSeguro(
            () => Conteudo.instancia.devocional(dia, Periodo.manha),
            _corpoDe,
          ),
          quando: manhaDt,
        );
      }

      final promessasDt = as(promessas);
      if (!ehHoje || promessasDt.isAfter(agora)) {
        await _armar(
          id: _idAlarmePromessasHoje + deslocamento,
          chave: 'promessas',
          titulo: 'Promessas de Deus',
          corpo: await _corpoSeguro(
            () => Conteudo.instancia.promessa(dia),
            _corpoDaPromessa,
          ),
          quando: promessasDt,
        );
      }

      final leituraDt = as(leitura);
      if (!ehHoje || leituraDt.isAfter(agora)) {
        await _armar(
          id: _idAlarmeLeituraHoje + deslocamento,
          chave: 'leitura',
          titulo: 'Leitura do Dia',
          corpo: await _corpoSeguro(
            () => Conteudo.instancia.diaDoPlano(dia),
            _corpoDaLeitura,
          ),
          quando: leituraDt,
        );
      }

      final noiteDt = as(noite);
      if (!ehHoje || noiteDt.isAfter(agora)) {
        await _armar(
          id: _idAlarmeNoiteHoje + deslocamento,
          chave: 'noite',
          titulo: 'Devocional da Noite',
          corpo: await _corpoSeguro(
            () => Conteudo.instancia.devocional(dia, Periodo.noite),
            _corpoDe,
          ),
          quando: noiteDt,
        );
      }
    }
  }

  /// Carrega o conteúdo do dia isolando a falha: se o asset não abrir, cai
  /// no corpo genérico em vez de abortar o armamento inteiro.
  Future<String> _corpoSeguro<T>(
    Future<T?> Function() carregar,
    String Function(T?) montar,
  ) async {
    try {
      return montar(await carregar());
    } catch (erro, pilha) {
      Registro.erro('Lembretes.conteudo', erro, pilha);
      return _corpoGenerico;
    }
  }

  /// "Gênesis 1:2" — a referência que o app já mostra em destaque na leitura.
  String _corpoDe(Devocional? devocional) {
    if (devocional == null || devocional.referencia.isEmpty) {
      return _corpoGenerico;
    }
    return devocional.referencia;
  }

  /// "Título | Gênesis 1:2" — o formato que as Promessas sempre usaram.
  String _corpoDaPromessa(Devocional? promessa) {
    if (promessa == null) return _corpoGenerico;
    if (promessa.titulo.isEmpty) return _corpoDe(promessa);
    return '${promessa.titulo} | ${promessa.referencia}';
  }

  String _corpoDaLeitura(DiaDoPlano? dia) {
    if (dia == null || dia.rotulo.isEmpty) return _corpoGenerico;
    return dia.rotulo;
  }

  Future<void> _armar({
    required int id,
    required String chave,
    required String titulo,
    required String corpo,
    required tz.TZDateTime quando,
  }) async {
    try {
      await _locais.zonedSchedule(
        id: id,
        title: titulo,
        body: corpo,
        scheduledDate: quando,
        notificationDetails: _detalhesLocais(await _iconeDoTema()),
        payload: chave,
        androidScheduleMode: await _modoDeAlarme(),
      );
    } catch (erro, pilha) {
      // Um alarme recusado pelo sistema não pode abortar os irmãos — cada
      // slot falha sozinho.
      Registro.erro('Lembretes.armar/$chave', erro, pilha);
    }
  }

  /// Alarme exato quando o sistema deixa (Android 12+ pede nas Configurações
  /// — declarada no manifesto, concedida fora do app); inexato caso
  /// contrário, que o Doze pode atrasar alguns minutos. Melhor reserva
  /// imperfeita do que exceção travando o agendamento.
  Future<AndroidScheduleMode> _modoDeAlarme() async {
    final pode = await _locais
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        false;
    return pode
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
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
  Future<String> diagnosticar() async {
    if (!_ehAndroid) return 'Diagnóstico disponível só no Android.';
    final partes = <String>[];
    final androidPlugin = _locais
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final notificacoesOk =
        await androidPlugin?.areNotificationsEnabled() ?? false;
    partes.add(
      notificacoesOk
          ? 'Permissão do app: OK'
          : 'Permissão do app: BLOQUEADA (Configurações > Notificações)',
    );

    try {
      final canais = await androidPlugin?.getNotificationChannels() ?? const [];
      AndroidNotificationChannel? canal;
      for (final c in canais) {
        if (c.id == _canalLembretes) canal = c;
      }
      partes.add(
        canal == null
            ? 'Canal "Lembretes diários": NÃO EXISTE'
            : 'Canal "Lembretes diários": importância ${canal.importance.name}'
                '${canal.importance == Importance.none ? ' — BLOQUEADO, reative em Configurações > Notificações > categoria' : ''}',
      );
    } catch (erro) {
      partes.add('Canal: não deu para ler ($erro)');
    }

    final exato =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    partes.add(
      exato
          ? 'Alarme exato (reserva T+5): OK'
          : 'Alarme exato: indisponível — reserva pode atrasar',
    );

    var pendentes = -1;
    try {
      pendentes = (await _locais.pendingNotificationRequests()).length;
    } catch (_) {}
    partes.add(
      pendentes > 0
          ? 'Alarmes de reserva armados: $pendentes'
          : 'Alarmes de reserva armados: NENHUM (abra o app com lembretes ligados)',
    );

    try {
      await _locais.show(
        id: 9999,
        title: 'Teste do Devocional',
        body: 'Se você está lendo isto, o canal de notificações funciona.',
        notificationDetails: _detalhesLocais(await _iconeDoTema()),
        payload: 'manha',
      );
      partes.add('Notificação de teste: ENVIADA — procure na gaveta.');
    } catch (erro) {
      partes.add('Notificação de teste: FALHOU — $erro');
    }
    return partes.join('\n');
  }

  @override
  String get fusoAtual =>
      _ultimoFuso.isEmpty ? 'ainda não detectado' : _ultimoFuso;
}
