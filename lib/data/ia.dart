import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_api_headers/google_api_headers.dart';
import 'package:http/http.dart' as http;

import 'modelos.dart';
import 'personas.dart';

/// Cliente da Gemini API gratuita (sem cartão de crédito).
///
/// São duas chaves, uma por plataforma, porque cada uma prova a identidade
/// de um jeito:
///
/// * _chaveWeb: criada no Google Cloud Console, restrita ao site do app
///   (`https://felipeambrozini.github.io` e `localhost`) e à Generative
///   Language API. O navegador manda o cabeçalho Origin, que é a prova que
///   essa restrição confere.
/// * _chaveAndroid: criada no Google Cloud Console, restrita ao app Android
///   (`com.felipeambrozini.devocional` + SHA-1 da assinatura) e à Generative
///   Language API. O celular prova a identidade com os cabeçalhos
///   X-Android-Package/X-Android-Cert, calculados em tempo de execução pelo
///   plugin google_api_headers — então debug e release funcionam sem trocar
///   nada, desde que os dois SHA-1 estejam registrados na chave.
///
/// Não é segredo de servidor: a Google desenha este caminho para apps
/// client-side, com CORS aberto (conferido em OPTIONS) e limite por projeto.
const _chaveWeb =
    'AIzaSyCA0Od5msmQjlEkyXtMVzJnLy0RTpmlT8g';

const _chaveAndroid =
    'AIzaSyBAD7HPChEKw59751oB2Qlx6b31-_S4knk';

String get _chaveGemini {
  if (kIsWeb) return _chaveWeb;
  return _chaveAndroid;
}

/// Os cabeçalhos do pedido à Gemini.
///
/// Fora da web, a chave restrita ao app exige a identidade do apk em todo
/// pedido. O plugin google_api_headers lê o nome do pacote e o SHA-1 da
/// assinatura em tempo de execução — assim o mesmo código serve para o build
/// de debug e o de release. No desktop (desenvolvimento) o plugin não existe
/// e o pedido segue sem a prova, que a própria API recusa se precisar.
Future<Map<String, String>> _cabecalhosDoPedido() async {
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

/// Alias estável da Google para o Flash atual: aponta para o modelo estável
/// vigente, então o app não quebra quando a Google aposenta um modelo. Os
/// Flash são a linha gratuita; os Pro saíram do tier grátis em 2026.
const _modelo = 'gemini-flash-latest';

/// Cliente compartilhado do app. Um cliente por chamada deixaria uma conexão
/// aberta a cada mensagem do chat; os testes injetam o próprio cliente falso.
final _clientePadrao = http.Client();

/// Teto de tokens da resposta: um conselho de Spurgeon não precisa de mais, e
/// um teto baixo segura a latência e o custo do tier gratuito.
const _maxTokensDeResposta = 2048;

/// Falha na conversa com a Gemini, já traduzida para o que o usuário deve ler.
///
/// Quem chama (a tela do chat) mostra [mensagem] num balão de erro com botão
/// de tentar de novo; nada disto é persistido no histórico.
class IaException implements Exception {
  const IaException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Fala com a persona e devolve a resposta.
///
/// [historico] é o que o [Estado] já guardou, [pergunta] a mensagem nova. O
/// histórico vai inteiro ao modelo, com o papel mapeado para o vocabulário do
/// Gemini ("user"/"model"), e a pergunta fecha como última fala do usuário,
/// que é o formato que a API exige.
///
/// [cliente] existe só para os testes injetarem um HTTP falso; quem chama de
/// verdade usa o cliente global do pacote `http`.
Future<String> perguntar({
  required Persona persona,
  required List<Mensagem> historico,
  required String pergunta,
  http.Client? cliente,
}) async {
  final conteudos = <Map<String, dynamic>>[];
  var ultimoPapel = '';
  for (final mensagem in historico) {
    final papel = mensagem.doUsuario ? 'user' : 'model';
    if (papel == ultimoPapel) continue;
    conteudos.add({'role': papel, 'parts': [{'text': mensagem.texto}]});
    ultimoPapel = papel;
  }
  // A API não aceita duas falas seguidas do mesmo papel, nem uma conversa que
  // não termine no usuário. Quando o histórico já termina no usuário (a
  // pergunta anterior que falhou), a nova pergunta entra junta na mesma fala.
  if (ultimoPapel == 'user') {
    final ultimo = conteudos.last['parts'] as List;
    ultimo[0] = {
      'text': '${(ultimo[0] as Map)['text']}\n\n$pergunta',
    };
  } else {
    conteudos.add({'role': 'user', 'parts': [{'text': pergunta}]});
  }

  final http.Response resposta;
  try {
    resposta = await (cliente ?? _clientePadrao)
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/'
            '$_modelo:generateContent?key=$_chaveGemini',
          ),
          headers: await _cabecalhosDoPedido(),
          body: json.encode({
            'systemInstruction': {
              'parts': [
                {'text': saudacaoComHorario(persona, DateTime.now())},
              ],
            },
            'contents': conteudos,
            'generationConfig': {'maxOutputTokens': _maxTokensDeResposta},
          }),
        )
        .timeout(const Duration(seconds: 90));
  } catch (_) {
    throw const IaException(
      'Não foi possível falar agora. Verifique se há conexão e tente de novo.',
    );
  }

  if (resposta.statusCode != 200) {
    throw IaException(_mensagemDeErro(resposta));
  }

  final Map corpo;
  try {
    corpo = json.decode(utf8.decode(resposta.bodyBytes)) as Map;
  } catch (_) {
    // 200 com corpo ilegível (HTML de proxy, resposta truncada): a mesma
    // mensagem do serviço fora do ar, não uma exceção sem tratamento.
    throw const IaException(
      'A inteligência artificial não respondeu agora. Tente de novo em '
      'instantes.',
    );
  }
  final candidatos = corpo['candidates'];
  final primeiro = candidatos is List && candidatos.isNotEmpty
      ? candidatos.first
      : null;
  final conteudo = primeiro is Map ? primeiro['content'] : null;
  final partes = conteudo is Map ? conteudo['parts'] : null;
  final primeira = partes is List && partes.isNotEmpty ? partes.first : null;
  final texto = primeira is Map ? primeira['text'] : null;
  if (texto is! String || texto.trim().isEmpty) {
    throw const IaException('A resposta veio vazia. Tente de novo.');
  }
  return texto.trim();
}

/// 429 é o teto do tier gratuito, que zera sozinho em até um dia; os outros
/// códigos são serviço fora do ar. Não se envia o corpo da API ao usuário:
/// é inglês técnico que não ajuda ninguém.
String _mensagemDeErro(http.Response resposta) {
  if (resposta.statusCode == 429 || resposta.statusCode == 403) {
    return 'O limite gratuito da inteligência artificial foi atingido. '
        'Espere um pouco e tente de novo.';
  }
  return 'A inteligência artificial não respondeu agora. Tente de novo em '
      'instantes.';
}

/// Identificador único de mensagem, para a fusão com a nuvem não duplicar.
String novoIdDeMensagem() {
  final agora = DateTime.now().millisecondsSinceEpoch;
  return '$agora-${Random().nextInt(1 << 32)}';
}