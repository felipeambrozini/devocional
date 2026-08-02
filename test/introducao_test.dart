import 'dart:convert';
import 'dart:io';

import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guarda o formato das 66 introduções enquanto elas são escritas.
///
/// São muitos arquivos escritos à mão; sem esta rede, um cabeçalho trocado ou um
/// travessão esquecido só apareceria na tela, depois de tudo pronto.
void main() {
  final arquivos =
      Directory('assets/intro')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('existe exatamente uma introdução para cada um dos 66 livros', () {
    final slugs = arquivos
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toSet();
    expect(slugs.length, 66);
    for (final livro in canon) {
      expect(slugs, contains(livro.slug), reason: 'falta ${livro.nome}');
    }
  });

  for (final arquivo in arquivos) {
    final slug = arquivo.uri.pathSegments.last.replaceAll('.json', '');

    group('introdução de $slug', () {
      late Introducao intro;
      late Map<String, dynamic> cru;

      setUp(() {
        cru = json.decode(arquivo.readAsStringSync()) as Map<String, dynamic>;
        intro = Introducao.doJson(cru);
      });

      test('o slug é um livro do canon e casa com o nome do arquivo', () {
        expect(cru['slug'], slug);
        final livro = livroPorSlug(slug);
        expect(livro, isNotNull, reason: '$slug não está no canon');
        expect(intro.livro, livro!.nome);
      });

      test('tem as quatro seções na ordem exigida', () {
        final titulos = intro.secoes.map((s) => s.$1).toList();
        expect(titulos, [
          'Circunstâncias da escrita',
          'Contribuição para a Bíblia',
          'Estrutura',
          'Spurgeon em ${nomeDoLivro(slug)}',
        ]);
      });

      test('nenhuma seção está vazia ou raquítica', () {
        for (final (titulo, corpo) in intro.secoes) {
          expect(corpo.trim(), isNotEmpty, reason: titulo);
          expect(
            corpo.split(RegExp(r'\s+')).length,
            greaterThan(60),
            reason: '$titulo tem texto curto demais',
          );
        }
      });

      test('não usa travessão em lugar nenhum', () {
        // Restrição explícita do formato: só vírgula, ponto e vírgula e ponto.
        for (final (titulo, corpo) in intro.secoes) {
          for (final proibido in ['—', '–', '--']) {
            expect(
              corpo,
              isNot(contains(proibido)),
              reason: '$titulo usa $proibido',
            );
          }
        }
      });

      test('a seção de Spurgeon fala em primeira pessoa', () {
        final corpo = intro.secoes.last.$2;
        final marcas = [
          'eu ',
          'me ',
          'minha',
          'meu ',
          'preguei',
          'confesso',
          'tenho ',
        ];
        expect(
          marcas.any((m) => corpo.toLowerCase().contains(m)),
          isTrue,
          reason: 'a quarta seção precisa ser em primeira pessoa',
        );
      });

      test('frase só aparece como citação de Spurgeon se for comprovada', () {
        // Uma linha composta na voz dele, rotulada como citação, seria atribuir a
        // uma pessoa real palavras que ela não escreveu.
        if (intro.frase.trim().isEmpty) return;
        expect(
          intro.fraseComprovada,
          isTrue,
          reason: 'frase presente exige quoteAttributed: true',
        );
        expect(
          intro.fonteDaFrase.trim(),
          isNotEmpty,
          reason: 'frase comprovada exige quoteSource com a obra',
        );
      });
    });
  }

  group('a linha de crédito da frase', () {
    // Os 66 assets todos têm fonte comprovada, e o teste acima exige que continue
    // assim, então o ramo sem fonte é inalcançável pelos arquivos. Construir a
    // Introducao na mão é o único jeito de exercitá-lo: sem isto, uma regressão
    // nesse ramo não apareceria em teste nem na tela.
    test('sem fonte comprovada não se apresenta como citação de Spurgeon', () {
      const semFonte = Introducao(
        livro: 'Gênesis',
        secoes: [],
        frase: 'uma linha na voz dele',
        fraseComprovada: false,
        fonteDaFrase: '',
      );
      expect(
        semFonte.atribuicao,
        'Escrito na voz de Spurgeon; sem citação comprovada',
      );
    });

    test('comprovada e sem fonte também não vira citação', () {
      const semObra = Introducao(
        livro: 'Gênesis',
        secoes: [],
        frase: 'x',
        fraseComprovada: true,
        fonteDaFrase: '   ',
      );
      expect(
        semObra.atribuicao,
        'Escrito na voz de Spurgeon; sem citação comprovada',
        reason: 'fonte só com espaços não é fonte, e a vírgula ficaria solta',
      );
    });

    test('com fonte comprovada credita Spurgeon e a obra', () {
      const comFonte = Introducao(
        livro: 'Salmos',
        secoes: [],
        frase: 'x',
        fraseComprovada: true,
        fonteDaFrase: 'O Tesouro de Davi',
      );
      expect(comFonte.atribuicao, 'Charles H. Spurgeon, O Tesouro de Davi');
    });
  });

  test('progresso: quantas das 66 já estão escritas', () {
    final escritas = arquivos.length;
    // Não falha por estar incompleto: só registra o andamento no relatório.
    printOnFailure('$escritas de 66');
    expect(escritas, lessThanOrEqualTo(66));
  });
}
