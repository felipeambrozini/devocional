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
  group('fimDosItens', () {
    test('lista vazia não tem fim', () {
      expect(DiaDaLeitura.fimDosItens([]), isNull);
    });

    test('o fim é o último capítulo da última faixa', () {
      expect(
        DiaDaLeitura.fimDosItens([
          _capitulos('genesis', 1, 3),
          _capitulos('joao', 2, 4),
        ]),
        ('joao', 4),
      );
    });

    test('faixa de um capítulo só termina nele mesmo', () {
      expect(DiaDaLeitura.fimDosItens([_capitulos('judas', 1, 1)]), (
        'judas',
        1,
      ));
    });

    test('dia que termina num devocional não tem fim a marcar', () {
      expect(
        DiaDaLeitura.fimDosItens([_capitulos('joao', 1, 1), _devocional]),
        isNull,
      );
    });

    test('devocional no começo não atrapalha: o fim é o último capítulo', () {
      expect(
        DiaDaLeitura.fimDosItens([_devocional, _capitulos('joao', 1, 1)]),
        ('joao', 1),
      );
    });
  });

  group('doCronograma e doPlano', () {
    test('o cronograma guarda a chave e o fim do dia', () {
      final dia = DiaDaLeitura.doCronograma('2026-11-24', [
        _capitulos('salmos', 1, 2),
      ])!;
      expect(dia.chave, '2026-11-24');
      expect(dia.livroDoFim, 'salmos');
      expect(dia.capituloDoFim, 2);
    });

    test('o plano guarda o id, o número e o fim do dia', () {
      final dia = DiaDaLeitura.doPlano('abc', 7, [_capitulos('joao', 3, 5)])!;
      expect(dia.planoId, 'abc');
      expect(dia.numero, 7);
      expect(dia.livroDoFim, 'joao');
      expect(dia.capituloDoFim, 5);
    });

    test('dia vazio ou terminado em devocional devolve nulo', () {
      expect(DiaDaLeitura.doCronograma('2026-11-24', []), isNull);
      expect(
        DiaDaLeitura.doCronograma('2026-11-24', [
          _capitulos('joao', 1, 1),
          _devocional,
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

  group('ehOFim', () {
    final dia = DiaDaLeitura.doCronograma('2026-11-24', [
      _capitulos('joao', 1, 3),
    ])!;

    test('só o último capítulo do dia é o fim', () {
      expect(dia.ehOFim('joao', 3), isTrue);
      expect(dia.ehOFim('joao', 2), isFalse);
      expect(dia.ehOFim('joao', 4), isFalse);
    });

    test('o mesmo número em outro livro não é o fim', () {
      expect(dia.ehOFim('marcos', 3), isFalse);
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
      expect(cronograma.livroDoFim, 'joao');
      expect(cronograma.capituloDoFim, 3);
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
      expect(plano.livroDoFim, 'salmos');
      expect(plano.capituloDoFim, 119);
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

    test('sem o fim, dá nulo', () {
      expect(
        DiaDaLeitura.doParametros({'diaDoCronograma': '2026-11-24'}),
        isNull,
      );
      expect(
        DiaDaLeitura.doParametros({'plano': 'abc', 'diaDoPlano': '3'}),
        isNull,
      );
    });

    test('fim malformado dá nulo', () {
      for (final fim in [
        '',
        'joao',
        'joao.',
        '.3',
        'joao.x',
        'joao.0',
        'joao.-1',
        'joao.3.1',
      ]) {
        expect(
          DiaDaLeitura.doParametros({
            'diaDoCronograma': '2026-11-24',
            'fim': fim,
          }),
          isNull,
          reason: 'fim "$fim"',
        );
      }
    });

    test('só o fim, sem dia nenhum, dá nulo', () {
      expect(DiaDaLeitura.doParametros({'fim': 'joao.3'}), isNull);
    });

    test('cronograma com a chave vazia dá nulo', () {
      expect(
        DiaDaLeitura.doParametros({'diaDoCronograma': '', 'fim': 'joao.3'}),
        isNull,
      );
    });

    test('plano sem id, sem número ou com número torto dá nulo', () {
      for (final parametros in [
        {'diaDoPlano': '3', 'fim': 'joao.3'},
        {'plano': '', 'diaDoPlano': '3', 'fim': 'joao.3'},
        {'plano': 'abc', 'fim': 'joao.3'},
        {'plano': 'abc', 'diaDoPlano': 'x', 'fim': 'joao.3'},
        {'plano': 'abc', 'diaDoPlano': '0', 'fim': 'joao.3'},
        {'plano': 'abc', 'diaDoPlano': '-2', 'fim': 'joao.3'},
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
        'fim': 'joao.1',
      });
      expect(dia, isA<DiaDePlano>());
      expect(dia!.capituloDoFim, 1);
    });

    test('com os dois tipos de dia, o cronograma vence', () {
      final dia = DiaDaLeitura.doParametros({
        'diaDoCronograma': '2026-11-24',
        'plano': 'abc',
        'diaDoPlano': '3',
        'fim': 'joao.3',
      });
      expect(dia, isA<DiaDoCronograma>());
    });
  });
}
