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
}
