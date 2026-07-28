import 'package:felipe_ambrozini/data/canon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canon', () {
    test('tem 66 livros e 1189 capitulos', () {
      expect(canon.length, 66);
      expect(canon.fold<int>(0, (soma, l) => soma + l.capitulos), 1189);
    });

    test('39 livros no Antigo Testamento e 27 no Novo', () {
      expect(canon.where((l) => l.testamento == Testamento.antigo).length, 39);
      expect(canon.where((l) => l.testamento == Testamento.novo).length, 27);
    });

    test('slugs sao unicos', () {
      expect(canon.map((l) => l.slug).toSet().length, 66);
    });

    test('comeca em Genesis e termina em Apocalipse', () {
      expect(canon.first.slug, 'genesis');
      expect(canon.last.slug, 'apocalipse');
    });

    test('resolve slug e devolve o proprio slug quando desconhecido', () {
      expect(nomeDoLivro('salmos'), 'Salmos');
      expect(livroPorSlug('salmos')?.capitulos, 150);
      expect(livroPorSlug('inexistente'), isNull);
      // Preferimos mostrar algo estranho na tela a fazer sumir uma referencia.
      expect(nomeDoLivro('inexistente'), 'inexistente');
    });

    test('contagem de capitulos de casos que costumam sair errados', () {
      expect(livroPorSlug('salmos')!.capitulos, 150);
      expect(livroPorSlug('josue')!.capitulos, 24);
      expect(livroPorSlug('1reis')!.capitulos, 22);
      expect(livroPorSlug('obadias')!.capitulos, 1);
      expect(livroPorSlug('3joao')!.capitulos, 1);
    });
  });
}
