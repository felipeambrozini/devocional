import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

/// Identificação do build para os relatórios que saem do app (erro e
/// denúncia). Sem isto, uma falha ou uma resposta ruim não diz em que versão
/// aconteceu — e o número da versão é justamente o que separa um bug de uma
/// build velha instalada (ver AGENTS.md).
Future<String>? _emAndamento;

/// "1.22.0+47": versão e build do pubspec, como o App Distribution mostra.
/// String vazia se o plugin não responder (teste, plataforma sem suporte).
Future<String> versaoDoApp() => _emAndamento ??= _lerVersao();

Future<String> _lerVersao() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
  } catch (_) {
    return '';
  }
}

/// "web", "web-android", "android": o bastante para saber onde a falha
/// aconteceu. O contrato do servidor e das regras tem teto de 20 caracteres.
String plataformaDoApp() {
  final nome = kIsWeb
      ? 'web-${defaultTargetPlatform.name}'
      : defaultTargetPlatform.name;
  return nome.length <= 20 ? nome : nome.substring(0, 20);
}
