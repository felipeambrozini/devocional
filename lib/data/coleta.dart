import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

import 'registro.dart';

/// Aplica a resposta do usuário (ver `Estado.aceiteDeColeta` e
/// `TelaDeAceiteDeColeta`) aos dois canais de coleta remota: Sentry, para
/// erro (via [Registro.envioRemotoPermitido]), e Analytics, para uso
/// anônimo. Chamado na abertura do app com a resposta já salva, e de novo
/// sempre que o usuário responde ao diálogo — nunca antes disso, os dois
/// ficam desligados por padrão.
///
/// Não vive em `estado.dart` de propósito: `Estado` não importa Firebase, e
/// este arquivo é o único ponto que liga os dois SDKs à escolha do usuário.
Future<void> aplicarAceiteDeColeta(bool? aceito) async {
  final permitido = aceito ?? false;
  Registro.envioRemotoPermitido = permitido;
  if (Firebase.apps.isEmpty) return;
  try {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(permitido);
  } catch (erro, pilha) {
    Registro.erro('aplicarAceiteDeColeta', erro, pilha);
  }
}
