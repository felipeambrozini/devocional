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
      expect(capituloEVersiculoDaReferencia('JOSUÉ 5:12'), (
        livroPorSlug('josue'),
        5,
        12,
      ));
    });

    test('resolve todos os livros quando a referencia cita mais de um', () {
      expect(livrosDaReferencia('Js 5:12').map((l) => l.slug), ['josue']);
      expect(livrosDaReferencia('Js 5:12 e Hb 4:9').map((l) => l.slug), [
        'josue',
        'hebreus',
      ]);
      expect(
        livrosDaReferencia('Gênesis 3:15, Romanos 16:20').map((l) => l.slug),
        ['genesis', 'romanos'],
      );
      // Livro repetido aparece uma unica vez.
      expect(livrosDaReferencia('Js 5:12 e Js 1:9').map((l) => l.slug), [
        'josue',
      ]);
    });

    test('resolve todos os versiculos quando a referencia cita mais de um', () {
      expect(versiculosDaReferencia('Js 5:12'), [
        (livroPorSlug('josue'), 5, 12),
      ]);
      expect(
        // O dia de 12 de julho de Manha e Noite encadeia tres passagens.
        versiculosDaReferencia('Jd 1:1, 1Co 1:2, 1Pe 1:2'),
        [
          (livroPorSlug('judas'), 1, 1),
          (livroPorSlug('1corintios'), 1, 2),
          (livroPorSlug('1pedro'), 1, 2),
        ],
      );
      // Trecho que nao resolve e' descartado, nao derruba os outros.
      expect(versiculosDaReferencia('Js 5:12 e nada a ver 1:1'), [
        (livroPorSlug('josue'), 5, 12),
      ]);
    });

    test(
      'resolve faixa de versiculos, como as promessas de dois versiculos',
      () {
        // Sem faixa, e' um so versiculo (inicio e fim iguais).
        expect(faixaDeVersiculoDaReferencia('Jo 6:37'), (
          livroPorSlug('joao'),
          6,
          37,
          37,
        ));
        // Promessas de Deus as vezes cita dois versiculos como uma so promessa.
        expect(faixaDeVersiculoDaReferencia('Salmos 102:13-14'), (
          livroPorSlug('salmos'),
          102,
          13,
          14,
        ));
        expect(faixasDaReferencia('Jo 6:37, Sl 102:13-14'), [
          (livroPorSlug('joao'), 6, 37, 37),
          (livroPorSlug('salmos'), 102, 13, 14),
        ]);
      },
    );

    test('contagem de capitulos de casos que costumam sair errados', () {
      expect(livroPorSlug('salmos')!.capitulos, 150);
      expect(livroPorSlug('josue')!.capitulos, 24);
      expect(livroPorSlug('1reis')!.capitulos, 22);
      expect(livroPorSlug('obadias')!.capitulos, 1);
      expect(livroPorSlug('3joao')!.capitulos, 1);
    });

    test('resolve o alvo de um link, capitulo com ou sem versiculo', () {
      expect(alvoDoLink('joao.3.16'), ('joao', 3, 16));
      expect(alvoDoLink('joao.3'), ('joao', 3, null));
    });

    test('rejeita link com slug, numero ou capitulo invalido', () {
      expect(alvoDoLink('inexistente.3.16'), isNull);
      expect(alvoDoLink('joao.abc'), isNull);
      expect(alvoDoLink('joao.3.abc'), isNull);
      // João só tem 21 capítulos.
      expect(alvoDoLink('joao.99'), isNull);
      expect(alvoDoLink('joao'), isNull);
      expect(alvoDoLink('joao.3.16.extra'), isNull);
    });

    test('link de um versiculo eh o inverso de alvoDoLink', () {
      final link = linkDoVersiculo('joao', 3, 16);
      expect(link, '$enderecoDoSite?ler=joao.3.16');
      final parametro = link.split('?ler=').last;
      expect(alvoDoLink(parametro), ('joao', 3, 16));
    });

    test('marca de edicao atras da referencia e ignorada', () {
      // O devocional citava "1Tm 3:16 ACF" e o parsing precisa parar no
      // primeiro numero, sem engasgar com a sigla (canon.dart).
      expect(capituloEVersiculoDaReferencia('1Tm 3:16 ACF'), (
        livroPorSlug('1timoteo'),
        3,
        16,
      ));
      expect(faixaDeVersiculoDaReferencia('1Tm 3:16 ACF'), (
        livroPorSlug('1timoteo'),
        3,
        16,
        16,
      ));
    });

    test('dois versiculos do mesmo capitulo seguem um trecho so', () {
      // "Zc 1:12,13" cita dois versiculos do mesmo capitulo: a virgula
      // separa versiculos, nao passagens (canon.dart).
      expect(trechosDaReferencia('Zc 1:12,13'), ['Zc 1:12,13']);
      expect(faixaDeVersiculoDaReferencia('Zc 1:12,13'), (
        livroPorSlug('zacarias'),
        1,
        12,
        13,
      ));
      // versiculosDaReferencia resolve um versiculo por trecho, o primeiro;
      // a faixa completa é responsabilidade de faixaDeVersiculoDaReferencia.
      expect(versiculosDaReferencia('Zc 1:12,13'), [
        (livroPorSlug('zacarias'), 1, 12),
      ]);
    });
  });
}
