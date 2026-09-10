/// No-op fora da web: `dart:js_interop` não existe na VM (Android, testes),
/// então a fachada condicional (`espelho_do_tema.dart`) cai aqui. Não há o
/// que espelhar — o ícone por tema no Android é resolvido por drawables com
/// qualifier `-night` e pela leitura de preferências em `lembretes.dart`.
Future<void> espelharTemaParaNotificacoes({required bool escuro}) async {}
