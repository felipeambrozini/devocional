import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Chave pública do Web Push (Console do Firebase > Cloud Messaging > Web
/// configuration > Generate key pair). Não é segredo — é a chave pública do
/// par VAPID — mas segue o mesmo padrão de `--dart-define` das outras chaves
/// em `lib/data/nuvem.dart`. Vazia (não configurada) faz `getToken` falhar só
/// na web; Android não depende dela.
const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Se o aparelho tem como receber o lembrete.
///
/// Android e web: os dois recebem o mesmo jeito, por push
/// (`tool/enviar_lembretes.dart` decide o horário e manda via FCM — ver
/// README.md). iOS fica de fora por ora: precisaria da chave APNs cadastrada
/// no Console, que não foi configurada.
bool get lembretesSuportados =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android;

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
  /// Só cobre Android: o toque na notificação da web chega como parâmetro de
  /// URL (`?lembrete=`), tratado em `lib/main.dart`, não por aqui — a web não
  /// passa pelo SDK nativo do FCM para abrir a aba.
  Future<String?> chaveQueAbriuOApp();

  /// Pede a permissão de notificação. false se negada ou se a plataforma não
  /// suporta lembretes (ver [lembretesSuportados]).
  Future<bool> pedirPermissao();

  /// Grava no Firestore os horários escolhidos e o token deste aparelho, para
  /// `tool/enviar_lembretes.dart` decidir quem avisar a cada rodada. Serve
  /// tanto para ligar quanto para mudar o horário — sempre substitui o
  /// registro anterior deste aparelho.
  Future<void> agendar({
    required TimeOfDay manhaEPromessas,
    required TimeOfDay noite,
  });

  Future<void> cancelar();

  /// Se já existe um registro deste aparelho no Firestore. Serve só para
  /// `reagendarLembretesSeNecessario` (`lib/telas/comuns.dart`) saber se
  /// precisa regravar no início do app — por exemplo depois de o app ter sido
  /// desinstalado e reinstalado, quando o token trocou e o registro antigo já
  /// não corresponde a este aparelho.
  Future<bool> agendados();

  /// O fuso horário detectado neste aparelho (ex.: "America/Sao_Paulo"), o
  /// mesmo que vai para o Firestore em [agendar]. Só para depurar: se
  /// aparecer vazio depois de [agendar], a detecção falhou silenciosamente.
  String get fusoAtual;
}

/// Implementação real: `firebase_messaging` grava o token no Firestore;
/// quem decide o horário e manda o push é `tool/enviar_lembretes.dart`, fora
/// do app.
///
/// ponytail: sem exibição manual em primeiro plano. O FCM mostra a
/// notificação do sistema sozinho quando o app está em segundo plano ou
/// fechado — o caso comum para um lembrete de 6h ou 21h — mas não em
/// primeiro plano (nem no Android nem na web); ali a mensagem chega a
/// `onMessage`/`onBackgroundMessage` sem virar notificação visível. Resolver
/// isso exigiria voltar a ter um plugin de notificação local só para exibir,
/// o que a unificação com a web queria evitar. Upgrade se o app ficar aberto
/// bem no horário do lembrete com frequência.
class LembretesReais implements Lembretes {
  static const _colecao = 'lembretes';

  final _mensageria = FirebaseMessaging.instance;

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
    final token = await _mensageria.getToken(vapidKey: _vapidKeyOuNulo());
    if (token == null) return;
    await _gravar(token, manhaEPromessas, noite);
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
