import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'google.dart';
import 'modelos.dart';
import 'personas.dart';
import 'registro.dart';

/// Cliente da Gemini API gratuita (sem cartão de crédito).
///
/// A chave mora em `lib/data/google.dart`, junto do cabeçalho de identidade do
/// apk. A leitura em voz alta não usa mais essa chave nem TTS: os áudios são
/// MP3 pré-gerados (ver `lib/data/voz.dart`).
///
/// Nome fixo, não o alias `gemini-flash-latest`: o alias pode passar a
/// apontar para um modelo fora do tier gratuito sem aviso, e a falha vira um
/// 403 disfarçado de limite de cota. Flash-Lite é o mais barato da linha, se
/// um dia sair do grátis (faturamento habilitado no projeto). 2.5 foi
/// descontinuado para novos usuários em favor do 3.5 (aviso 404 da própria
/// API), então o nome fixo também precisa de olho na aposentadoria do Google.
const _modelo = 'gemini-3.5-flash-lite';

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
            '$_modelo:generateContent?key=$chaveGemini',
          ),
          headers: await cabecalhosGoogle(),
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
  } catch (erro, pilha) {
    Registro.erro('Ia.responder', erro, pilha);
    throw const IaException(
      'Não foi possível falar agora. Verifique se há conexão e tente de novo.',
    );
  }

  if (resposta.statusCode != 200) {
    Registro.erro(
      'Ia.responder',
      'HTTP ${resposta.statusCode}: ${utf8.decode(resposta.bodyBytes)}',
    );
    throw IaException(_mensagemDeErro(resposta));
  }

  final Map corpo;
  try {
    corpo = json.decode(utf8.decode(resposta.bodyBytes)) as Map;
  } catch (erro, pilha) {
    // 200 com corpo ilegível (HTML de proxy, resposta truncada): a mesma
    // mensagem do serviço fora do ar, não uma exceção sem tratamento.
    Registro.erro('Ia.responder', erro, pilha);
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

/// 429 é o teto do tier gratuito, que zera sozinho em até um dia. 403 é outra
/// coisa: a chave sem permissão para o modelo (não se resolve sozinho, e sem
/// isso o usuário achava que era o mesmo limite e ficava esperando à toa). Os
/// outros códigos são serviço fora do ar. Não se envia o corpo da API ao
/// usuário: é inglês técnico que não ajuda ninguém; fica no registro.
String _mensagemDeErro(http.Response resposta) {
  if (resposta.statusCode == 429) {
    return 'O limite gratuito da inteligência artificial foi atingido. '
        'Espere um pouco e tente de novo.';
  }
  if (resposta.statusCode == 403) {
    return 'A inteligência artificial recusou o pedido (chave sem permissão '
        'para este modelo). Isto não se resolve sozinho — avise quem mantém '
        'o app.';
  }
  return 'A inteligência artificial não respondeu agora. Tente de novo em '
      'instantes.';
}

/// Identificador único de mensagem, para a fusão com a nuvem não duplicar.
String novoIdDeMensagem() {
  final agora = DateTime.now().millisecondsSinceEpoch;
  return '$agora-${Random().nextInt(0x7FFFFFFF)}';
}