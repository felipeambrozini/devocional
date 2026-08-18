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
        secoes: [('Estrutura', 'Primeiro parágrafo.\n\nSegundo parágrafo.')],
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
          voice['name'] != 'pt-BR-chirp3-hd-fenrir' ||
          audio['audioEncoding'] != 'MP3' ||
          audio['speakingRate'] != 0.92) {
        return http.Response('pedido diferente do esperado', 500);
      }
      return http.Response(
        json.encode({
          'audioContent': base64.encode([1, 2, 3]),
        }),
        200,
      );
    });

    test('pede o MP3 à API com a voz e o pedido certos', () async {
      final audio = await sintetizar(
        'No princípio.',
        tipo: TipoConteudoAudio.biblia,
        cliente: cliente,
        chave: 'teste',
      );
      expect(audio, [1, 2, 3]);
    });

    test(
      'cada tipo de conteúdo pede a própria voz e o próprio ritmo',
      () async {
        final pedidos = <(String, double)>[];
        final medidor = MockClient((request) async {
          final corpo = json.decode(request.body) as Map<String, dynamic>;
          final voice = corpo['voice'] as Map<String, dynamic>;
          final audio = corpo['audioConfig'] as Map<String, dynamic>;
          pedidos.add((
            voice['name'] as String,
            audio['speakingRate'] as double,
          ));
          return http.Response(
            json.encode({
              'audioContent': base64.encode([1, 2, 3]),
            }),
            200,
          );
        });
        for (final tipo in TipoConteudoAudio.values) {
          await sintetizar(
            'Texto.',
            tipo: tipo,
            cliente: medidor,
            chave: 'teste',
          );
        }
        expect(pedidos, [
          ('pt-BR-chirp3-hd-fenrir', 0.92), // biblia
          ('pt-BR-chirp3-hd-orus', 0.94), // devocionalManha
          ('pt-BR-chirp3-hd-orus', 0.88), // devocionalNoite
          ('pt-BR-chirp3-hd-orus', 0.91), // promessasDeDeus
          ('pt-BR-chirp3-hd-fenrir', 0.92), // introducao
        ]);
      },
    );

    test(
      'texto maior que o teto é fatiado e os áudios emendados na ordem',
      () async {
        final pedidos = <String>[];
        final fatiado = MockClient((request) async {
          final corpo = json.decode(request.body) as Map<String, dynamic>;
          final texto =
              (corpo['input'] as Map<String, dynamic>)['text'] as String;
          pedidos.add(texto);
          return http.Response(
            json.encode({
              'audioContent': base64.encode(utf8.encode('áudio: $texto')),
            }),
            200,
          );
        });
        // 600 frases: ~16 KB, mais de três vezes o teto de 5000 bytes da API.
        final texto = List.filled(600, 'Um versículo bem comprido.').join(' ');
        final audio = await sintetizar(
          texto,
          tipo: TipoConteudoAudio.biblia,
          cliente: fatiado,
          chave: 'teste',
        );

        expect(pedidos.length, greaterThan(1));
        for (final pedido in pedidos) {
          expect(
            utf8.encode(pedido).length,
            lessThanOrEqualTo(5000),
            reason: 'cada pedido respeita o teto da API',
          );
        }
        for (var i = 0; i < pedidos.length - 1; i++) {
          expect(
            pedidos[i],
            endsWith('.'),
            reason: 'o corte cai na fronteira de frase',
          );
        }
        final esperado = pedidos.map((pedido) => 'áudio: $pedido').join();
        expect(utf8.decode(audio), esperado);
      },
    );

    test('sem chave no build avisa como ligar, não estoura', () async {
      // Os testes rodam sem --dart-define: a chave vem vazia, e o usuário
      // precisa da mensagem de configuração, não de um erro sem sentido.
      await expectLater(
        sintetizar('Texto.', tipo: TipoConteudoAudio.biblia, cliente: cliente),
        throwsA(
          isA<VozException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('TTS_API_KEY'),
          ),
        ),
      );
    });

    test(
      '403 (chave sem a API liberada) vira aviso de serviço, não de aparelho',
      () async {
        // O erro é de configuração da chave na nuvem: culpar o aparelho do
        // leitor ("atualize ou recarregue") mandaria a um conserto que não
        // existe. A mensagem fala do serviço e deixa o "Tentar de novo" agir.
        final bloqueado = MockClient(
          (_) async => http.Response('{"error":{}}', 403),
        );
        await expectLater(
          sintetizar(
            'Texto.',
            tipo: TipoConteudoAudio.biblia,
            cliente: bloqueado,
            chave: 'teste',
          ),
          throwsA(
            isA<VozException>().having(
              (e) => e.mensagem,
              'mensagem',
              contains('não está disponível agora'),
            ),
          ),
        );
      },
    );

    test('429 (teto do tier gratuito) vira aviso de esperar', () async {
      final noLimite = MockClient(
        (_) async => http.Response('{"error":{}}', 429),
      );
      await expectLater(
        sintetizar(
          'Texto.',
          tipo: TipoConteudoAudio.biblia,
          cliente: noLimite,
          chave: 'teste',
        ),
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
        sintetizar(
          'Texto.',
          tipo: TipoConteudoAudio.biblia,
          cliente: vazia,
          chave: 'teste',
        ),
        throwsA(isA<VozException>()),
      );
    });
  });
}
