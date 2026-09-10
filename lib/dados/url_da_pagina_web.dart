import 'package:web/web.dart' as web;

/// Some com [chave] da URL visível, mantendo o caminho e os outros
/// parâmetros — sem navegar, e sem passar pelo GoRouter.
///
/// Existe porque `main.dart` (`_abrirLeituraDoLembreteDoLink` e afins) lê
/// `?lembrete=`/`?ler=`/`?plano=` e abre a leitura com um
/// `navigatorKey.currentState?.push(...)` direto no Navigator — não um
/// `push`/`go` do GoRouter. Só as chamadas imperativas do próprio GoRouter
/// pedem `routeInformationUpdated` ao motor (é o que
/// `GoRouter.optionURLReflectsImperativeAPIs`, ligada em [AppDevocional],
/// cobre — ver `test/url_no_motor_test.dart`); um push direto no Navigator
/// fica de fora, e a barra de endereço ficaria presa no parâmetro para
/// sempre, mesmo trocando de aba. Chamar isto depois de consumir o
/// parâmetro é o que garante que reabrir a mesma notificação outra vez leve
/// à leitura de novo, em vez de cair num link já velho.
void removerParametroDaUrl(String chave) {
  final uri = Uri.parse(web.window.location.href);
  if (!uri.queryParameters.containsKey(chave)) return;
  final parametros = Map<String, String>.from(uri.queryParameters)
    ..remove(chave);
  final urlLimpa = uri.replace(
    queryParameters: parametros.isEmpty ? null : parametros,
  );
  web.window.history.replaceState(null, '', urlLimpa.toString());
}
