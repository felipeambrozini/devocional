import 'dart:async';

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
import 'modelos.dart' show Devocional, ModoDoTema, Periodo;
import 'registro.dart';

/// Se o aparelho tem como receber o lembrete: **só o aplicativo Android**.
///
/// O lembrete é agendado e disparado pelo próprio aparelho
/// (`flutter_local_notifications`) — sem servidor, sem FCM, sem cron de CI.
/// A web ficou de fora quando o push do servidor foi aposentado: um
/// service worker não dispara nada com a aba fechada sem depender de
/// infraestrutura externa, exatamente o que esta funcionalidade queria
/// evitar. iOS exigiria os pods/permissões da Apple — também de fora.
bool get lembretesSuportados =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const _canalLembretes = 'lembretes_devocional';

// Um id por notificação: 3 slots x 2 dias (hoje e amanhã). O slot da manhã
// arma duas notificações (devocional + promessas), como o push antigo fazia.
const _idManhaHoje = 1001;
const _idManhaAmanha = 1002;
const _idPromessasHoje = 1401;
const _idPromessasAmanha = 1402;
const _idNoiteHoje = 2001;
const _idNoiteAmanha = 2002;

const _todosOsIds = <int>[
  _idManhaHoje,
  _idManhaAmanha,
  _idPromessasHoje,
  _idPromessasAmanha,
  _idNoiteHoje,
  _idNoiteAmanha,
];

/// Texto de reserva quando o conteúdo do dia não carrega (asset ausente,
/// erro de leitura): melhor avisar genérico do que calar.
const _corpoGenerico = 'Está na hora da leitura de hoje. Toque para abrir.';

/// O small icon da notificação conforme o tema escolhido no app: no claro,
/// um glifo escuro; no escuro, um claro. No "Automático" devolve null — e aí
/// quem escolhe é o próprio Android pelos qualifiers `drawable`/
/// `drawable-night` de `ic_lembete`, o único jeito de acertar quando o app
/// está morto e ninguém pode ler a preferência.
///
/// Lê direto do `SharedPreferences`, não do [Estado]: o alarme dispara sem
/// nenhuma instância de estado por perto. Falhar aqui custa só cair no ícone
/// padrão — por isso engolido.
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
    // Nome do drawable; null usa o padrão do initialize, que é o par com
    // qualifier -night.
    icon: icone,
    importance: Importance.high,
    priority: Priority.high,
  ),
);

/// Agenda o lembrete diário no próprio aparelho e navega quando a notificação
/// é tocada.
///
/// Uma interface, e não só uma classe: a lógica de horário precisa de teste,
/// e testá-la contra notificações de verdade exigiria canal de plataforma que
/// o ambiente de teste não tem. `Lembretes.instancia` é trocável por uma
/// implementação falsa no `setUp` do teste.
abstract class Lembretes {
  static Lembretes instancia = LembretesReais();

  /// Prepara o plugin de notificações e liga [aoTocarNotificacao] ao toque na
  /// notificação. Chamar uma vez, no início do app. [aoTocarNotificacao]
  /// recebe a chave da leitura — "manha", "promessas" ou "noite", o mesmo
  /// nome de `Leitura.values.byName` em `lib/telas/devocional.dart`.
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  });

  /// Se o app foi aberto por um toque na notificação (app fechado), a chave
  /// da leitura tocada. null se o app abriu de outro jeito. Só vale
  /// imediatamente após [inicializar], antes do primeiro quadro.
  Future<String?> chaveQueAbriuOApp();

  /// Pede a permissão de notificação (Android 13+). false se negada ou se a
  /// plataforma não suporta lembretes (ver [lembretesSuportados]).
  Future<bool> pedirPermissao();

  /// Arma os alarmes locais nos horários escolhidos, com a referência do dia
  /// no corpo (ex.: "Gênesis 1:2"; Promessas leva "Título | Gênesis 1:2").
  /// Serve tanto para ligar quanto para mudar o horário: sempre substitui os
  /// alarmes anteriores.
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  });

  Future<void> cancelar();

  /// Se algum dos alarmes diários está armado. Diagnóstico e teste.
  Future<bool> agendados();

  /// O fuso horário detectado neste aparelho (ex.: "America/Sao_Paulo"), o
  /// mesmo usado para armar os alarmes em [agendar]. Só para depurar: se
  /// aparecer vazio depois de [agendar], a detecção falhou silenciosamente.
  String get fusoAtual;
}

/// Implementação real: alarmes de um tiro só armados no aparelho para uma
/// janela de dois dias (hoje, se ainda dá, e amanhã), com o conteúdo do dia
/// calculado dos assets ([Conteudo]) — "Devocional da Manhã | Gênesis 1:2",
/// "Devocional da Noite | ...", "Promessas de Deus | Título | ...".
///
/// Por que janela de dois dias e não alarme recorrente: recorrente nasce com
/// o texto congelado, e o corpo com a referência do dia é o ponto da
/// funcionalidade. Quem rearma a janela é a abertura do app
/// (`reagendarLembretesSeNecessario`), a troca de horário e o boot (receiver
/// do plugin resgata os alarmes persistidos). Se o usuário ficar mais de dois
/// dias sem abrir o app, os dias seguintes à janela ficam mudos — aceito:
/// abrir o devocional a cada dois dias é o comportamento esperado de quem
/// pediu um lembrete dele.
class LembretesReais implements Lembretes {
  final _locais = FlutterLocalNotificationsPlugin();

