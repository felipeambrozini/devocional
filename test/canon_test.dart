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

    test('resolve livro a partir da referencia do devocional', () {
      expect(livroDaReferencia('Js 5:12')?.slug, 'josue');
      expect(livroDaReferencia('2Pe 3:18')?.slug, '2pedro');
      expect(livroDaReferencia('Gênesis 3:15')?.slug, 'genesis');
      expect(livroDaReferencia('1 Samuel 2:9')?.slug, '1samuel');
      expect(livroDaReferencia('nada a ver 1:1'), isNull);
    });

    test('resolve mesmo com o nome do livro todo em maiusculas', () {
      // O Devocional reescreve a referencia de Manha e Noite assim ("JOSUÉ
      // 5:12"), para exibir como cabecalho; a introducao do livro depende de
      // livrosDaReferencia continuar reconhecendo esse formato.
      expect(livroDaReferencia('JOSUÉ 5:12')?.slug, 'josue');
      expect(livroDaReferencia('JOÃO 6:37')?.slug, 'joao');
      expect(capituloEVersiculoDaReferencia('JOSUÉ 5:12'), (livroPorSlug('josue'), 5, 12));
    });

    test('resolve todos os livros quando a referencia cita mais de um', () {
      expect(livrosDaReferencia('Js 5:12').map((l) => l.slug), ['josue']);
      expect(
        livrosDaReferencia('Js 5:12 e Hb 4:9').map((l) => l.slug),
        ['josue', 'hebreus'],
      );
      expect(
        livrosDaReferencia('Gênesis 3:15, Romanos 16:20').map((l) => l.slug),
        ['genesis', 'romanos'],
      );
      // Livro repetido aparece uma unica vez.
      expect(livrosDaReferencia('Js 5:12 e Js 1:9').map((l) => l.slug), ['josue']);
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
