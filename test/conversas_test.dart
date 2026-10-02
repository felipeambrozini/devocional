import 'dart:convert';

import 'package:felipe_ambrozini/dados/conversas.dart';
import 'package:felipe_ambrozini/dados/modelos.dart';
import 'package:felipe_ambrozini/dados/personas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O histórico do chat tem duas portas de entrada do formato antigo (persona →
/// lista de mensagens): a leitura local, em [Conversas.ler], e a fusão com a
/// nuvem, em [Conversas.fundirConversas]. São duas cópias da mesma migração, e é
/// por isso que elas são testadas lado a lado: uma correção que fosse só num
/// dos lados faria o mesmo histórico virar conversas diferentes em aparelhos
/// diferentes.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Base dos momentos. Lápide e conversa se comparam em milissegundos desde a
  /// época, e um número pequeno de teste é sempre mais velho que uma lápide
  /// feita com `DateTime.now()` — o que inverteria a regra sem querer.
  final agora = DateTime.now().millisecondsSinceEpoch;

  Future<Conversas> abrir({Map<String, Object>? guardado}) async {
    if (guardado != null) SharedPreferences.setMockInitialValues(guardado);
    return Conversas.ler(await SharedPreferences.getInstance(), () {});
  }

  Mensagem mensagem(String id, String papel, String texto, int momento) =>
      Mensagem(id: id, papel: papel, texto: texto, momento: momento);

  /// O formato antigo: a chave é o id da persona e o valor é a lista de
  /// mensagens, sem id de conversa nem título. [apagadas] usa a chave antiga
  /// também, pelo id da persona.
  String legado(
    Map<String, List<Map<String, dynamic>>> porPersona, {
    Map<String, int> apagadas = const {},
  }) => json.encode({
    for (final e in porPersona.entries) e.key: e.value,
    if (apagadas.isNotEmpty) 'apagadas': apagadas,
  });

  /// Momento 200 e lápide 500: o histórico sempre perde para a exclusão, então
  /// quem manda na conversa migrada é a lápide.
  final conversaAntiga = [
    mensagem(
      'm1',
      Mensagem.papelUsuario,
      'Qual a primeira Fé?',
      100,
    ).paraJson(),
    mensagem(
      'm2',
      Mensagem.papelAssistente,
      'A Fé espera por ouvir.',
      200,
    ).paraJson(),
  ];

  /// Uma conversa já viva, com uma pergunta registrada.
  Future<Conversas> comConversaViva({String persona = 'felipe'}) async {
    final conversas = await abrir();
    final conversa = await conversas.novaConversa(persona, titulo: 'Pergunta');
    await conversas.registrarMensagem(
      persona,
      conversa.id,
      mensagem('a1', Mensagem.papelUsuario, 'Pergunta', agora),
    );
    return conversas;
  }

  group('migração do formato antigo', () {
    test(
      'a leitura local vira uma conversa com id fixo, título e momento',
      () async {
        final conversas = await abrir(
          guardado: {
            'conversas': legado({personaSpurgeon.id: conversaAntiga}),
          },
        );

        final lista = conversas.conversasDe(personaSpurgeon.id);
        expect(lista, hasLength(1));
        final migrada = lista.single;
        expect(migrada.id, 'conversa-${personaSpurgeon.id}');
        // O título é a primeira pergunta de quem lê, não a primeira mensagem.
        expect(migrada.titulo, 'Qual a primeira Fé?');
        // O momento é da última fala, que é o que a lista de histórico ordena.
        expect(migrada.momento, 200);
        expect(migrada.mensagens.map((m) => m.id), ['m1', 'm2']);
      },
    );

    test('a lápide por persona migra para a conversa migrada', () async {
      final conversas = await abrir(
        guardado: {
          'conversas': legado(
            {personaSpurgeon.id: conversaAntiga},
            apagadas: {personaSpurgeon.id: 500},
          ),
        },
      );

      // A lápide antiga (por persona) passa a valer pela conversa migrada:
      // registrada nessa conversa, [Conversas.registrarMensagem] recusa a
      // mensagem em vez de ressuscitar um histórico apagado.
      final migrada = conversas.conversasDe(personaSpurgeon.id).single;
      expect(migrada.id, 'conversa-${personaSpurgeon.id}');
      await conversas.registrarMensagem(
        personaSpurgeon.id,
        migrada.id,
        mensagem('m9', Mensagem.papelUsuario, 'oi', agora),
      );
      expect(
        conversas.mensagensDe(personaSpurgeon.id, migrada.id).map((m) => m.id),
        ['m1', 'm2'],
      );

      // E a conversa nova desta persona não nasce confundida com a apagada.
      final nova = await conversas.novaConversa(
        personaSpurgeon.id,
        titulo: 'Nova',
      );
      await conversas.registrarMensagem(
        personaSpurgeon.id,
        nova.id,
        mensagem('m10', Mensagem.papelUsuario, 'oi de novo', agora),
      );
      expect(nova.id, isNot('conversa-${personaSpurgeon.id}'));
      expect(conversas.conversasDe(personaSpurgeon.id), hasLength(2));
    });

    test('a fusão com a nuvem migra igual à leitura local', () async {
      // A mesma entrada pelos dois caminhos, e a comparação campo a campo: é
      // a comparação que impede as duas cópias da migração de divergirem.
      final pelaLeitura = await abrir(
        guardado: {
          'conversas': legado({personaSpurgeon.id: conversaAntiga}),
        },
      );
      final pelaFusao = await abrir();
      await pelaFusao.fundirConversas(
        legado({personaSpurgeon.id: conversaAntiga}),
      );

      final a = pelaLeitura.conversasDe(personaSpurgeon.id).single;
      final b = pelaFusao.conversasDe(personaSpurgeon.id).single;
      expect(b.id, a.id);
      expect(b.titulo, a.titulo);
      expect(b.momento, a.momento);
      expect(b.mensagens.map((m) => m.id), a.mensagens.map((m) => m.id));
    });

    test('lápide remota no formato antigo apaga a conversa migrada', () async {
      final conversas = await abrir();
      await conversas.fundirConversas(
        legado(
          {personaSpurgeon.id: conversaAntiga},
          apagadas: {personaSpurgeon.id: 500},
        ),
      );

      // Sem a conversa, a lápide por conversa segue valendo: o reaparecimento
      // do histórico antigo não ressuscita nada.
      await conversas.fundirConversas(legado({personaSpurgeon.id: []}));
      expect(conversas.conversasDe(personaSpurgeon.id), isEmpty);
    });
  });

  group('lápide contra conversa', () {
    test(
      'a lápide mais nova que a conversa apaga nos dois aparelhos',
      () async {
        final conversas = await comConversaViva();
        final conversa = conversas.conversasDe(personaFelipe.id).single;
        await conversas.limparConversa(personaFelipe.id, conversa.id);

        // Aparelho novo, que só conhece a cópia serializada com a lápide.
        final outro = await abrir();
        await outro.fundirConversas(conversas.serializarConversas());
        expect(outro.conversasDe(personaFelipe.id), isEmpty);
      },
    );

    test('conversa mais nova que a lápide volta inteira', () async {
      final conversas = await comConversaViva();
      final conversa = conversas.conversasDe(personaFelipe.id).single;
      await conversas.limparConversa(personaFelipe.id, conversa.id);

      await conversas.fundirConversas(
        json.encode({
          personaFelipe.id: {
            conversa.id: Conversa(
              id: conversa.id,
              titulo: conversa.titulo,
              momento: agora + 60000,
              mensagens: [
                mensagem(
                  'a2',
                  Mensagem.papelUsuario,
                  'continuação',
                  agora + 60000,
                ),
              ],
            ).paraJson(),
          },
        }),
      );

      final voltou = conversas.conversasDe(personaFelipe.id);
      expect(voltou, hasLength(1));
      expect(voltou.single.mensagens.map((m) => m.id), ['a2']);
    });

    test('lápide sozinha, sem conversa, também impede o retorno', () async {
      final conversas = await comConversaViva();
      final conversa = conversas.conversasDe(personaFelipe.id).single;
      await conversas.limparConversa(personaFelipe.id, conversa.id);

      final outro = await abrir();
      await outro.fundirConversas(
        json.encode({
          'apagadas': {conversa.id: agora},
        }),
      );
      expect(outro.conversasDe(personaFelipe.id), isEmpty);
    });

    test('restaurar remove a lápide e devolve a conversa', () async {
      final conversas = await comConversaViva();
      final conversa = conversas.conversasDe(personaFelipe.id).single;
      await conversas.limparConversa(personaFelipe.id, conversa.id);
      await conversas.restaurarConversa(personaFelipe.id, conversa);

      expect(conversas.conversasDe(personaFelipe.id).single.id, conversa.id);
      // Sem lápide, o momento vai para agora para a conversa restaurada vencer
      // a própria exclusão na próxima fusão, e nada de lápide sobe.
      expect(conversas.serializarConversas(), isNot(contains('apagadas')));
    });
  });

  group('resposta interrompida', () {
    test('não ressuscita conversa apagada no meio da resposta', () async {
      final conversas = await abrir();
      final conversa = await conversas.novaConversa(
        personaSpurgeon.id,
        titulo: 'Pergunta',
      );
      await conversas.limparConversa(personaSpurgeon.id, conversa.id);

      // A resposta que ainda voava quando a conversa foi apagada chegou
      // depois. A lápide manda: ela não volta.
      await conversas.registrarMensagem(
        personaSpurgeon.id,
        conversa.id,
        mensagem('r1', Mensagem.papelAssistente, 'resposta atrasada', agora),
      );

      expect(conversas.conversasDe(personaSpurgeon.id), isEmpty);
    });

    test('marcarRespondidas limpa só as pendentes', () async {
      final conversas = await abrir();
      final conversa = await conversas.novaConversa(
        personaSpurgeon.id,
        titulo: 'Pergunta',
      );
      await conversas.registrarMensagem(
        personaSpurgeon.id,
        conversa.id,
        const Mensagem(
          id: 'p1',
          papel: Mensagem.papelUsuario,
          texto: 'Pergunta',
          momento: 100,
          pendente: true,
        ),
      );
      await conversas.marcarRespondidas(personaSpurgeon.id, conversa.id);

      final mensagens = conversas.mensagensDe(personaSpurgeon.id, conversa.id);
      expect(mensagens.single.pendente, isFalse);
      expect(mensagens.single.texto, 'Pergunta');
    });
  });

  group('robustez', () {
    test('histórico corrompido abre vazio, sem quebrar o app', () async {
      final conversas = await abrir(guardado: {'conversas': 'isto não é json'});
      expect(conversas.conversasDe(personaFelipe.id), isEmpty);

      await conversas.novaConversa(personaFelipe.id, titulo: 'Nova');
      expect(conversas.conversasDe(personaFelipe.id), hasLength(1));
    });

    test('cópia remota ilegível deixa o histórico local intacto', () async {
      final conversas = await comConversaViva();
      await conversas.fundirConversas('também não é json');

      expect(conversas.conversasDe(personaFelipe.id), hasLength(1));
    });

    test('entrada sem id é ignorada em vez de virar conversa sem id', () async {
      final conversas = await abrir();
      await conversas.fundirConversas(
        json.encode({
          personaFelipe.id: {
            '': {'id': '', 'mensagens': []},
          },
        }),
      );
      expect(conversas.conversasDe(personaFelipe.id), isEmpty);
    });

    test('id repetido não duplica mensagem na fusão', () async {
      final conversas = await comConversaViva();
      await conversas.fundirConversas(conversas.serializarConversas());

      final conversa = conversas.conversasDe(personaFelipe.id).single;
      expect(conversa.mensagens.map((m) => m.id), ['a1']);
    });

    test('o teto corta o começo e marca a conversa como cortada', () async {
      final conversas = await abrir();
      final conversa = await conversas.novaConversa(
        personaFelipe.id,
        titulo: 'Pergunta',
      );
      for (var i = 0; i < Conversas.maxMensagensPorConversa + 5; i++) {
        await conversas.registrarMensagem(
          personaFelipe.id,
          conversa.id,
          mensagem('m$i', Mensagem.papelUsuario, 'fala $i', agora + i),
        );
      }

      final cortada = conversas.conversasDe(personaFelipe.id).single;
      expect(cortada.cortada, isTrue);
      expect(cortada.mensagens, hasLength(Conversas.maxMensagensPorConversa));
      expect(cortada.mensagens.first.id, 'm5');
    });
  });
}
