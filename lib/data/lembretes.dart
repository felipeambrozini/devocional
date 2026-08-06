import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as banco_de_fusos;
import 'package:timezone/timezone.dart' as tz;

/// Se o aparelho tem como agendar notificação enquanto o app está fechado.
///
/// Só Android e iOS: são as duas plataformas com um agendador de sistema que o
/// plugin de fato controla. Web e desktop ficam de fora não por falta de
/// tentativa, mas porque não há infraestrutura confiável para o app fechado
/// disparar algo — o mesmo motivo que já tirou a camada monocromática do
/// ícone do Android (ver CONTINUAR.md).
bool get lembretesSuportados =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// As três leituras que têm lembrete, com um id fixo cada para agendar (e
/// cancelar) sempre a mesma notificação em vez de acumular uma nova a cada
/// chamada.
///
/// `chave` é o contrato com quem navega: precisa bater exatamente com
/// `Leitura.name` de `lib/telas/devocional.dart` — é assim que
/// `Leitura.values.byName(chave)` resolve o toque na notificação de volta
/// para a leitura certa. Este arquivo é `lib/data/`, e `data/` não importa
/// `telas/`; por isso a ponte é uma string, não o enum.
enum _Lembrete {
  manha(1, 'manha', 'Devocional da Manhã'),
  promessas(2, 'promessas', 'Promessas de Deus'),
  noite(3, 'noite', 'Devocional da Noite');

  const _Lembrete(this.id, this.chave, this.titulo);

  final int id;
  final String chave;
  final String titulo;
}

/// Agenda os três lembretes diários e navega quando um deles é tocado.
///
/// Uma interface, e não só uma classe: a lógica de horário e de payload
/// precisa de teste, e testá-la contra o plugin de verdade exigiria um canal
/// de plataforma que o ambiente de teste não tem. `Lembretes.instancia` é
/// trocável por uma implementação falsa no `setUp` do teste.
abstract class Lembretes {
  static Lembretes instancia = LembretesReais();

  /// Prepara o plugin e liga [aoTocarNotificacao] ao toque, com o app aberto.
  /// Chamar uma vez, no início do app. [aoTocarNotificacao] recebe a `chave`
  /// de [_Lembrete] — "manha", "promessas" ou "noite".
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  });

  /// Se o app foi aberto por um toque numa notificação, a chave da leitura
  /// tocada. null se o app abriu de outro jeito. Só vale imediatamente após
  /// [inicializar], antes do primeiro quadro.
  Future<String?> chaveQueAbriuOApp();

  /// Pede a permissão de notificação. false se negada ou se a plataforma não
  /// suporta lembretes (ver [lembretesSuportados]).
  Future<bool> pedirPermissao();

  /// Agenda os três lembretes diários, cancelando os anteriores antes. Serve
  /// tanto para ligar quanto para mudar o horário.
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  });

  Future<void> cancelar();

  /// O fuso horário resolvido para agendar (ex.: "America/Sao_Paulo"). Só
  /// para depurar na tela de ajustes: se aparecer "UTC" num aparelho fora
  /// desse fuso, a detecção falhou e caiu no padrão silencioso do pacote
  /// `timezone` (ver Item 1 do CONTINUAR.md, o defeito mais difícil de notar).
  String get fusoAtual;
}

/// Implementação real: `flutter_local_notifications` + `timezone`.
class LembretesReais implements Lembretes {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _fusoPronto = false;

  @override
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  }) async {
    if (!lembretesSuportados) return;

    if (!_fusoPronto) {
      // initializeTimeZones() só carrega o banco de fusos; sem isto o `tz.local`
      // fica em UTC, e 6h escolhida pelo usuário viraria 6h UTC, 3h no Brasil.
      // Se o identificador do aparelho não bater com o banco, fica em UTC em
      // vez de travar o app: um horário errado é recuperável no ajuste; um app
      // que não abre, não.
      banco_de_fusos.initializeTimeZones();
      try {
        final fuso = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(fuso.identifier));
      } catch (_) {
        // Segue em UTC.
      }
      _fusoPronto = true;
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // false nos três: pedir aqui prometeria a notificação antes do
        // usuário tocar o interruptor. pedirPermissao() pede de verdade.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (resposta) {
        final chave = resposta.payload;
        if (chave != null) aoTocarNotificacao(chave);
      },
    );
  }

  @override
  Future<String?> chaveQueAbriuOApp() async {
    if (!lembretesSuportados) return null;
    final detalhe = await _plugin.getNotificationAppLaunchDetails();
    if (detalhe?.didNotificationLaunchApp != true) return null;
    return detalhe?.notificationResponse?.payload;
  }

  @override
  Future<bool> pedirPermissao() async {
    if (!lembretesSuportados) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final concedida = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return concedida ?? false;
    }
    final concedida = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return concedida ?? false;
  }

  @override
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  }) async {
    if (!lembretesSuportados) return;
    await cancelar();
    await _agendarUm(_Lembrete.manha, manhaEPromessas);
    await _agendarUm(_Lembrete.promessas, manhaEPromessas);
    await _agendarUm(_Lembrete.noite, noite);
  }

  Future<void> _agendarUm(_Lembrete lembrete, TimeOfDay hora) async {
    await _plugin.zonedSchedule(
      id: lembrete.id,
      title: lembrete.titulo,
      body: 'Toque para ler agora.',
      scheduledDate: _proximaOcorrencia(hora),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lembretes_diarios',
          'Lembretes diários',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexata: sem SCHEDULE_EXACT_ALARM, sem o usuário precisar conceder
      // acesso especial em Configurações. Uma janela de alguns minutos não
      // importa para "leia seu devocional de manhã". Ver CONTINUAR.md.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: lembrete.chave,
    );
  }

  /// A próxima vez que [hora] ocorre, hoje se ainda não passou, amanhã se já
  /// passou. `zonedSchedule` com `DateTimeComponents.time` repete todo dia a
  /// partir daqui.
  tz.TZDateTime _proximaOcorrencia(TimeOfDay hora) {
    final agora = tz.TZDateTime.now(tz.local);
    var data = tz.TZDateTime(
      tz.local,
      agora.year,
      agora.month,
      agora.day,
      hora.hour,
      hora.minute,
    );
    if (data.isBefore(agora)) data = data.add(const Duration(days: 1));
    return data;
  }

  @override
  Future<void> cancelar() async {
    if (!lembretesSuportados) return;
    for (final lembrete in _Lembrete.values) {
      await _plugin.cancel(id: lembrete.id);
    }
  }

  @override
  String get fusoAtual => _fusoPronto ? tz.local.name : 'ainda não detectado';
}
