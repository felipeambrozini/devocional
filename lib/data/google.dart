import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_api_headers/google_api_headers.dart';

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
///   X-Android-Package/X-Android-Cert, calculados em tempo de execução pelo
///   plugin google_api_headers — então debug e release funcionam sem trocar
///   nada, desde que os dois SHA-1 estejam registrados na chave.
/// * chaveIos: criada no Google Cloud Console, restrita ao app iOS
///   (`com.felipeambrozini.devocional` Bundle ID) e às APIs que o app usa.
///
/// São três pares de chave porque o console do Cloud não deixa juntar certas
/// APIs na mesma chave: a restrição da Generative Language API não combina com
/// a da Cloud Text-to-Speech. Então:
///
/// * [chaveGemini] (GEMINI_API_KEY): o chat (`lib/data/ia.dart`).
/// * [chaveTts] (TTS_API_KEY): a voz (`lib/data/voz.dart`), com as mesmas
///   restrições de origem da outra.
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

const chaveTtsWeb = String.fromEnvironment('TTS_API_KEY_WEB');

const chaveTtsAndroid = String.fromEnvironment('TTS_API_KEY_ANDROID');

const chaveTtsIos = String.fromEnvironment('TTS_API_KEY_IOS');

String get chaveTts {
  if (kIsWeb) return chaveTtsWeb;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return chaveTtsIos;
    case TargetPlatform.android:
      return chaveTtsAndroid;
    default:
      return '';
  }
}

/// Os cabeçalhos do pedido a uma API do Google.
///
/// Fora da web, a chave restrita ao app exige a identidade do apk em todo
/// pedido. O plugin google_api_headers lê o nome do pacote e o SHA-1 da
/// assinatura em tempo de execução — assim o mesmo código serve para o build
/// de debug e o de release. Se o plugin faltar num aparelho, o pedido segue
/// sem a prova, que a própria API recusa se precisar.
Future<Map<String, String>> cabecalhosGoogle() async {
  final cabecalhos = <String, String>{'Content-Type': 'application/json'};
  if (!kIsWeb) {
    try {
      cabecalhos.addAll(await GoogleApiHeaders().getHeaders());
    } catch (_) {
      // Plataforma sem o plugin nativo: segue sem a prova de identidade.
    }
  }
  return cabecalhos;
}