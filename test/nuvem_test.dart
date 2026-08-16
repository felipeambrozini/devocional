import 'dart:convert';

import 'package:felipe_ambrozini/data/canon.dart';
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

        await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
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
        puxar: () async => null,
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
      await estado.definirNota(Versao.bkj, 'joao', 3, 16, 'nota daqui');

      final remota = await () async {
        SharedPreferences.setMockInitialValues({});
        final outro = await Estado.abrir();
        await outro.alternarFavorito(Versao.bkj, 'joao', 3, 16);
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
        estado.marcacaoDe(Versao.bkj, 'joao', 3, 16)?.nota,
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
      'empurrar que falha marca falhouAoEnviar, e a próxima mudança tenta de novo',
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

        await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
        await assentar();
        expect(sincronia.falhouAoEnviar, isTrue);

        await estado.alternarFavorito(Versao.bkj, 'romanos', 8, 28);
        await assentar();
        expect(tentativas, 2);
        expect(sincronia.falhouAoEnviar, isFalse);
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

      await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
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
        puxar: () async => null,
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
        puxar: () async => null,
        empurrar: (_) async => envios++,
        atraso: Duration.zero,
      );
      await sincronia.comecar();

      await estado.definirModoDoTema(ModoDoTema.escuro);
      await assentar();

      expect(
        envios,
        0,
        reason: 'preferência de aparelho não é conversa',
      );
    });

    test('comecar() funde o histórico remoto sem apagar o local', () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem(
        'spurgeon',
        mensagem('local', 'user', 'daqui', 1),
      );
      final remota = json.encode({
        'spurgeon': [
          {'id': 'remota', 'papel': 'assistant', 'texto': 'de la', 'momento': 2},
        ],
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
        estado.mensagensDe('spurgeon').map((m) => m.id),
        ['local', 'remota'],
        reason: 'fundir une por id, na ordem do momento',
      );
    });

    test('apagar conversa sobe a lápide para a nuvem', () async {
      final estado = await Estado.abrir();
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
        mensagem('a1', 'user', 'Ola', 1),
      );
      await assentar();
      expect(envios, 1);

      await estado.limparConversa('spurgeon');
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
        (mapa['apagadas'] as Map)['spurgeon'],
        isA<int>(),
        reason: 'sem a lápide, o outro aparelho ressuscitaria a conversa',
      );
    });
  });
}
