import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/estado.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Reabre o estado a partir do mesmo armazenamento, provando que o dado
  /// sobreviveu e não estava só na memória.
  Future<Estado> reabrir() async => Estado(await SharedPreferences.getInstance());

  group('progresso do cronograma', () {
    test('marca, desmarca e persiste', () async {
      final estado = await Estado.abrir();
      expect(estado.diasLidos, 0);
      expect(estado.foiLido('01-01'), isFalse);

      await estado.alternarLido('01-01');
      await estado.alternarLido('12-25');
      expect(estado.diasLidos, 2);
      expect(estado.foiLido('01-01'), isTrue);

      expect((await reabrir()).diasLidos, 2);

      await estado.alternarLido('01-01');
      expect(estado.foiLido('01-01'), isFalse);
      expect((await reabrir()).diasLidos, 1);
    });

    test('progresso e fracao de 365 dias', () async {
      final estado = await Estado.abrir();
      expect(estado.progressoDoAno, 0);
      await estado.alternarLido('01-01');
      expect(estado.progressoDoAno, closeTo(1 / 365, 1e-9));
    });
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

    test('as duas versoes do mesmo versiculo sao marcacoes distintas', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito(Versao.bkj, 'joao', 3, 16);
      expect(estado.ehFavorito(Versao.nvt, 'joao', 3, 16), isFalse);
      await estado.alternarFavorito(Versao.nvt, 'joao', 3, 16);
      expect(estado.marcacoes.length, 2);
    });

    test('nota sobrevive ao ciclo de gravacao', () async {
      final estado = await Estado.abrir();
      await estado.definirNota(Versao.bkj, 'salmos', 23, 1, '  Pastor e provedor.  ');

      final relido = await reabrir();
      final marcacao = relido.marcacaoDe(Versao.bkj, 'salmos', 23, 1);
      expect(marcacao, isNotNull);
      // A nota e gravada sem espaco em volta.
      expect(marcacao!.nota, 'Pastor e provedor.');
      expect(relido.comNota.length, 1);
    });

    test('desfavoritar nao apaga uma nota escrita', () async {
      final estado = await Estado.abrir();
      await estado.definirNota(Versao.bkj, 'salmos', 23, 1, 'Anotacao importante');

      // O toque no favorito nao pode destruir texto que o usuario escreveu.
      await estado.alternarFavorito(Versao.bkj, 'salmos', 23, 1);
      expect(estado.marcacaoDe(Versao.bkj, 'salmos', 23, 1)?.nota,
          'Anotacao importante');
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
    test('versao preferida persiste e comeca em BKJ', () async {
      final estado = await Estado.abrir();
      expect(estado.versao, Versao.bkj);
      await estado.definirVersao(Versao.nvt);
      expect((await reabrir()).versao, Versao.nvt);
    });

    test('ultima leitura persiste', () async {
      final estado = await Estado.abrir();
      expect(estado.ultimaLeitura, isNull);
      await estado.registrarLeitura('romanos', 8);
      expect((await reabrir()).ultimaLeitura, ('romanos', 8));
    });

    test('ultima leitura invalida e ignorada em vez de derrubar o app', () async {
      SharedPreferences.setMockInitialValues({'ultima_leitura': 'livro_que_nao_existe/9'});
      expect((await Estado.abrir()).ultimaLeitura, isNull);
    });

    test('marcacoes corrompidas nao impedem o app de abrir', () async {
      SharedPreferences.setMockInitialValues({'marcacoes': 'isto nao e json'});
      final estado = await Estado.abrir();
      expect(estado.marcacoes, isEmpty);
    });
  });
}
