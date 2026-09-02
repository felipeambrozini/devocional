import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

import 'registro.dart';

/// Eventos de uso anônimo — só os que respondem "em que tela alguém travou
/// ou desistiu", não um funil completo. Cada chamada é segura por conta
/// própria: o SDK do Analytics decide sozinho, via
/// `FirebaseAnalytics.setAnalyticsCollectionEnabled` (ver
/// lib/data/coleta.dart), se o evento sai de verdade — o guard abaixo só
/// evita a exceção de chamar antes do Firebase inicializar.
Future<void> _registrar(String nome, [Map<String, Object>? parametros]) async {
  if (Firebase.apps.isEmpty) return;
  try {
    await FirebaseAnalytics.instance.logEvent(name: nome, parameters: parametros);
  } catch (erro, pilha) {
    Registro.erro('Eventos.$nome', erro, pilha);
  }
}

/// Troca de rota — go_router já preenche `route.settings.name` com o
/// caminho completo, sem precisar de `name:` em cada `GoRoute` (ver o
/// observador em `main.dart`).
Future<void> registrarTelaVista(String nomeDaTela) async {
  if (Firebase.apps.isEmpty) return;
  try {
    await FirebaseAnalytics.instance.logScreenView(screenName: nomeDaTela);
  } catch (erro, pilha) {
    Registro.erro('Eventos.telaVista', erro, pilha);
  }
}

/// Um dia virou lido — nunca ao desmarcar, que é a mesma alternância ao
/// contrário e não diz nada sobre progresso.
Future<void> registrarDiaMarcado() => _registrar('dia_marcado');

Future<void> registrarOuvirIniciado() => _registrar('ouvir_iniciado');

Future<void> registrarOuvirFalhou() => _registrar('ouvir_falhou');

Future<void> registrarDownloadIniciado(String categoria) =>
    _registrar('download_iniciado', {'categoria': categoria});

Future<void> registrarDownloadConcluido(String categoria) =>
    _registrar('download_concluido', {'categoria': categoria});

/// Sem o texto da pergunta — só a persona, o suficiente para saber se o chat
/// está sendo usado.
Future<void> registrarChatMensagem(String personaId) =>
    _registrar('chat_mensagem', {'persona': personaId});
