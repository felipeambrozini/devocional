import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'instalacao.dart';

InstalacaoDoApp criarInstalacao() => _InstalacaoWeb();

/// O `BeforeInstallPromptEvent`, que o `package:web` não descreve (só o
/// Chromium tem).
extension type _Convite._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
  external JSPromise<_Escolha> get userChoice;
}

extension type _Escolha._(JSObject _) implements JSObject {
  external String get outcome;
}

/// Lê o que o `index.html` guardou (`convitePraInstalar`, `appInstalado`) e
/// ouve os mesmos eventos para avisar a tela quando o convite chega ou some.
/// Os ouvintes do `index.html` foram registrados antes destes, então quando
/// estes rodam as variáveis globais já estão atualizadas.
class _InstalacaoWeb extends InstalacaoDoApp {
  _InstalacaoWeb() {
    final avisar = ((web.Event _) => notifyListeners()).toJS;
    web.window.addEventListener('beforeinstallprompt', avisar);
    web.window.addEventListener('appinstalled', avisar);
  }

  _Convite? get _convite =>
      web.window.getProperty<_Convite?>('convitePraInstalar'.toJS);

  /// Aberto pelo ícone da tela inicial (Android, Chrome/Edge no computador)
  /// ou, no iPhone, pelo "Adicionar à Tela de Início" (`navigator.standalone`,
  /// só do Safari).
  bool get _abertoComoApp =>
      web.window.matchMedia('(display-mode: standalone)').matches ||
      web.window.matchMedia('(display-mode: fullscreen)').matches ||
      web.window.matchMedia('(display-mode: minimal-ui)').matches ||
      web.window.navigator.getProperty<JSBoolean?>('standalone'.toJS)?.toDart ==
          true;

  /// Instalado nesta mesma aba: a aba continua em modo navegador, mas
  /// oferecer de novo seria estranho.
  bool get _acabouDeInstalar =>
      web.window.getProperty<JSBoolean?>('appInstalado'.toJS)?.toDart == true;

  @override
  bool get disponivel => !_abertoComoApp && !_acabouDeInstalar;

  @override
  bool get temConviteDoNavegador => _convite != null;

  @override
  Future<bool> pedir() async {
    final convite = _convite;
    if (convite == null) return false;
    // O evento só pode abrir a janela uma vez; com ou sem aceite, ele morre
    // aqui e o navegador manda outro se ainda couber.
    web.window.setProperty('convitePraInstalar'.toJS, null);
    // Um erro aqui sobe: quem chamou mostra o caminho pelo menu em vez de
    // deixar o toque sem resposta.
    try {
      await convite.prompt().toDart;
      final escolha = await convite.userChoice.toDart;
      return escolha.outcome == 'accepted';
    } finally {
      notifyListeners();
    }
  }
}
