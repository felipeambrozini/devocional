import 'package:devocional/dados/planos_nuvem.dart';
import 'package:flutter_test/flutter_test.dart';

/// A revisão do plano compartilhado: quando o criador troca livros ou dias, o
/// dia 5 vira outro trecho, e a entrada de quem ficou para trás não conta.

void main() {
  group('revisaoDoPlano', () {
    test('documento sem o campo não tem revisão', () {
      expect(revisaoDoPlano({'dias': 10}), isNull);
    });

    test('devolve a revisão inteira do documento', () {
      expect(revisaoDoPlano({'revisao': 3}), 3);
      expect(revisaoDoPlano({'revisao': 0}), 0);
    });

    test('valor que não é inteiro é como se não existisse', () {
      expect(revisaoDoPlano({'revisao': '3'}), isNull);
      expect(revisaoDoPlano({'revisao': 2.5}), isNull);
      expect(revisaoDoPlano({'revisao': null}), isNull);
    });
  });

  group('entradaDesatualizada', () {
    test('documento sem revisão nunca deixa ninguém para trás', () {
      expect(
        entradaDesatualizada({}, {
          'lidos': [1],
        }),
        isFalse,
      );
      expect(
        entradaDesatualizada({}, {
          'lidos': [1],
          'revisao': 2,
        }),
        isFalse,
      );
      expect(entradaDesatualizada({}, null), isFalse);
    });

    test('entrada sem revisão num documento com revisão está atrasada', () {
      expect(
        entradaDesatualizada(
          {'revisao': 1},
          {
            'lidos': [1],
          },
        ),
        isTrue,
      );
    });

    test('entrada ausente ou malformada num documento com revisão atrasa', () {
      expect(entradaDesatualizada({'revisao': 1}, null), isTrue);
      expect(entradaDesatualizada({'revisao': 1}, 'texto'), isTrue);
    });

    test('revisões iguais não estão atrasadas', () {
      expect(
        entradaDesatualizada({'revisao': 2}, {'lidos': [], 'revisao': 2}),
        isFalse,
      );
    });

    test('revisão diferente da do documento está atrasada', () {
      expect(
        entradaDesatualizada({'revisao': 2}, {'lidos': [], 'revisao': 1}),
        isTrue,
      );
    });
  });

  group('lidosValidos', () {
    test('devolve os dias da entrada em dia', () {
      final dados = {'dias': 10, 'revisao': 1};
      final entrada = {
        'lidos': [1, 5, 10],
        'revisao': 1,
      };
      expect(lidosValidos(dados, entrada), {1, 5, 10});
    });

    test('documento sem revisão aceita a entrada como está', () {
      expect(
        lidosValidos(
          {'dias': 3},
          {
            'lidos': [1, 2],
          },
        ),
        {1, 2},
      );
    });

    test('entrada desatualizada não conta nenhum dia', () {
      final dados = {'dias': 10, 'revisao': 2};
      expect(
        lidosValidos(dados, {
          'lidos': [1, 2, 3],
          'revisao': 1,
        }),
        isEmpty,
      );
      expect(
        lidosValidos(dados, {
          'lidos': [1, 2, 3],
        }),
        isEmpty,
      );
    });

    test('descarta dias acima do total e abaixo de 1, mantendo os limites', () {
      final entrada = {
        'lidos': [-1, 0, 1, 7, 8, 100],
      };
      expect(lidosValidos({'dias': 7}, entrada), {1, 7});
    });

    test('sem o total de dias no documento, só o limite inferior vale', () {
      final entrada = {
        'lidos': [0, 1, 500],
      };
      expect(lidosValidos({}, entrada), {1, 500});
      expect(lidosValidos({'dias': 'dez'}, entrada), {1, 500});
    });

    test('ignora itens que não são inteiros', () {
      final entrada = {
        'lidos': [1, '2', 3.5, null, 4],
      };
      expect(lidosValidos({'dias': 10}, entrada), {1, 4});
    });

    test('entrada ausente ou malformada não conta nada', () {
      expect(lidosValidos({'dias': 10}, null), isEmpty);
      expect(lidosValidos({'dias': 10}, 'texto'), isEmpty);
      expect(lidosValidos({'dias': 10}, <String, dynamic>{}), isEmpty);
      expect(lidosValidos({'dias': 10}, {'lidos': 'x'}), isEmpty);
    });

    test('lista vazia de lidos dá conjunto vazio', () {
      expect(lidosValidos({'dias': 10}, {'lidos': <int>[]}), isEmpty);
    });
  });
}
