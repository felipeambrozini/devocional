import 'package:devocional/dados/dia_da_leitura.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:devocional/funcoes/abrir_na_biblia.dart';
import 'package:flutter_test/flutter_test.dart';

const _devocional = ItemDeDevocional(
  tipo: TipoDeDevocional.manha,
  chaveDoDia: '24-11',
);

ItemDeCapitulo _capitulos(String livro, int de, int ate) =>
    ItemDeCapitulo(Faixa(livro: livro, deCapitulo: de, ateCapitulo: ate));

/// O que a rota `/ler` faz: lê os parâmetros da URL montada por
/// `caminhoNaBiblia`.
DiaDaLeitura? _pelaUrl(String caminho) =>
    DiaDaLeitura.doParametros(Uri.parse(caminho).queryParameters);

void main() {
  group('capitulosDosItens', () {
    test('lista vazia não tem capítulo nenhum', () {
      expect(DiaDaLeitura.capitulosDosItens([]), isNull);
    });

    test('faixa de vários capítulos abre capítulo a capítulo', () {
      expect(DiaDaLeitura.capitulosDosItens([_capitulos('genesis', 1, 3)]), [
        'genesis.1',
        'genesis.2',
        'genesis.3',
      ]);
    });

    test('faixa de um capítulo só vira um capítulo', () {
      expect(DiaDaLeitura.capitulosDosItens([_capitulos('judas', 1, 1)]), [
        'judas.1',
      ]);
    });

    test('várias faixas seguem a ordem da leitura', () {
      expect(
        DiaDaLeitura.capitulosDosItens([
          _capitulos('genesis', 1, 2),
          _capitulos('salmos', 1, 1),
        ]),
        ['genesis.1', 'genesis.2', 'salmos.1'],
      );
    });

    test('capítulo repetido entre faixas entra uma vez só', () {
      expect(
        DiaDaLeitura.capitulosDosItens([
          _capitulos('joao', 1, 2),
          _capitulos('joao', 2, 3),
        ]),
        ['joao.1', 'joao.2', 'joao.3'],
      );
    });

    test('devocional no fim dá nulo', () {
      expect(
        DiaDaLeitura.capitulosDosItens([_capitulos('joao', 1, 1), _devocional]),
        isNull,
      );
    });

    test('devocional no começo dá nulo', () {
      expect(
        DiaDaLeitura.capitulosDosItens([_devocional, _capitulos('joao', 1, 1)]),
        isNull,
      );
    });

    test('devocional no meio dá nulo', () {
      expect(
        DiaDaLeitura.capitulosDosItens([
          _capitulos('joao', 1, 1),
          _devocional,
          _capitulos('salmos', 1, 1),
        ]),
        isNull,
      );
    });

    test('só devocional dá nulo', () {
      expect(DiaDaLeitura.capitulosDosItens([_devocional]), isNull);
    });
  });

  group('doCronograma e doPlano', () {
    test(
      'o cronograma guarda a chave, os capítulos e a chave do progresso',
      () {
        final dia = DiaDaLeitura.doCronograma('2026-11-24', [
          _capitulos('salmos', 1, 2),
        ])!;
        expect(dia.chave, '2026-11-24');
        expect(dia.capitulos, ['salmos.1', 'salmos.2']);
        expect(dia.chaveDoProgresso, 'cronograma:2026-11-24');
      },
    );

    test('o plano guarda o id, o número, os capítulos e a chave', () {
      final dia = DiaDaLeitura.doPlano('abc', 7, [_capitulos('joao', 3, 5)])!;
      expect(dia.planoId, 'abc');
      expect(dia.numero, 7);
      expect(dia.capitulos, ['joao.3', 'joao.4', 'joao.5']);
      expect(dia.chaveDoProgresso, 'plano:abc:7');
    });

    test('dia vazio ou com devocional devolve nulo', () {
      expect(DiaDaLeitura.doCronograma('2026-11-24', []), isNull);
      expect(
        DiaDaLeitura.doCronograma('2026-11-24', [
          _capitulos('joao', 1, 1),
          _devocional,
        ]),
        isNull,
      );
      expect(
        DiaDaLeitura.doCronograma('2026-11-24', [
          _devocional,
          _capitulos('joao', 1, 1),
        ]),
        isNull,
      );
      expect(DiaDaLeitura.doPlano('abc', 1, []), isNull);
      expect(
        DiaDaLeitura.doPlano('abc', 1, [_capitulos('joao', 1, 1), _devocional]),
        isNull,
      );
    });
  });

  group('temCapitulo', () {
    final dia = DiaDaLeitura.doCronograma('2026-11-24', [
      _capitulos('joao', 1, 3),
    ])!;

    test('todo capítulo do dia faz parte dele', () {
      for (var n = 1; n <= 3; n++) {
        expect(dia.temCapitulo('joao', n), isTrue, reason: 'joao $n');
      }
    });

    test('capítulo fora da faixa não faz parte', () {
      expect(dia.temCapitulo('joao', 0), isFalse);
      expect(dia.temCapitulo('joao', 4), isFalse);
    });

    test('o mesmo número em outro livro não faz parte', () {
      expect(dia.temCapitulo('marcos', 2), isFalse);
    });

    test('capitulo monta o formato livro.numero', () {
      expect(DiaDaLeitura.capitulo('genesis', 12), 'genesis.12');
    });
  });

  group('ida e volta pela URL', () {
    test('o dia do cronograma volta igual', () {
      final dia = DiaDaLeitura.doCronograma('2026-11-24', [
        _capitulos('joao', 1, 3),
      ])!;
      final volta = _pelaUrl(caminhoNaBiblia('joao', 1, dia: dia));
      expect(volta, isA<DiaDoCronograma>());
      final cronograma = volta as DiaDoCronograma;
      expect(cronograma.chave, '2026-11-24');
      expect(cronograma.capitulos, ['joao.1', 'joao.2', 'joao.3']);
    });

    test('o dia com vários capítulos vai na URL separado por vírgula', () {
      final dia = DiaDaLeitura.doCronograma('2026-11-24', [
        _capitulos('genesis', 1, 2),
        _capitulos('salmos', 1, 1),
      ])!;
      final caminho = caminhoNaBiblia('genesis', 1, dia: dia);
      expect(
        Uri.parse(caminho).queryParameters['capitulos'],
        'genesis.1,genesis.2,salmos.1',
      );
      expect(_pelaUrl(caminho)!.capitulos, [
        'genesis.1',
        'genesis.2',
        'salmos.1',
      ]);
    });

    test('o dia do plano volta igual', () {
      final dia = DiaDaLeitura.doPlano('abc123', 12, [
        _capitulos('salmos', 119, 119),
      ])!;
      final volta = _pelaUrl(caminhoNaBiblia('salmos', 119, dia: dia));
      expect(volta, isA<DiaDePlano>());
      final plano = volta as DiaDePlano;
      expect(plano.planoId, 'abc123');
      expect(plano.numero, 12);
      expect(plano.capitulos, ['salmos.119']);
    });

    test('id de plano com caracteres especiais sobrevive à URL', () {
      const id = 'a b&c=d?e#f/ç+1%2F';
      final dia = DiaDaLeitura.doPlano(id, 2, [_capitulos('joao', 1, 1)])!;
      final caminho = caminhoNaBiblia('joao', 1, dia: dia);
      // Codificado: nenhum separador de query vaza do id.
      expect(caminho, isNot(contains('c=d')));
      expect(caminho, isNot(contains('#')));
      expect((_pelaUrl(caminho) as DiaDePlano).planoId, id);
    });

    test('os parâmetros convivem com os versículos a destacar', () {
      final dia = DiaDaLeitura.doCronograma('2026-11-24', [
        _capitulos('salmos', 119, 119),
      ])!;
      final caminho = caminhoNaBiblia(
        'salmos',
        119,
        destacar: (1, 56),
        dia: dia,
      );
      final uri = Uri.parse(caminho);
      expect(uri.path, '/ler/salmos/119');
      expect(uri.queryParameters['versiculos'], '1-56');
      expect(_pelaUrl(caminho), isA<DiaDoCronograma>());
      expect(
        leituraDoCaminho('salmos', '119', uri.queryParameters['versiculos']),
        ('salmos', 119, (1, 56)),
      );
    });

    test('sem dia o caminho continua igual ao de antes', () {
      expect(caminhoNaBiblia('joao', 3), '/ler/joao/3');
      expect(_pelaUrl('/ler/joao/3'), isNull);
      expect(_pelaUrl('/ler/joao/3?versiculos=16'), isNull);
    });
  });

  group('doParametros com parâmetros tortos', () {
    test('mapa vazio dá nulo', () {
      expect(DiaDaLeitura.doParametros({}), isNull);
    });

    test('sem os capítulos, dá nulo', () {
      expect(
        DiaDaLeitura.doParametros({'diaDoCronograma': '2026-11-24'}),
        isNull,
      );
      expect(
        DiaDaLeitura.doParametros({'plano': 'abc', 'diaDoPlano': '3'}),
        isNull,
      );
    });

    test('capítulos malformados dão nulo', () {
      for (final capitulos in [
        '',
        'joao',
        'joao.',
        '.3',
        'joao.x',
        'joao.0',
        'joao.-1',
        'joao.3.1',
        'joao.1,',
        'joao.1,joao',
        'joao.1,,joao.2',
      ]) {
        expect(
          DiaDaLeitura.doParametros({
            'diaDoCronograma': '2026-11-24',
            'capitulos': capitulos,
          }),
          isNull,
          reason: 'capitulos "$capitulos"',
        );
      }
    });

    test('só os capítulos, sem dia nenhum, dá nulo', () {
      expect(DiaDaLeitura.doParametros({'capitulos': 'joao.3'}), isNull);
    });

    test('cronograma com a chave vazia dá nulo', () {
      expect(
        DiaDaLeitura.doParametros({
          'diaDoCronograma': '',
          'capitulos': 'joao.3',
        }),
        isNull,
      );
    });

    test('plano sem id, sem número ou com número torto dá nulo', () {
      for (final parametros in [
        {'diaDoPlano': '3', 'capitulos': 'joao.3'},
        {'plano': '', 'diaDoPlano': '3', 'capitulos': 'joao.3'},
        {'plano': 'abc', 'capitulos': 'joao.3'},
        {'plano': 'abc', 'diaDoPlano': 'x', 'capitulos': 'joao.3'},
        {'plano': 'abc', 'diaDoPlano': '0', 'capitulos': 'joao.3'},
        {'plano': 'abc', 'diaDoPlano': '-2', 'capitulos': 'joao.3'},
      ]) {
        expect(
          DiaDaLeitura.doParametros(parametros),
          isNull,
          reason: '$parametros',
        );
      }
    });

    test('o limite do intervalo vale: capítulo 1 e dia 1 são aceitos', () {
      final dia = DiaDaLeitura.doParametros({
        'plano': 'abc',
        'diaDoPlano': '1',
        'capitulos': 'joao.1',
      });
      expect(dia, isA<DiaDePlano>());
      expect(dia!.capitulos, ['joao.1']);
    });

    test('com os dois tipos de dia, o cronograma vence', () {
      final dia = DiaDaLeitura.doParametros({
        'diaDoCronograma': '2026-11-24',
        'plano': 'abc',
        'diaDoPlano': '3',
        'capitulos': 'joao.3',
      });
      expect(dia, isA<DiaDoCronograma>());
    });
  });

  group('doParametros com o fim da versão anterior', () {
    test('o fim vira a lista de um capítulo só', () {
      final dia = DiaDaLeitura.doParametros({
        'diaDoCronograma': '2026-11-24',
        'fim': 'joao.3',
      });
      expect(dia, isA<DiaDoCronograma>());
      expect(dia!.capitulos, ['joao.3']);
    });

    test('vale também para o plano', () {
      final dia = DiaDaLeitura.doParametros({
        'plano': 'abc',
        'diaDoPlano': '2',
        'fim': 'salmos.23',
      });
      expect(dia, isA<DiaDePlano>());
      expect(dia!.capitulos, ['salmos.23']);
    });

    test('capitulos vence o fim quando vêm os dois', () {
      final dia = DiaDaLeitura.doParametros({
        'diaDoCronograma': '2026-11-24',
        'capitulos': 'joao.1,joao.2',
        'fim': 'joao.9',
      });
      expect(dia!.capitulos, ['joao.1', 'joao.2']);
    });

    test('fim torto dá nulo', () {
      expect(
        DiaDaLeitura.doParametros({
          'diaDoCronograma': '2026-11-24',
          'fim': 'joao',
        }),
        isNull,
      );
    });
  });
}
