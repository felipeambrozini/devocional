import 'dart:convert';

import 'package:felipe_ambrozini/data/ia.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/personas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response respostaDaGemini(String texto) => http.Response(
    json.encode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': texto},
            ],
          },
        },
      ],
    }),
    200,
  );

  group('perguntar', () {
    test('mapeia o histórico e fecha a pergunta como última fala do usuário',
        () async {
      late Map<String, dynamic> corpo;
      final cliente = MockClient((requisicao) async {
        corpo = json.decode(requisicao.body) as Map<String, dynamic>;
        return respostaDaGemini('Amem.');
      });

      final resposta = await perguntar(
        persona: personaSpurgeon,
        cliente: cliente,
        pergunta: 'Como vencer a ansiedade?',
        historico: [
          Mensagem(id: '1', papel: 'user', texto: 'Estou ansioso.', momento: 1),
          Mensagem(
            id: '2',
            papel: 'assistant',
            texto: 'Busque o Senhor.',
            momento: 2,
          ),
        ],
      );

      expect(resposta, 'Amem.');
      final papeis = [
        for (final c in corpo['contents'] as List) (c as Map)['role'],
      ];
      expect(papeis, ['user', 'model', 'user']);
      final ultimo = (corpo['contents'] as List).last as Map;
      expect(
        ((ultimo['parts'] as List).first as Map)['text'],
        'Como vencer a ansiedade?',
      );
      final sistema = (((corpo['systemInstruction'] as Map)['parts'] as List)
              .first as Map)['text']
          as String;
      expect(sistema, contains('Tabernáculo Metropolitano'));
      expect(sistema, contains('PROIBIDO usar travessões'));
    });

    test('derruba falas seguidas do mesmo papel e funde perguntas repetidas',
        () async {
      late Map<String, dynamic> corpo;
      final cliente = MockClient((requisicao) async {
        corpo = json.decode(requisicao.body) as Map<String, dynamic>;
        return respostaDaGemini('ok');
      });

      // "user, user, assistant, assistant, user": o Gemini não aceita papéis
      // repetidos. O último "user" é a pergunta anterior que falhou, e a
      // pergunta nova entra junto dela, sem virar um sexto turno.
      await perguntar(
        persona: personaFelipe,
        cliente: cliente,
        pergunta: 'E se eu fizer tudo de novo?',
        historico: [
          Mensagem(id: '1', papel: 'user', texto: 'Pergunta 1', momento: 1),
          Mensagem(id: '2', papel: 'user', texto: 'Pergunta 2', momento: 2),
          Mensagem(id: '3', papel: 'assistant', texto: 'Resposta 1', momento: 3),
          Mensagem(id: '4', papel: 'assistant', texto: 'Resposta 2', momento: 4),
          Mensagem(id: '5', papel: 'user', texto: 'Pergunta 3', momento: 5),
        ],
      );

      final conteudos = corpo['contents'] as List;
      final papeis = [for (final c in conteudos) (c as Map)['role']];
      expect(papeis, ['user', 'model', 'user']);
      final ultimo = conteudos.last as Map;
      final textoDoUltimo =
          ((ultimo['parts'] as List).first as Map)['text'] as String;
      expect(textoDoUltimo, contains('Pergunta 3'));
      expect(textoDoUltimo, contains('E se eu fizer tudo de novo?'));
    });

    test('anexa o horário ao sistema da persona que cumprimenta', () async {
      late Map<String, dynamic> corpo;
      final cliente = MockClient((requisicao) async {
        corpo = json.decode(requisicao.body) as Map<String, dynamic>;
        return respostaDaGemini('Bom dia');
      });

      await perguntar(
        persona: personaFelipe,
        cliente: cliente,
        pergunta: 'Oi',
        historico: const [],
      );

      final sistema = (((corpo['systemInstruction'] as Map)['parts'] as List)
              .first as Map)['text']
          as String;
      expect(sistema, contains('Horário atual do interlocutor'));
      expect(sistema, contains('Bom dia'));
    });

    test('429 vira mensagem amigável de limite gratuito', () async {
      final cliente = MockClient(
        (requisicao) async => http.Response('{"error": {}}', 429),
      );

      await expectLater(
        perguntar(
          persona: personaSpurgeon,
          cliente: cliente,
          pergunta: 'Oi',
          historico: const [],
        ),
        throwsA(
          isA<IaException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('limite gratuito'),
          ),
        ),
      );
    });

    test('403 vira mensagem amigável de chave sem permissão', () async {
      final cliente = MockClient(
        (requisicao) async => http.Response('{"error": {}}', 403),
      );

      await expectLater(
        perguntar(
          persona: personaSpurgeon,
          cliente: cliente,
          pergunta: 'Oi',
          historico: const [],
        ),
        throwsA(
          isA<IaException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('sem permissão'),
          ),
        ),
      );
    });

    test('500 vira mensagem de serviço fora do ar', () async {
      final cliente = MockClient(
        (requisicao) async => http.Response('{"error": {}}', 500),
      );

      await expectLater(
        perguntar(
          persona: personaSpurgeon,
          cliente: cliente,
          pergunta: 'Oi',
          historico: const [],
        ),
        throwsA(
          isA<IaException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('não respondeu agora'),
          ),
        ),
      );
    });

    test('200 com corpo ilegível vira IaException, não exceção solta',
        () async {
      // Um 200 com HTML de proxy ou resposta truncada não pode vazar como
      // FormatException: a tela do chat só trata IaException.
      final cliente = MockClient(
        (requisicao) async => http.Response('<html>proxy</html>', 200),
      );

      await expectLater(
        perguntar(
          persona: personaSpurgeon,
          cliente: cliente,
          pergunta: 'Oi',
          historico: const [],
        ),
        throwsA(
          isA<IaException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('não respondeu agora'),
          ),
        ),
      );
    });

    test('falha de rede vira IaException de conexão', () async {
      final cliente = MockClient(
        (requisicao) async => throw http.ClientException('sem rede'),
      );

      await expectLater(
        perguntar(
          persona: personaSpurgeon,
          cliente: cliente,
          pergunta: 'Oi',
          historico: const [],
        ),
        throwsA(
          isA<IaException>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('Não foi possível falar agora'),
          ),
        ),
      );
    });

    test('resposta sem texto vira IaException, não string nula', () async {
      final cliente = MockClient(
        (requisicao) async => http.Response('{"candidates": []}', 200),
      );

      await expectLater(
        perguntar(
          persona: personaSpurgeon,
          cliente: cliente,
          pergunta: 'Oi',
          historico: const [],
        ),
        throwsA(isA<IaException>()),
      );
    });
  });
}