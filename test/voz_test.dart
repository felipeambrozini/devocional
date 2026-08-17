import 'dart:convert';

import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/voz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('textoDeCapitulo', () {
    test('começa pela referência e lê cada versículo com o número', () {
      const capitulo = Capitulo(
        livro: 'joao',
        numero: 3,
        titulo: '',
        nome: 'João',
        versiculos: [
          (1, 'Havia entre os fariseus um homem chamado Nicodemos.'),
          (16, 'Porque Deus amou o mundo de tal maneira.'),
        ],
      );
      expect(
        textoDeCapitulo(capitulo),
        'João 3 1. Havia entre os fariseus um homem chamado Nicodemos. '
        '16. Porque Deus amou o mundo de tal maneira.',
      );
    });

    test('lê o sobrescrito quando o capítulo tem um (os Salmos)', () {
      const salmo = Capitulo(
        livro: 'salmos',
        numero: 23,
        titulo: 'Salmo de Davi.',
        nome: 'Salmos',
        versiculos: [(1, 'O Senhor é o meu pastor.')],
      );
      expect(
        textoDeCapitulo(salmo),
        'Salmos 23 Salmo de Davi. 1. O Senhor é o meu pastor.',
      );
    });
  });

  group('textoDeIntroducao', () {
    test('lê o título, as seções em ordem e a frase com a atribuição', () {
      const introducao = Introducao(
        livro: 'João',
        secoes: [
          ('Estrutura', 'Primeiro parágrafo.\n\nSegundo parágrafo.'),
        ],
        frase: 'Grandes coisas!',
        fraseComprovada: true,
        fonteDaFrase: 'O Tesouro de Davi',
      );
      expect(
        textoDeIntroducao(introducao),
        'Introdução de João. Estrutura Primeiro parágrafo. Segundo '
        'parágrafo. "Grandes coisas!" Charles H. Spurgeon, O Tesouro de Davi',
      );
    });

    test('sem frase comprovada lê a introdução sem a citação', () {
      const semFrase = Introducao(
        livro: 'João',
        secoes: [('Estrutura', 'Um parágrafo.')],
        frase: '',
        fraseComprovada: false,
        fonteDaFrase: '',
      );
      expect(
        textoDeIntroducao(semFrase),
        'Introdução de João. Estrutura Um parágrafo.',
      );
    });
  });

  group('sintetizar', () {
    final cliente = MockClient((request) async {
      if (request.url.path != '/v1/text:synthesize') {
        return http.Response('rota errada', 404);
      }
      if (request.url.queryParameters['key'] != 'teste') {
        return http.Response('chave errada', 403);
      }
      final corpo = json.decode(request.body) as Map<String, dynamic>;
      final input = corpo['input'] as Map<String, dynamic>;
      final voice = corpo['voice'] as Map<String, dynamic>;
      final audio = corpo['audioConfig'] as Map<String, dynamic>;
      if (input['text'] != 'No princípio.' ||
          voice['languageCode'] != 'pt-BR' ||
          voice['name'] != 'pt-BR-Neural2-B' ||
          audio['audioEncoding'] != 'MP3') {
        return http.Response('pedido diferente do esperado', 500);
      }
      return http.Response(
        json.encode({'audioContent': base64.encode([1, 2, 3])}),
        200,
      );
    });

    test('pede o MP3 à API com a voz e o pedido certos', () async {
      final audio = await sintetizar(
        'No princípio.',
        cliente: cliente,
        chave: 'teste',
      );
      expect(audio, [1, 2, 3]);
    });

    test('sem chave no build avisa como ligar, não estoura', () async {
      // Os testes rodam sem --dart-define: a chave vem vazia, e o usuário
      // precisa da mensagem de configuração, não de um erro sem sentido.
      await expectLater(
        sintetizar('Texto.', cliente: cliente),
        throwsA(
          isA<VozException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('TTS_API_KEY'),
          ),
        ),
      );
    });

    test('403 (chave sem a API liberada) vira aviso de atualizar', () async {
      final bloqueado = MockClient(
        (_) async => http.Response('{"error":{}}', 403),
      );
      await expectLater(
        sintetizar('Texto.', cliente: bloqueado, chave: 'teste'),
        throwsA(
          isA<VozException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('Atualize o aplicativo'),
          ),
        ),
      );
    });

    test('429 (teto do tier gratuito) vira aviso de esperar', () async {
      final noLimite = MockClient(
        (_) async => http.Response('{"error":{}}', 429),
      );
      await expectLater(
        sintetizar('Texto.', cliente: noLimite, chave: 'teste'),
        throwsA(
          isA<VozException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('limite gratuito'),
          ),
        ),
      );
    });

    test('resposta sem áudio vira aviso de tentar de novo', () async {
      final vazia = MockClient(
        (_) async => http.Response(json.encode({'audioContent': ''}), 200),
      );
      await expectLater(
        sintetizar('Texto.', cliente: vazia, chave: 'teste'),
        throwsA(isA<VozException>()),
      );
    });
  });
}