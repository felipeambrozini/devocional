import 'dart:async';

import 'package:felipe_ambrozini/data/conversador.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/ia.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/personas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Cria a conversa e devolve o id, como a tela do chat faria ao abrir uma
  /// conversa existente.
  Future<String> abrirConversa(Estado estado, List<Mensagem> mensagens) async {
    var titulo = '';
    for (final m in mensagens) {
      if (m.doUsuario) {
        titulo = m.texto;
        break;
      }
    }
    final conversa = await estado.novaConversa('spurgeon', titulo: titulo);
    for (final m in mensagens) {
      await estado.registrarMensagem('spurgeon', conversa.id, m);
    }
    return conversa.id;
  }

  group('enviar', () {
    test('grava a pergunta, a resposta e limpa a pendência', () async {
      final estado = await Estado.abrir();
      final conversador = Conversador(
        persona: personaSpurgeon,
        estado: estado,
        chamar: ({required persona, required historico, required pergunta}) async {
          return 'Amém, meu filho.';
        },
      );
      expect(conversador.id, isNull, reason: 'a conversa nova só nasce na fala');

      await conversador.enviar('Como vencer a ansiedade?');

      expect(conversador.id, isNotNull);
      final mensagens = estado.mensagensDe('spurgeon', conversador.id!);
      expect(mensagens, hasLength(2));
      expect(mensagens.first.texto, 'Como vencer a ansiedade?');
      expect(mensagens.first.pendente, isFalse,
          reason: 'a resposta chegou, nada fica pendente');
      expect(mensagens.last.papel, 'assistant');
      expect(mensagens.last.texto, 'Amém, meu filho.');
      expect(conversador.respondendo, isFalse);
      expect(conversador.erro, isNull);
      expect(
        estado.conversasDe('spurgeon').single.titulo,
        'Como vencer a ansiedade?',
        reason: 'a primeira pergunta vira o título no histórico',
      );
    });

    test('a pergunta chega ao modelo como última fala do histórico', () async {
      final estado = await Estado.abrir();
      final id = await abrirConversa(estado, [
        Mensagem(id: '1', papel: 'user', texto: 'Tenho medo.', momento: 1),
      ]);
      late String vista;
      final conversador = Conversador(
        persona: personaSpurgeon,
        estado: estado,
        conversaId: id,
        chamar: ({required persona, required historico, required pergunta}) async {
          vista = pergunta;
          // O histórico que o modelo recebe já inclui a pergunta nova,
          // registrada como pendente: a última fala é ela, na ordem.
          expect(historico.last.texto, pergunta);
          return 'Confie no Senhor.';
        },
      );

      await conversador.enviar('Como parar?');

      expect(vista, 'Como parar?');
      expect(
        estado.mensagensDe('spurgeon', id).first.texto,
        'Tenho medo.',
        reason: 'a conversa antiga não é tocada',
      );
    });

    test('respondendo fica ligado enquanto a IA responde', () async {
      final estado = await Estado.abrir();
      final portao = Completer<String>();
      late final Conversador conversador;
      conversador = Conversador(
        persona: personaSpurgeon,
        estado: estado,
        chamar: ({required persona, required historico, required pergunta}) {
          expect(conversador.respondendo, isTrue,
              reason: 'a tela precisa do indicador durante a espera');
          return portao.future;
        },
      );

      final enviando = conversador.enviar('Oi');
      await Future<void>.delayed(Duration.zero);
      expect(conversador.respondendo, isTrue);

      portao.complete('Paz.');
      await enviando;
      expect(conversador.respondendo, isFalse);
    });

    test('falha vira erro e deixa a pergunta pendente para repetir', () async {
      final estado = await Estado.abrir();
      var tentativas = 0;
      final conversador = Conversador(
        persona: personaSpurgeon,
        estado: estado,
        chamar: ({required persona, required historico, required pergunta}) async {
          tentativas++;
          if (tentativas == 1) {
            throw const IaException('O limite gratuito da inteligência '
                'artificial foi atingido.');
          }
          return 'Agora sim.';
        },
      );

      await conversador.enviar('Pode responder?');

      expect(conversador.erro, contains('limite gratuito'));
      expect(conversador.respondendo, isFalse);
      expect(estado.mensagensDe('spurgeon', conversador.id!), hasLength(1));
      expect(
        estado.mensagensDe('spurgeon', conversador.id!).single.pendente,
        isTrue,
        reason: 'a pergunta fica marcada para o "Tentar de novo"',
      );

      await conversador.repetir();

      expect(conversador.erro, isNull);
      expect(conversador.respondendo, isFalse);
      expect(estado.mensagensDe('spurgeon', conversador.id!), hasLength(2));
      expect(
        estado.mensagensDe('spurgeon', conversador.id!).last.texto,
        'Agora sim.',
      );
      expect(
        estado.mensagensDe('spurgeon', conversador.id!).first.pendente,
        isFalse,
        reason: 'a resposta chegou e limpa a pendência antiga',
      );
    });

    test('repetir sem falha anterior refaz a última pergunta mesmo assim',
        () async {
      final estado = await Estado.abrir();
      final feitas = <String>[];
      final conversador = Conversador(
        persona: personaSpurgeon,
        estado: estado,
        chamar: ({required persona, required historico, required pergunta}) async {
          feitas.add(pergunta);
          return 'respondi';
        },
      );

      await conversador.enviar('Primeira');
      expect(feitas, ['Primeira']);

      // Depois de um sucesso o "Tentar de novo" não está na tela, mas repetir
      // continua seguro: refaz a última pergunta, sem duplicar a pergunta.
      await conversador.repetir();
      expect(feitas, ['Primeira', 'Primeira']);
      expect(estado.mensagensDe('spurgeon', conversador.id!), hasLength(3));
    });
  });

  group('retomarInterrompida', () {
    test('última pergunta pendente oferece o tentar de novo', () async {
      final estado = await Estado.abrir();
      final id = await abrirConversa(estado, [
        Mensagem(
          id: '1',
          papel: 'user',
          texto: 'Sumiu?',
          momento: 1,
          pendente: true,
        ),
      ]);
      final conversador = Conversador(
        persona: personaSpurgeon,
        estado: estado,
        conversaId: id,
        chamar: ({required persona, required historico, required pergunta}) async {
          return 'Aqui estou.';
        },
      );

      conversador.retomarInterrompida();

      expect(conversador.erro, 'A resposta anterior não chegou.');
      expect(conversador.ultimaPergunta, 'Sumiu?');

      // E o "Tentar de novo" resolve de verdade.
      await conversador.repetir();
      expect(conversador.erro, isNull);
      expect(estado.mensagensDe('spurgeon', id), hasLength(2));
    });

    test('conversa sossegada não acende o aviso', () async {
      final estado = await Estado.abrir();
      final id = await abrirConversa(estado, [
        Mensagem(id: '1', papel: 'user', texto: 'Oi', momento: 1),
        Mensagem(id: '2', papel: 'assistant', texto: 'Paz.', momento: 2),
      ]);
      final conversador = Conversador(
        persona: personaSpurgeon,
        estado: estado,
        conversaId: id,
        chamar: ({required persona, required historico, required pergunta}) async {
          return 'ok';
        },
      );

      conversador.retomarInterrompida();

      expect(conversador.erro, isNull);
      expect(conversador.ultimaPergunta, isEmpty);
    });

    test('conversa nova não tem o que retomar', () async {
      final estado = await Estado.abrir();
      final conversador = Conversador(
        persona: personaSpurgeon,
        estado: estado,
        chamar: ({required persona, required historico, required pergunta}) async {
          return 'ok';
        },
      );

      conversador.retomarInterrompida();

      expect(conversador.erro, isNull);
      expect(conversador.ultimaPergunta, isEmpty);
    });
  });
}