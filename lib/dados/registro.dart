import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';

/// Tamanho máximo do arquivo antes de recomeçar do zero.
///
/// Sem rotação por data nem histórico de arquivos antigos — se um
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
/// conectado no momento da falha.
///
/// Só escreve em arquivo fora da web: não há onde persistir um arquivo lá
/// (mesmo motivo de [lembretesSuportados] em `lembretes.dart`), e o console
/// do navegador já cumpre esse papel. `debugPrint` continua valendo em
/// qualquer plataforma.
abstract final class Registro {
  static File? _arquivo;

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

  /// Registra um evento esperado, sem ser falha: vai só para o console.
  ///
  /// Diferente de [erro] de propósito: uma notificação que chegou, um push
  /// recebido, uma chave consultada são o app funcionando, e mandá-los para o
  /// arquivo encheria de ruído o registro que existe para achar o que quebrou. Sem [inicializar] e sem rede, para poder chamar de
  /// qualquer isolate e em qualquer plataforma.
  static void traco(String origem, String detalhe) {
    debugPrint('[$origem] $detalhe');
  }

  /// Registra uma falha conhecida e esperada em certas condições (device
  /// sem App Attest, simulador, provedor de attestation indisponível): vai
  /// para o console e o arquivo, sem canal remoto.
  static void esperado(String origem, Object erro, [StackTrace? pilha]) {
    final linha = formatarLinha(origem, erro, pilha);
    debugPrint(linha);
    _gravarNoArquivo(linha);
  }

  /// Registra um erro: sempre no console (`debugPrint`) e no arquivo quando
  /// [inicializar] já preparou um. Sem envio remoto: o app não tem coleta
  /// de erro nem de uso (ver PRIVACIDADE, sem Sentry e sem Analytics).
  static void erro(String origem, Object erro, [StackTrace? pilha]) {
    final linha = formatarLinha(origem, erro, pilha);
    debugPrint(linha);
    _gravarNoArquivo(linha);
  }

  static void _gravarNoArquivo(String linha) {
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
