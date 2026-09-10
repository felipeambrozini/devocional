import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Tamanho máximo do arquivo antes de recomeçar do zero.
///
/// ponytail: sem rotação por data nem histórico de arquivos antigos — se um
/// dia isto virar pouco, trocar por `registro.log` + `registro.log.1`.
const _tamanhoMaximo = 512 * 1024;

/// A linha gravada para um erro, no formato do arquivo — separado da escrita
/// em si para dar para testar o formato sem tocar em disco.
String formatarLinha(String origem, Object erro, StackTrace? pilha) {
  final buffer = StringBuffer('[${DateTime.now().toIso8601String()}] $origem: $erro');
  if (pilha != null) buffer.write('\n$pilha');
  buffer.writeln();
  return buffer.toString();
}

/// Grava erros num arquivo no aparelho, para investigar depois de o app já
/// ter fechado — o que só `debugPrint` não permite fora do Android Studio
/// conectado no momento da falha — e manda ao Sentry, para chegar sem
/// depender de alguém relatar.
///
/// Só escreve em arquivo fora da web: não há onde persistir um arquivo lá
/// (mesmo motivo de [lembretesSuportados] em `lembretes.dart`), e o console
/// do navegador já cumpre esse papel. `debugPrint` continua valendo em
/// qualquer plataforma. O Sentry funciona nas duas (web e Android), mas só
/// depois do aceite do usuário — ver [envioRemotoPermitido] e o `beforeSend`
/// montado em `main.dart`.
abstract final class Registro {
  static File? _arquivo;

  /// Portão do envio ao Sentry. `false` por padrão: sem aceite explícito
  /// (ver `Estado.aceiteDeColeta` e `TelaDeAceiteDeColeta`), nenhum evento
  /// sai, mesmo com o SDK já inicializado — o SDK precisa estar de pé antes
  /// da resposta do usuário chegar, então o filtro fica aqui e no
  /// `beforeSend`, não na inicialização.
  static bool envioRemotoPermitido = false;

  /// Prepara o arquivo de registro. Chamar uma vez, no início do app.
  static Future<void> inicializar() async {
    if (kIsWeb) return;
    try {
      final diretorio = await getApplicationSupportDirectory();
      _arquivo = File('${diretorio.path}/registro.log');
    } catch (_) {
      // Sem diretório (plataforma sem o plugin, ambiente de teste): o app
      // segue sem o arquivo — debugPrint ainda funciona.
    }
  }

  /// Registra um erro: sempre no console (`debugPrint`) e no arquivo quando
  /// [inicializar] já preparou um; manda ao Sentry quando [envioRemotoPermitido].
  static void erro(String origem, Object erro, [StackTrace? pilha]) {
    final linha = formatarLinha(origem, erro, pilha);
    debugPrint(linha);
    if (envioRemotoPermitido) {
      // Sem await: registrar um erro não pode esperar rede. O próprio SDK
      // enfileira e tenta de novo por conta própria.
      unawaited(
        Sentry.captureException(
          erro,
          stackTrace: pilha,
          hint: Hint.withMap({'origem': origem}),
        ),
      );
    }
    final arquivo = _arquivo;
    if (arquivo == null) return;
    try {
      if (arquivo.existsSync() && arquivo.lengthSync() > _tamanhoMaximo) {
        arquivo.deleteSync();
      }
      arquivo.writeAsStringSync(linha, mode: FileMode.append, flush: false);
    } catch (_) {
      // Falha ao escrever (disco cheio, sem permissão): não há um segundo
      // lugar para registrar a falha de registrar.
    }
  }
}
