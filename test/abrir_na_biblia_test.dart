import 'package:devocional/funcoes/abrir_na_biblia.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('caminhoNaBiblia', () {
    test('sem destaque, só livro e capítulo', () {
      expect(caminhoNaBiblia('joao', 3), '/ler/joao/3');
    });

    test('um versículo só vira um número', () {
      expect(
        caminhoNaBiblia('joao', 3, destacar: (16, 16)),
        '/ler/joao/3?versiculos=16',
      );
    });

    test('uma faixa vira de-ate', () {
      expect(
        caminhoNaBiblia('joao', 1, destacar: (1, 18)),
        '/ler/joao/1?versiculos=1-18',
      );
    });
  });

  group('leituraDoCaminho', () {
    test('desfaz o que caminhoNaBiblia monta', () {
      expect(leituraDoCaminho('joao', '1', '1-18'), ('joao', 1, (1, 18)));
      expect(leituraDoCaminho('joao', '3', '16'), ('joao', 3, (16, 16)));
      expect(leituraDoCaminho('joao', '3', null), ('joao', 3, null));
    });

    test('livro inexistente ou capítulo fora do livro dá null', () {
      expect(leituraDoCaminho('naoexiste', '1', null), isNull);
      expect(leituraDoCaminho('joao', '22', null), isNull);
      expect(leituraDoCaminho('joao', '0', null), isNull);
      expect(leituraDoCaminho('joao', 'x', null), isNull);
    });

    test('faixa inválida some, mas o capítulo continua abrindo', () {
      expect(leituraDoCaminho('joao', '3', '18-16'), ('joao', 3, null));
      expect(leituraDoCaminho('joao', '3', '0'), ('joao', 3, null));
      expect(leituraDoCaminho('joao', '3', 'a-b'), ('joao', 3, null));
      expect(leituraDoCaminho('joao', '3', '1-2-3'), ('joao', 3, null));
    });
  });
}
