/// Fachada condicional do espelho do tema para notificações.
///
/// Na web, [espelharTemaParaNotificacoes] grava o tema efetivo no Cache
/// Storage para o service worker escolher o ícone da notificação — ver
/// `espelho_do_tema_web.dart`. Fora da web (VM de teste incluída), é um
/// no-op em `espelho_do_tema_io.dart`: `dart:js_interop` só existe na web,
/// e importá-lo direto quebraria a compilação de todo teste que passa por
/// `main.dart`. Mesma costura de `package:flutter_web_plugins/url_strategy`.
library;

export 'espelho_do_tema_io.dart'
    if (dart.library.js_interop) 'espelho_do_tema_web.dart';
