import 'dart:convert';

import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Reabre o estado a partir do mesmo armazenamento, provando que o dado
  /// sobreviveu e não estava só na memória.
  Future<Estado> reabrir() async =>
      Estado(await SharedPreferences.getInstance());

  group('progresso do cronograma', () {
    test('marca, desmarca e persiste', () async {
      final estado = await Estado.abrir();
      expect(estado.diasLidos, 0);
      expect(estado.foiLido('01-01'), isFalse);

      await estado.alternarLido('01-01');
      await estado.alternarLido('25-12');
      expect(estado.diasLidos, 2);
      expect(estado.foiLido('01-01'), isTrue);

      expect((await reabrir()).diasLidos, 2);

      await estado.alternarLido('01-01');
      expect(estado.foiLido('01-01'), isFalse);
      expect((await reabrir()).diasLidos, 1);
    });

    test('progresso e fracao do total de dias do ano', () async {
      final estado = await Estado.abrir();
      expect(estado.progressoDoAno(365), 0);
      await estado.alternarLido('01-01');
      expect(estado.progressoDoAno(365), closeTo(1 / 365, 1e-9));
      // Em ano bissexto o divisor é 366, senão marcar o ano inteiro passaria de 100%.
      expect(estado.progressoDoAno(366), closeTo(1 / 366, 1e-9));
    });

    test(
      'o ano inteiro marcado fecha em 100% em ano comum e em bissexto',
      () async {
        for (final (ano, total) in [(2027, 365), (2028, 366)]) {
          // Cada volta começa de armazenamento limpo: sem isto a segunda passagem
          // desmarcaria os dias já marcados, porque alternarLido alterna.
          SharedPreferences.setMockInitialValues({});
          final estado = await Estado.abrir();
          for (var d = 0; d < total; d++) {
            final dia = DateTime(ano, 1, 1).add(Duration(days: d));
            await estado.alternarLido(Conteudo.chaveDoDia(dia));
          }
          expect(
            estado.diasLidos,
            total,
            reason: 'ano $ano deve render $total chaves distintas',
          );
          expect(
            estado.progressoDoAno(Conteudo.diasDoAno(ano)),
            closeTo(1.0, 1e-9),
            reason: 'ano $ano',
          );
        }
      },
    );
  });

  group('favoritos e notas', () {
    test('favorita, desfavorita e persiste', () async {
      final estado = await Estado.abrir();
      expect(estado.ehFavorito(Versao.bkj, 'joao', 3, 16), isFalse);

      await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
      expect(estado.ehFavorito(Versao.bkj, 'joao', 3, 16), isTrue);
      expect((await reabrir()).ehFavorito(Versao.bkj, 'joao', 3, 16), isTrue);

      await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
      expect(estado.ehFavorito(Versao.bkj, 'joao', 3, 16), isFalse);
      expect((await reabrir()).marcacoes, isEmpty);
    });

    test('nota sobrevive ao ciclo de gravacao', () async {
      final estado = await Estado.abrir();
      await estado.definirNota(
        Versao.bkj,
        'salmos',
        23,
        1,
        '  Pastor e provedor.  ',
      );

      final relido = await reabrir();
      final marcacao = relido.marcacaoDe(Versao.bkj, 'salmos', 23, 1);
      expect(marcacao, isNotNull);
      // A nota e gravada sem espaco em volta.
      expect(marcacao!.nota, 'Pastor e provedor.');
      expect(relido.comNota.length, 1);
    });

    test('desfavoritar nao apaga uma nota escrita', () async {
      final estado = await Estado.abrir();
      await estado.definirNota(
        Versao.bkj,
        'salmos',
        23,
        1,
        'Anotacao importante',
      );

      // O toque no favorito nao pode destruir texto que o usuario escreveu.
      await estado.alternarFavorito(Versao.bkj, 'salmos', 23, 1);
      expect(
        estado.marcacaoDe(Versao.bkj, 'salmos', 23, 1)?.nota,
        'Anotacao importante',
      );
    });

    test('nota vazia limpa o texto mas conserva o favorito', () async {
      final estado = await Estado.abrir();
      await estado.definirNota(Versao.bkj, 'salmos', 23, 1, 'temporaria');
      await estado.definirNota(Versao.bkj, 'salmos', 23, 1, '   ');
      expect(estado.ehFavorito(Versao.bkj, 'salmos', 23, 1), isTrue);
      expect(estado.comNota, isEmpty);
    });

    test('marcacoes saem em ordem canonica, nao por ordem de clique', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito(Versao.bkj, 'apocalipse', 1, 1);
      await estado.alternarFavorito(Versao.bkj, 'genesis', 1, 1);
      await estado.alternarFavorito(Versao.bkj, 'salmos', 23, 6);
      await estado.alternarFavorito(Versao.bkj, 'salmos', 23, 1);

      expect(
        estado.marcacoes.map((m) => '${m.livro}:${m.capitulo}:${m.versiculo}'),
        ['genesis:1:1', 'salmos:23:1', 'salmos:23:6', 'apocalipse:1:1'],
      );
    });

    test('remover apaga a marcacao inteira', () async {
      final estado = await Estado.abrir();
      await estado.definirNota(Versao.bkj, 'joao', 1, 1, 'nota');
      await estado.removerMarcacao(estado.marcacoes.single);
      expect(estado.marcacoes, isEmpty);
      expect((await reabrir()).marcacoes, isEmpty);
    });
  });

  group('preferencias', () {
    test('a traducao interna e BKJ', () async {
      final estado = await Estado.abrir();
      expect(estado.versao, Versao.bkj);
    });

    test('ultima leitura persiste', () async {
      final estado = await Estado.abrir();
      expect(estado.ultimaLeitura, isNull);
      await estado.registrarLeitura('romanos', 8);
      expect((await reabrir()).ultimaLeitura, ('romanos', 8));
    });

    test(
      'ultima leitura invalida e ignorada em vez de derrubar o app',
      () async {
        SharedPreferences.setMockInitialValues({
          'ultima_leitura': 'livro_que_nao_existe/9',
        });
        expect((await Estado.abrir()).ultimaLeitura, isNull);
      },
    );

    test('marcacoes corrompidas nao impedem o app de abrir', () async {
      SharedPreferences.setMockInitialValues({'marcacoes': 'isto nao e json'});
      final estado = await Estado.abrir();
      expect(estado.marcacoes, isEmpty);
    });
  });

  group('tamanho do texto de leitura', () {
    test('persiste, e so aceita um passo conhecido', () async {
      final estado = await Estado.abrir();
      expect(estado.escalaDeLeitura, 1.0);

      await estado.definirEscalaDeLeitura(1.3);
      expect((await reabrir()).escalaDeLeitura, 1.3);

      // Um valor fora da lista nao pode passar: deixaria o texto ilegivel e nao
      // haveria como voltar pela propria interface, que so oferece os passos.
      await estado.definirEscalaDeLeitura(9.0);
      expect(estado.escalaDeLeitura, 1.3);
    });

    test('valor gravado fora da lista volta ao padrao', () async {
      SharedPreferences.setMockInitialValues({'escala_de_leitura': 42.0});
      expect((await Estado.abrir()).escalaDeLeitura, 1.0);
    });
  });

  group('claro ou escuro', () {
    test('comeca seguindo o aparelho e persiste a escolha', () async {
      final estado = await Estado.abrir();
      expect(estado.modoDoTema, ModoDoTema.sistema);

      await estado.definirModoDoTema(ModoDoTema.claro);
      expect((await reabrir()).modoDoTema, ModoDoTema.claro);

      await estado.definirModoDoTema(ModoDoTema.escuro);
      expect((await reabrir()).modoDoTema, ModoDoTema.escuro);
    });

    test('valor desconhecido volta a seguir o aparelho', () async {
      SharedPreferences.setMockInitialValues({'modo_do_tema': 'sepia'});
      expect((await Estado.abrir()).modoDoTema, ModoDoTema.sistema);
    });
  });

  group('copia de seguranca', () {
    test('exportar e importar leva favoritos, notas e progresso', () async {
      final origem = await Estado.abrir();
      await origem.alternarFavorito(Versao.bkj, 'joao', 3, 16);
      await origem.definirNota(Versao.bkj, 'romanos', 8, 28, 'para meditar');
      await origem.alternarLido('01-01');
      await origem.alternarLido('15-03');
      final copia = origem.exportar();

      // Aparelho novo: nada gravado, so a copia.
      SharedPreferences.setMockInitialValues({});
      final destino = await Estado.abrir();
      expect(destino.marcacoes, isEmpty);

      final (marcacoes, dias) = await destino.importar(copia);
      expect(marcacoes, 2);
      expect(dias, 2);
      expect(destino.ehFavorito(Versao.bkj, 'joao', 3, 16), isTrue);
      expect(
        destino.marcacaoDe(Versao.bkj, 'romanos', 8, 28)?.nota,
        'para meditar',
      );
      expect(destino.diasLidos, 2);

      // E sobreviveu ao disco, nao ficou so na memoria.
      expect((await reabrir()).diasLidos, 2);
    });

    test('importar funde em vez de substituir, e nao apaga nota local', () async {
      final estado = await Estado.abrir();
      await estado.definirNota(Versao.bkj, 'joao', 3, 16, 'nota daqui');
      await estado.alternarLido('01-01');

      // Copia com o mesmo versiculo sem nota, mais um dia que nao existia aqui.
      final outra = await () async {
        SharedPreferences.setMockInitialValues({});
        final e = await Estado.abrir();
        await e.alternarFavorito(Versao.bkj, 'joao', 3, 16);
        await e.alternarLido('04-07');
        return e.exportar();
      }();

      final (_, dias) = await estado.importar(outra);
      expect(dias, 1, reason: 'so o dia que faltava');
      expect(estado.diasLidos, 2, reason: '01-01 continua marcado');
      expect(
        estado.marcacaoDe(Versao.bkj, 'joao', 3, 16)?.nota,
        'nota daqui',
        reason: 'a nota local nao pode ser apagada por um favorito sem nota',
      );
    });

    test('importar duas vezes nao duplica nada', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
      await estado.alternarLido('01-01');
      final copia = estado.exportar();

      await estado.importar(copia);
      final (marcacoes, dias) = await estado.importar(copia);
      expect(marcacoes, 0);
      expect(dias, 0);
      expect(estado.marcacoes.length, 1);
      expect(estado.diasLidos, 1);
    });

    test('texto que nao e copia e recusado com explicacao', () async {
      final estado = await Estado.abrir();
      expect(
        () => estado.importar('isto nao e json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => estado.importar('[1, 2, 3]'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => estado.importar('{"versao": 99}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('uma entrada quebrada nao derruba a importacao inteira', () async {
      final estado = await Estado.abrir();
      final (marcacoes, _) = await estado.importar(
        '{"versao": 1, "marcacoes": ['
        '{"livro": "joao"},'
        '{"versao": "bkj", "livro": "joao", "capitulo": 3, "versiculo": 16}'
        '], "dias_lidos": []}',
      );
      expect(marcacoes, 1);
      expect(estado.ehFavorito(Versao.bkj, 'joao', 3, 16), isTrue);
    });
  });

  group('lembretes diarios', () {
    test(
      'comeca desligado, em 6h e 18h, e persiste o que for mudado',
      () async {
        final estado = await Estado.abrir();
        expect(estado.lembretesAtivos, isFalse);
        expect(estado.minutosLembreteManha, 6 * 60);
        expect(estado.minutosLembreteNoite, 18 * 60);

        await estado.definirLembretesAtivos(true);
        await estado.definirHorariosDeLembrete(
          minutosManha: 7 * 60,
          minutosNoite: 21 * 60 + 30,
        );

        final relido = await reabrir();
        expect(relido.lembretesAtivos, isTrue);
        expect(relido.minutosLembreteManha, 7 * 60);
        expect(relido.minutosLembreteNoite, 21 * 60 + 30);
      },
    );

    test(
      'minutos fora de 0..1439 gravados por fora voltam ao padrao',
      () async {
        SharedPreferences.setMockInitialValues({
          'minutos_lembrete_manha': -1,
          'minutos_lembrete_noite': 24 * 60,
        });
        final estado = await Estado.abrir();
        expect(estado.minutosLembreteManha, 6 * 60);
        expect(estado.minutosLembreteNoite, 18 * 60);
      },
    );
  });

  group('conversas do chat', () {
    Mensagem mensagem(String id, String papel, String texto, int momento) =>
        Mensagem(id: id, papel: papel, texto: texto, momento: momento);

    test('registra por persona, persiste e limpa so a pedida', () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem(
        'spurgeon',
        mensagem('1', 'user', 'Ola', 1),
      );
      await estado.registrarMensagem(
        'spurgeon',
        mensagem('2', 'assistant', 'Paz, meu filho.', 2),
      );
      await estado.registrarMensagem(
        'felipe',
        mensagem('3', 'user', 'Bom dia', 3),
      );

      expect(estado.mensagensDe('spurgeon').length, 2);
      expect(estado.mensagensDe('felipe').single.texto, 'Bom dia');
      expect(
        (await reabrir()).mensagensDe('spurgeon').length,
        2,
        reason: 'o histórico sobrevive ao reabrir',
      );

      await estado.limparConversa('spurgeon');
      expect(estado.mensagensDe('spurgeon'), isEmpty);
      expect((await reabrir()).mensagensDe('spurgeon'), isEmpty);
      expect(
        (await reabrir()).mensagensDe('felipe').length,
        1,
        reason: 'limpar uma persona não toca na outra',
      );
    });

    test('teto de 120 mensagens por conversa, ficando com a cauda', () async {
      final estado = await Estado.abrir();
      for (var i = 0; i < 125; i++) {
        await estado.registrarMensagem(
          'spurgeon',
          mensagem('$i', 'user', 'm$i', i),
        );
      }
      final mensagens = estado.mensagensDe('spurgeon');
      expect(mensagens.length, 120);
      expect(mensagens.first.id, '5');
      expect(mensagens.last.id, '124');
    });

    test('fundir nao duplica, ordena por momento e persiste', () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem(
        'spurgeon',
        mensagem('a', 'user', 'local', 1),
      );
      final remota = json.encode({
        'spurgeon': [
          {'id': 'a', 'papel': 'user', 'texto': 'local', 'momento': 1},
          {'id': 'b', 'papel': 'assistant', 'texto': 'remota', 'momento': 3},
        ],
        'felipe': [
          {'id': 'c', 'papel': 'user', 'texto': 'outra', 'momento': 5},
        ],
      });
      await estado.fundirConversas(remota);

      expect(
        estado.mensagensDe('spurgeon').map((m) => m.id),
        ['a', 'b'],
        reason: 'a remota que já existia não duplica',
      );
      expect(estado.mensagensDe('felipe').single.id, 'c');
      expect(
        (await reabrir()).mensagensDe('spurgeon').length,
        2,
        reason: 'a fusão também persiste',
      );
    });

    test('lixo remoto e engolido sem derrubar o local', () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem(
        'spurgeon',
        mensagem('a', 'user', 'fica', 1),
      );
      await estado.fundirConversas('{"versao": 99}');
      await estado.fundirConversas('isto não é json');
      await estado.fundirConversas('{"spurgeon": "texto, não lista"}');
      expect(estado.mensagensDe('spurgeon').single.texto, 'fica');
    });

    test('pendente persiste e marcarRespondidas limpa', () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem(
        'spurgeon',
        Mensagem(
          id: '1',
          papel: 'user',
          texto: 'Fica?',
          momento: 1,
          pendente: true,
        ),
      );
      expect(estado.mensagensDe('spurgeon').single.pendente, isTrue);

      final relido = await reabrir();
      expect(
        relido.mensagensDe('spurgeon').single.pendente,
        isTrue,
        reason: 'a interrupção sobrevive ao reabrir',
      );
      await relido.marcarRespondidas('spurgeon');
      expect(relido.mensagensDe('spurgeon').single.pendente, isFalse);
      expect((await reabrir()).mensagensDe('spurgeon').single.pendente, isFalse);
    });

    test('apagar grava lápide e o remoto antigo não ressuscita', () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem('spurgeon', mensagem('1', 'user', 'oi', 1));
      await estado.limparConversa('spurgeon');
      expect(estado.mensagensDe('spurgeon'), isEmpty);

      final serializado = estado.serializarConversas();
      final mapa = json.decode(serializado) as Map<String, dynamic>;
      expect(
        mapa['apagadas'],
        isA<Map<String, dynamic>>(),
        reason: 'a exclusão viaja com o histórico para alcançar a nuvem',
      );
      expect((mapa['apagadas'] as Map)['spurgeon'], isA<int>());

      // O outro aparelho ainda tem a conversa antiga, mas a lápide é mais
      // nova: o reencontro não a ressuscita.
      final remota = json.encode({
        'spurgeon': [
          {'id': '2', 'papel': 'assistant', 'texto': 'velha', 'momento': 1},
        ],
      });
      await estado.fundirConversas(remota);
      expect(estado.mensagensDe('spurgeon'), isEmpty);
      expect((await reabrir()).mensagensDe('spurgeon'), isEmpty);
    });

    test('lápide remota mais nova apaga a conversa local', () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem('spurgeon', mensagem('1', 'user', 'oi', 1));
      final remota = json.encode({
        'spurgeon': [
          {'id': '2', 'papel': 'assistant', 'texto': 'velha', 'momento': 1},
        ],
        'apagadas': {'spurgeon': 5},
      });
      await estado.fundirConversas(remota);

      expect(estado.mensagensDe('spurgeon'), isEmpty);
      final mapa = json.decode(estado.serializarConversas())
          as Map<String, dynamic>;
      expect(
        (mapa['apagadas'] as Map)['spurgeon'],
        5,
        reason: 'a lápide mais nova das duas fica, e o reabrir não ressuscita',
      );
      expect((await reabrir()).mensagensDe('spurgeon'), isEmpty);
    });

    test('conversa que continuou em outro aparelho volta e limpa a lápide',
        () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem('spurgeon', mensagem('1', 'user', 'oi', 1));
      await estado.limparConversa('spurgeon');
      expect(estado.mensagensDe('spurgeon'), isEmpty);

      // O outro aparelho continuou a conversa depois da exclusão: as mensagens
      // dele são mais novas que a lápide, e a conversa volta inteira.
      final continuacao = DateTime.now().millisecondsSinceEpoch + 1000;
      final remota = json.encode({
        'spurgeon': [
          {
            'id': '2',
            'papel': 'user',
            'texto': 'continuo aqui',
            'momento': continuacao,
          },
        ],
      });
      await estado.fundirConversas(remota);

      expect(estado.mensagensDe('spurgeon').single.texto, 'continuo aqui');
      expect(
        estado.serializarConversas(),
        isNot(contains('apagadas')),
        reason: 'a conversa revivida não carrega mais a lápide',
      );
      expect((await reabrir()).mensagensDe('spurgeon').length, 1);
    });

    test('lápide sem mensagens vira a cópia inteira e persiste', () async {
      final estado = await Estado.abrir();
      await estado.limparConversa('spurgeon');
      final mapa = json.decode(estado.serializarConversas())
          as Map<String, dynamic>;
      expect((mapa['apagadas'] as Map)['spurgeon'], isA<int>());
      expect(
        (await reabrir()).serializarConversas(),
        contains('apagadas'),
        reason: 'apagar sem histórico também tem de alcançar a nuvem',
      );
    });

    test('lápide remota sozinha apaga a conversa local', () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem('spurgeon', mensagem('1', 'user', 'oi', 1));

      // O outro aparelho apagou e empurrou só a lápide, sem histórico.
      final remota = json.encode({'apagadas': {'spurgeon': 5}});
      await estado.fundirConversas(remota);

      expect(estado.mensagensDe('spurgeon'), isEmpty);
      final mapa = json.decode(estado.serializarConversas())
          as Map<String, dynamic>;
      expect(
        (mapa['apagadas'] as Map)['spurgeon'],
        5,
        reason: 'a exclusão chega de verdade e não volta a subir',
      );
      expect((await reabrir()).mensagensDe('spurgeon'), isEmpty);
    });

    test('lápide remota sozinha e antiga não apaga a conversa que continuou',
        () async {
      final estado = await Estado.abrir();
      await estado.registrarMensagem('spurgeon', mensagem('1', 'user', 'oi', 7));

      final remota = json.encode({'apagadas': {'spurgeon': 5}});
      await estado.fundirConversas(remota);

      expect(
        estado.mensagensDe('spurgeon').single.id,
        '1',
        reason: 'a conversa local é mais nova que a exclusão remota',
      );
    });
  });

  group('conversas corrompidas no armazenamento', () {
    test('JSON inválido não impede o app de abrir', () async {
      SharedPreferences.setMockInitialValues({
        'conversas': 'isto não é json {',
      });
      final estado = await Estado.abrir();
      expect(estado.mensagensDe('spurgeon'), isEmpty);
      expect(estado.serializarConversas(), '{}');
    });

    test('mensagem sem forma de mapa é descartada, as boas ficam', () async {
      SharedPreferences.setMockInitialValues({
        'conversas': json.encode({
          'spurgeon': [
            {'id': '1', 'papel': 'user', 'texto': 'Olá', 'momento': 1},
            'não sou um mapa',
            42,
          ],
        }),
      });
      final estado = await Estado.abrir();
      final mensagens = estado.mensagensDe('spurgeon');
      expect(mensagens, hasLength(1));
      expect(mensagens.single.texto, 'Olá');
    });

    test('lápide com valor que não é int é descartada', () async {
      SharedPreferences.setMockInitialValues({
        'conversas': json.encode({
          'apagadas': {
            'spurgeon': 'ontem',
            'felipe': 3,
          },
        }),
      });
      final estado = await Estado.abrir();
      // A lápide torta não entra; a válida continua valendo.
      final mapa = json.decode(estado.serializarConversas())
          as Map<String, dynamic>;
      final apagadas = mapa['apagadas'] as Map;
      expect(apagadas['spurgeon'], isNull);
      expect(apagadas['felipe'], 3);
    });
  });
}
