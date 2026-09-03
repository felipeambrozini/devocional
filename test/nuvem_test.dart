import 'dart:convert';

import 'package:felipe_ambrozini/data/estado.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/nuvem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Deixa o `Timer(Duration.zero)` da [Sincronia] disparar. Duas voltas do
  /// laço de eventos: uma para o Timer chamar `_enviar`, outra para o `await`
  /// de dentro dele (a closure `empurrar`) completar.
  Future<void> assentar() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('Sincronia', () {
    test(
      'mudar um favorito envia uma vez, com o texto de exportar()',
      () async {
        final estado = await Estado.abrir();
        var envios = 0;
        String? enviado;
        final sincronia = Sincronia(
          estado: estado,
          puxar: () async => null,
          empurrar: (copia) async {
            envios++;
            enviado = copia;
          },
          atraso: Duration.zero,
        );
        await sincronia.comecar();

        await estado.alternarFavorito('joao', 3, 16);
        await assentar();

        expect(envios, 1);
        expect(enviado, estado.exportar());
      },
    );

    test('mudar tema ou escala não envia nada', () async {
      final estado = await Estado.abrir();
      var envios = 0;
      final sincronia = Sincronia(
        estado: estado,
        // Conta em dia: com ela vazia, o próprio comecar() já subiria o que
        // só existe neste aparelho (ver 'plano que já existia no aparelho'
        // mais abaixo), e o envio a medir aqui não seria o do tema.
        puxar: () async => estado.exportar(),
        empurrar: (_) async => envios++,
        atraso: Duration.zero,
      );
      await sincronia.comecar();

      await estado.definirModoDoTema(ModoDoTema.escuro);
      await estado.definirEscalaDeLeitura(1.2);
      await assentar();

      expect(
        envios,
        0,
        reason: 'preferência de aparelho não entra em exportar()',
      );
    });

    test('comecar() funde a cópia remota sem apagar a nota local', () async {
      final estado = await Estado.abrir();
      await estado.definirNota('joao', 3, 16, 'nota daqui');

      final remota = await () async {
        SharedPreferences.setMockInitialValues({});
        final outro = await Estado.abrir();
        await outro.alternarFavorito('joao', 3, 16);
        await outro.alternarLido('04-07');
        return outro.exportar();
      }();

      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => remota,
        empurrar: (_) async {},
        atraso: Duration.zero,
      );
      await sincronia.comecar();

      expect(
        estado.marcacaoDe('joao', 3, 16)?.nota,
        'nota daqui',
        reason: 'a nota local não pode ser apagada por um favorito sem nota',
      );
      expect(estado.foiLido('04-07'), isTrue);
    });

    test(
      'o eco de importar() termina: sem novidade não envia, com novidade envia uma vez',
      () async {
        final estado = await Estado.abrir();
        await estado.alternarLido('01-01');
        final copiaIgual = estado.exportar();

        var envios = 0;
        final semNovidade = Sincronia(
          estado: estado,
          puxar: () async => copiaIgual,
          empurrar: (_) async => envios++,
          atraso: Duration.zero,
        );
        await semNovidade.comecar();
        await assentar();
        expect(
          envios,
          0,
          reason:
              'importar() não trouxe nada novo, e sem isso o notifyListeners do próprio importar viraria um envio',
        );
        // Sem isto, o ouvinte de cima continua registrado no mesmo `estado` e
        // dispara de novo quando a segunda Sincronia importar() logo abaixo —
        // exatamente o que `Nuvem` evita ao chamar `_sincronia?.parar()` antes
        // de criar a próxima, em cada troca de login.
        semNovidade.parar();

        final comNovidade = await () async {
          SharedPreferences.setMockInitialValues({});
          final outro = await Estado.abrir();
          await outro.alternarLido('25-12');
          return outro.exportar();
        }();
        final sincronia = Sincronia(
          estado: estado,
          puxar: () async => comNovidade,
          empurrar: (_) async => envios++,
          atraso: Duration.zero,
        );
        await sincronia.comecar();
        await assentar();
        expect(
          envios,
          1,
          reason: 'importar() fundiu um dia novo; deve subir, mas só uma vez',
        );
      },
    );

    test('puxar devolvendo lixo não derruba o estado local', () async {
      final estado = await Estado.abrir();
      await estado.alternarLido('01-01');

      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => '{"versao": 99}',
        empurrar: (_) async {},
        atraso: Duration.zero,
      );
      await sincronia.comecar();

      expect(
        estado.diasLidos,
        1,
        reason: 'cópia remota ilegível é engolida, local continua intacto',
      );
    });

    test(
      'empurrar que falha não desiste: a próxima mudança tenta de novo',
      () async {
        final estado = await Estado.abrir();
        var tentativas = 0;
        final sincronia = Sincronia(
          estado: estado,
          puxar: () async => null,
          empurrar: (_) async {
            tentativas++;
            if (tentativas == 1) throw Exception('sem rede');
          },
          atraso: Duration.zero,
        );
        await sincronia.comecar();

        await estado.alternarFavorito('joao', 3, 16);
        await assentar();
        expect(tentativas, 1);

        await estado.alternarFavorito('romanos', 8, 28);
        await assentar();
        expect(tentativas, 2);
      },
    );

    test('despejar() envia agora o que ainda aguardava o debounce', () async {
      final estado = await Estado.abrir();
      var envios = 0;
      String? enviado;
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => null,
        empurrar: (copia) async {
          envios++;
          enviado = copia;
        },
        // Atraso longo de propósito: nada dispara sem o despejo.
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      await estado.alternarFavorito('joao', 3, 16);
      expect(envios, 0, reason: 'ainda dentro do debounce');

      await sincronia.despejar();
      expect(envios, 1);
      expect(enviado, estado.exportar());
    });

    test('despejar() sem pendência não envia nada', () async {
      final estado = await Estado.abrir();
      var envios = 0;
      final sincronia = Sincronia(
        estado: estado,
        // Conta em dia: nada para o comecar() deixar pendente.
        puxar: () async => estado.exportar(),
        empurrar: (_) async => envios++,
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      await sincronia.despejar();
      expect(envios, 0);
    });
  });

  group('Sincronia de conversas', () {
    Mensagem mensagem(String id, String papel, String texto, int momento) =>
        Mensagem(id: id, papel: papel, texto: texto, momento: momento);

    test(
      'mensagem nova sobe uma vez, com o texto de serializarConversas()',
      () async {
        final estado = await Estado.abrir();
        final c = await estado.novaConversa('spurgeon', titulo: 'Ola');
        var envios = 0;
        String? enviado;
        final sincronia = Sincronia(
          estado: estado,
          serializar: estado.serializarConversas,
          fundir: estado.fundirConversas,
          puxar: () async => null,
          empurrar: (copia) async {
            envios++;
            enviado = copia;
          },
          atraso: Duration.zero,
        );
        await sincronia.comecar();

        await estado.registrarMensagem(
          'spurgeon',
          c.id,
          mensagem('a1', 'user', 'Ola', 1),
        );
        await assentar();

        expect(envios, 1);
        expect(enviado, estado.serializarConversas());
      },
    );

    test('mudar tema ou escala não sobe conversa nenhuma', () async {
      final estado = await Estado.abrir();
      var envios = 0;
      final sincronia = Sincronia(
        estado: estado,
        serializar: estado.serializarConversas,
        fundir: estado.fundirConversas,
        // Conta em dia, pela mesma razão do teste de tema lá em cima.
        puxar: () async => estado.serializarConversas(),
        empurrar: (_) async => envios++,
        atraso: Duration.zero,
      );
      await sincronia.comecar();

      await estado.definirModoDoTema(ModoDoTema.escuro);
      await assentar();

      expect(envios, 0, reason: 'preferência de aparelho não é conversa');
    });

    test('comecar() funde o histórico remoto sem apagar o local', () async {
      final estado = await Estado.abrir();
      final c = await estado.novaConversa('spurgeon', titulo: 'daqui');
      await estado.registrarMensagem(
        'spurgeon',
        c.id,
        mensagem('local', 'user', 'daqui', 1),
      );
      final remota = json.encode({
        'spurgeon': {
          c.id: {
            'id': c.id,
            'titulo': 'daqui',
            'momento': 2,
            'mensagens': [
              {
                'id': 'remota',
                'papel': 'assistant',
                'texto': 'de la',
                'momento': 2,
              },
            ],
          },
        },
      });

      final sincronia = Sincronia(
        estado: estado,
        serializar: estado.serializarConversas,
        fundir: estado.fundirConversas,
        puxar: () async => remota,
        empurrar: (_) async {},
        atraso: Duration.zero,
      );
      await sincronia.comecar();

      expect(
        estado.mensagensDe('spurgeon', c.id).map((m) => m.id),
        ['local', 'remota'],
        reason: 'fundir une por id, na ordem do momento',
      );
    });

    test('apagar conversa sobe a lápide para a nuvem', () async {
      final estado = await Estado.abrir();
      final c = await estado.novaConversa('spurgeon', titulo: 'Ola');
      var envios = 0;
      String? enviado;
      final sincronia = Sincronia(
        estado: estado,
        serializar: estado.serializarConversas,
        fundir: estado.fundirConversas,
        puxar: () async => null,
        empurrar: (copia) async {
          envios++;
          enviado = copia;
        },
        atraso: Duration.zero,
      );
      await sincronia.comecar();

      await estado.registrarMensagem(
        'spurgeon',
        c.id,
        mensagem('a1', 'user', 'Ola', 1),
      );
      await assentar();
      expect(envios, 1);

      await estado.limparConversa('spurgeon', c.id);
      await assentar();

      expect(
        envios,
        2,
        reason: 'a exclusão é uma mudança e precisa subir como tal',
      );
      final mapa = json.decode(enviado!) as Map<String, dynamic>;
      expect(
        mapa.containsKey('spurgeon'),
        isFalse,
        reason: 'o histórico não sobe mais, só a lápide',
      );
      expect(
        (mapa['apagadas'] as Map)[c.id],
        isA<int>(),
        reason: 'sem a lápide, o outro aparelho ressuscitaria a conversa',
      );
    });
  });

  group('Sincronia de planos', () {
    test(
      'plano que já existia no aparelho sobe no primeiro login, mesmo com a nuvem vazia',
      () async {
        final estado = await Estado.abrir();
        await estado.criarPlano(
          titulo: 'Gênesis em 10 dias',
          livros: ['genesis'],
          dias: 10,
        );

        var envios = 0;
        String? enviado;
        final sincronia = Sincronia(
          estado: estado,
          serializar: estado.serializarPlanos,
          fundir: estado.fundirPlanos,
          puxar: () async => null,
          empurrar: (copia) async {
            envios++;
            enviado = copia;
          },
          atraso: Duration.zero,
        );
        await sincronia.comecar();
        await assentar();

        expect(
          envios,
          1,
          reason:
              'sem isto o plano criado antes de entrar na conta nunca sobe, e a web nunca o vê',
        );
        expect(enviado, estado.serializarPlanos());
      },
    );

    test('plano que só existe na conta aparece neste aparelho', () async {
      final remota = await () async {
        SharedPreferences.setMockInitialValues({});
        final outro = await Estado.abrir();
        final plano = await outro.criarPlano(
          titulo: 'Salmos em 30 dias',
          livros: ['salmos'],
          dias: 30,
        );
        await outro.alternarLidoNoPlano(plano.id, 1);
        return outro.serializarPlanos();
      }();

      SharedPreferences.setMockInitialValues({});
      final estado = await Estado.abrir();
      final sincronia = Sincronia(
        estado: estado,
        serializar: estado.serializarPlanos,
        fundir: estado.fundirPlanos,
        puxar: () async => remota,
        empurrar: (_) async {},
        atraso: Duration.zero,
      );
      await sincronia.comecar();

      expect(
        estado.planosDoUsuario.map((p) => p.titulo),
        ['Salmos em 30 dias'],
        reason: 'é assim que o plano criado no celular chega à web',
      );
      expect(estado.diasLidosDoPlano(estado.planosDoUsuario.first.id), 1);
    });

    test(
      'conta em dia não vira escrita, mesmo com as chaves em outra ordem',
      () async {
        final estado = await Estado.abrir();
        await estado.criarPlano(
          titulo: 'Gênesis em 10 dias',
          livros: ['genesis'],
          dias: 10,
        );

        var envios = 0;
        final sincronia = Sincronia(
          estado: estado,
          serializar: estado.serializarPlanos,
          fundir: estado.fundirPlanos,
          // O Firestore devolve os campos de um mapa em outra ordem que a de
          // quem gravou; comparar as strings acusaria diferença e mandaria
          // uma escrita à toa a cada entrada na conta.
          puxar: () async => _comChavesOrdenadas(estado.serializarPlanos()),
          empurrar: (_) async => envios++,
          atraso: Duration.zero,
        );
        await sincronia.comecar();
        await assentar();

        expect(envios, 0);
      },
    );
  });
}

/// A mesma cópia com as chaves de todo mapa em ordem alfabética — como o
/// Firestore devolve o que guardou.
String _comChavesOrdenadas(String copia) =>
    json.encode(_ordenar(json.decode(copia)));

dynamic _ordenar(dynamic valor) => switch (valor) {
  Map<String, dynamic> mapa => {
    for (final chave in mapa.keys.toList()..sort()) chave: _ordenar(mapa[chave]),
  },
  List lista => [for (final item in lista) _ordenar(item)],
  _ => valor,
};
