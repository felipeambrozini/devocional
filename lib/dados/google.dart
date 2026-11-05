import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:package_info_plus/package_info_plus.dart';

/// Chaves de API do Google, uma por plataforma, porque cada uma prova a
/// identidade de um jeito:
///
/// * chaveWeb: criada no Google Cloud Console, restrita ao site do app
///   (`https://www.felipeambrozini.com.br` e `localhost`) e às APIs que o app
///   usa. O navegador manda o cabeçalho Origin, que é a prova que essa
///   restrição confere.
/// * chaveAndroid: criada no Google Cloud Console, restrita ao app Android
///   (`com.felipeambrozini.devocional` + SHA-1 da assinatura) e às APIs que o
///   app usa. O celular prova a identidade com os cabeçalhos
///   X-Android-Package/X-Android-Cert, calculados em tempo de execução (ver
///   [cabecalhosGoogle]) — então debug e release funcionam sem trocar nada,
///   desde que os dois SHA-1 estejam registrados na chave.
/// * chaveIos: criada no Google Cloud Console, restrita ao app iOS
///   (`com.felipeambrozini.devocional` Bundle ID) e às APIs que o app usa.
///
/// Não é segredo de servidor: a Google desenha este caminho para apps
/// client-side, com CORS aberto (conferido em OPTIONS) e limite por projeto.
/// As chaves chegam por `--dart-define` no build (GitHub Secrets no CI).
const chaveGeminiWeb = String.fromEnvironment('GEMINI_API_KEY_WEB');

const chaveGeminiAndroid = String.fromEnvironment('GEMINI_API_KEY_ANDROID');

const chaveGeminiIos = String.fromEnvironment('GEMINI_API_KEY_IOS');

String get chaveGemini {
  if (kIsWeb) return chaveGeminiWeb;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return chaveGeminiIos;
    case TargetPlatform.android:
      return chaveGeminiAndroid;
    default:
      return '';
  }
}

/// Canal do MainActivity.kt que devolve o SHA-1 da assinatura do apk.
const _canalAssinatura = MethodChannel('devocional/assinatura');

/// Os cabeçalhos do pedido a uma API do Google.
///
/// Fora da web, a chave restrita ao app exige a identidade do app em todo
/// pedido, lida em tempo de execução — assim o mesmo código serve para o
/// build de debug e o de release. Se o canal nativo faltar (um isolate de
/// segundo plano não passa pelo MainActivity), o pedido segue sem a prova,
/// que a própria API recusa se precisar.
Future<Map<String, String>> cabecalhosGoogle() async {
  final cabecalhos = <String, String>{'Content-Type': 'application/json'};
  if (!kIsWeb) {
    try {
      cabecalhos.addAll(await _provaDeIdentidade());
    } catch (_) {
      // Sem o canal nativo: segue sem a prova de identidade.
    }
  }
  return cabecalhos;
}

/// O que a restrição de cada chave confere: pacote + SHA-1 da assinatura no
/// Android, Bundle ID no iOS.
Future<Map<String, String>> _provaDeIdentidade() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      final sha1 = await _canalAssinatura.invokeMethod<String>('sha1');
      return {
        'X-Android-Package': await _nomeDoPacote(),
        'X-Android-Cert': ?sha1,
      };
    case TargetPlatform.iOS:
      return {'X-Ios-Bundle-Identifier': await _nomeDoPacote()};
    default:
      return {};
  }
}

Future<String> _nomeDoPacote() async =>
    (await PackageInfo.fromPlatform()).packageName;
