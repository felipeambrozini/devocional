import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;

import 'versao.dart';

/// Relatórios de erro da web.
///
/// O app não tem Sentry nem Analytics de propósito (ver PRIVACIDADE). O que
/// existe é só isto: em build de release na web, cada erro que já ia para o
/// console vira um POST para a Function `registrarErro` (ver
/// functions/src/erro.ts), que guarda mensagem, pilha, o caminho da página e a
/// versão. Nunca vai o texto digitado, a conversa, o e-mail, o uid nem a URL
/// com query string — o servidor também corta qualquer coisa fora do contrato.
///
/// Limites do lado do cliente: no máximo 5 relatórios por sessão e um por
/// mensagem distinta, para um laço de erro não virar enxurrada de rede. Do
/// lado do servidor há limite por cliente e por instância.
abstract final class Monitoramento {
  static const _endpoint = '/devocional/api/erro';
  static const _maximoPorSessao = 5;

  static int _enviados = 0;
  static final Set<String> _vistos = {};

  /// Chamado por `Registro.erro`; fire-and-forget de propósito. Não roda em
  /// debug (poluiria a coleção com falhas de desenvolvimento) nem fora da web
  /// (o público é o site; o APK é só de testadores).
  static void registrar(String origem, Object erro, [StackTrace? pilha]) {
    if (!kIsWeb || !kReleaseMode) return;
    if (_enviados >= _maximoPorSessao) return;
    final mensagem = _limitar(erro.toString(), 1000);
    if (mensagem.isEmpty) return;
    final chave = '$origem|$mensagem';
    if (!_vistos.add(chave)) return;
    _enviados++;
    unawaited(_enviar(origem, mensagem, pilha));
  }

  static Future<void> _enviar(
    String contexto,
    String mensagem,
    StackTrace? pilha,
  ) async {
    try {
      final versao = await versaoDoApp();
      final resposta = await http
          .post(
            Uri.base.resolve(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            // jsonEncode, não o Map direto: o package:http manda Map como
            // formulário (ou estoura no cast), e a Function só lê JSON.
            body: jsonEncode(
              jsonDoRelatorio(
                contexto: contexto,
                mensagem: mensagem,
                pilha: _limitar(pilha?.toString() ?? '', 8000),
                url: Uri.base.path,
                versao: versao,
                plataforma: plataformaDoApp(),
              ),
            ),
          )
          .timeout(const Duration(seconds: 5));
      // 4xx/5xx não têm o que fazer: o relatório é acessório ao app.
      if (resposta.statusCode >= 500) {
        // Um único debugPrint, sem chamar Registro.erro de novo (laço).
        debugPrintRelatorio('servidor respondeu ${resposta.statusCode}');
      }
    } catch (erro) {
      // Sem rede, endpoint fora do ar, CORS: o app segue, como sempre seguiu
      // sem coleta remota.
      debugPrintRelatorio('falha ao enviar: $erro');
    }
  }

  static Map<String, Object> jsonDoRelatorio({
    required String contexto,
    required String mensagem,
    required String pilha,
    required String url,
    required String versao,
    required String plataforma,
  }) => {
    'origem': 'dart',
    'contexto': contexto,
    'mensagem': mensagem,
    'pilha': pilha,
    'arquivo': '',
    'linha': 0,
    'url': url,
    'versao': versao,
    'plataforma': plataforma,
  };

  static String _limitar(String texto, int limite) =>
      texto.length <= limite ? texto : texto.substring(0, limite);

  /// Prefixo fixo para não confundir com o log normal do app.
  static void debugPrintRelatorio(String detalhe) {
    debugPrint('[monitoramento] $detalhe');
  }
}