  String _ultimoFuso = '';

  @override
  Future<void> inicializar({
    required void Function(String chaveDaLeitura) aoTocarNotificacao,
  }) async {
    if (!lembretesSuportados) return;

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

  @override
  Future<String?> chaveQueAbriuOApp() async {
    if (!lembretesSuportados) return null;
    final abertura = await _locais.getNotificationAppLaunchDetails();
    if (abertura?.didNotificationLaunchApp != true) return null;
    return abertura?.notificationResponse?.payload;
  }

  @override
  Future<bool> pedirPermissao() async {
    if (!lembretesSuportados) return false;
    // Em versões anteriores ao Android 13 é no-op (null): notificação era
    // concedida por padrão lá atrás, então tratar null como concedido.
    final concedida = await _locais
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return concedida != false;
  }

  @override
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  }) async {
    if (!lembretesSuportados) return;
    try {
      banco_de_fusos.initializeTimeZones();
      final nomeDoFuso = (await FlutterTimezone.getLocalTimezone()).identifier;
      _ultimoFuso = nomeDoFuso;
      final local = tz.getLocation(nomeDoFuso);
      final agora = tz.TZDateTime.now(local);

      // Cancela tudo antes de armar: trocar horário não pode deixar alarme
      // órfão do esquema anterior.
      for (final id in _todosOsIds) {
        unawaited(_locais.cancel(id: id));
      }

      // Janela de dois dias: hoje (só as ocorrências que ainda não passaram)
      // e amanhã inteiro. Cada abertura do app rearma a janela com o
      // conteúdo fresco dos dois dias.
      for (var deslocamento = 0; deslocamento < 2; deslocamento++) {
        final dia = DateTime(agora.year, agora.month, agora.day)
            .add(Duration(days: deslocamento));
        final ehHoje = deslocamento == 0;

        tz.TZDateTime as(TimeOfDay hora) => tz.TZDateTime(
          local,
          dia.year,
          dia.month,
          dia.day,
          hora.hour,
          hora.minute,
        );

        // Manhã: devocional e promessas no mesmo horário, notificações
        // separadas — mesmo contrato de títulos/corpos do push antigo.
        final manha = as(manhaEPromessas);
        if (!ehHoje || manha.isAfter(agora)) {
          await _armar(
            id: _idManhaHoje + deslocamento,
            chave: 'manha',
            titulo: 'Devocional da Manhã',
            corpo: _corpoDe(
              await Conteudo.instancia.devocional(dia, Periodo.manha),
            ),
            quando: manha,
          );
          await _armar(
            id: _idPromessasHoje + deslocamento,
            chave: 'promessas',
            titulo: 'Promessas de Deus',
            corpo: _corpoDaPromessa(await Conteudo.instancia.promessa(dia)),
            quando: manha,
          );
        }

        final noiteDeHoje = as(noite);
        if (!ehHoje || noiteDeHoje.isAfter(agora)) {
          await _armar(
            id: _idNoiteHoje + deslocamento,
            chave: 'noite',
            titulo: 'Devocional da Noite',
            corpo: _corpoDe(
              await Conteudo.instancia.devocional(dia, Periodo.noite),
            ),
            quando: noiteDeHoje,
          );
        }
      }
    } catch (erro, pilha) {
      // Fuso estranho, asset faltando ou alarme bloqueado pelo fabricante
      // não podem derrubar o app nem travar a folha de ajustes — o erro vai
      // para o registro.
      Registro.erro('Lembretes.agendar', erro, pilha);
    }
  }

  /// "Gênesis 1:2" — a referência que o app já mostra em destaque na leitura.
  String _corpoDe(Devocional? devocional) {
    if (devocional == null || devocional.referencia.isEmpty) {
      return _corpoGenerico;
    }
    return devocional.referencia;
  }

  /// "Título | Gênesis 1:2" — o formato que as Promessas já usavam no push.
  String _corpoDaPromessa(Devocional? promessa) {
    if (promessa == null) return _corpoGenerico;
    if (promessa.titulo.isEmpty) return _corpoDe(promessa);
    return '${promessa.titulo} | ${promessa.referencia}';
  }

  Future<void> _armar({
    required int id,
    required String chave,
    required String titulo,
    required String corpo,
    required tz.TZDateTime quando,
  }) async {
    await _locais.zonedSchedule(
      id: id,
      title: titulo,
      body: corpo,
      scheduledDate: quando,
      notificationDetails: _detalhesLocais(await _iconeDoTema()),
      payload: chave,
      androidScheduleMode: await _modoDeAlarme(),
    );
  }

  /// Alarme exato quando o sistema deixa (Android 12+ pede permissão nas
  /// Configurações — declarada no manifesto, concedida fora do app);
  /// inexato caso contrário, que o Doze pode atrasar alguns minutos. Melhor
  /// lembrete imperfeito do que exceção travando o agendamento.
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

  @override
  Future<void> cancelar() async {
    if (!lembretesSuportados) return;
    for (final id in _todosOsIds) {
      unawaited(_locais.cancel(id: id));
    }
  }

  @override
  Future<bool> agendados() async {
    if (!lembretesSuportados) return false;
    final pendentes = await _locais.pendingNotificationRequests();
    return pendentes.any((p) => _todosOsIds.contains(p.id));
  }

  @override
  String get fusoAtual =>
      _ultimoFuso.isEmpty ? 'ainda não detectado' : _ultimoFuso;
}
