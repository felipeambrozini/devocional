import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

/// Espelha o tema efetivo do app para o Cache Storage — o único lugar que o
/// service worker consegue ler com o app fechado (`localStorage` é da janela,
/// invisível para ele; `shared_preferences` vive justamente ali). Quem lê é
/// `web/firebase-messaging-sw.js`, para escolher o ícone da notificação
/// conforme o tema que o usuário escolheu no app.
///
/// Guarda o tema **resolvido** ("claro"/"escuro"), e não o escolhido: no modo
/// "Automático" o que importa para o contraste do ícone é o brilho real em
/// que a interface foi desenhada por último. Se o sistema virar o tema com o
/// app fechado, o espelho fica defasado até a próxima abertura — o ícone
/// erra de lado uma vez, sem quebrar nada.
const _nomeDoCache = 'devocional-preferencias';
const _chaveDoTema = '/devocional/__modo-do-tema';

Future<void> espelharTemaParaNotificacoes({required bool escuro}) async {
  if (!kIsWeb) return;
  try {
    final cache = await web.window.caches.open(_nomeDoCache).toDart;
    await cache
        .put(_chaveDoTema.toJS, web.Response((escuro ? 'escuro' : 'claro').toJS))
        .toDart;
  } catch (_) {
    // Espelho é melhor-esforço: sem ele (navegador sem Cache Storage,
    // modo privado rigoroso), o service worker cai no ícone padrão fixo.
  }
}
