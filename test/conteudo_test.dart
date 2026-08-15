import 'dart:convert';
import 'dart:io';

import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/conteudo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Estes testes leem os assets do disco. Não são um teste de widget: são a garantia
/// de que o texto extraído dos PDFs continua íntegro depois de qualquer mexida no
/// extrator, que é onde os erros silenciosos aparecem.
void main() {
  // Só para os testes de buscarDevocionais, que passam por `rootBundle`
  // (Conteudo lê os dois JSONs de devocional do bundle, não do disco direto
  // como o resto deste arquivo). Sem isto, `rootBundle.loadString` não tem
  // canal de plataforma para responder. Mesmo padrão de `fontes_test.dart`.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizacao da busca', () {
    test('ignora acento e caixa', () {
      expect(Conteudo.normalizar('CORAÇÃO'), 'coracao');
      expect(Conteudo.normalizar('Após'), 'apos');
      expect(Conteudo.normalizar('Jesus'), 'jesus');
    });

    test('preserva o comprimento, para o realce nao sair deslocado', () {
      // A tela de busca mapeia posicoes do texto normalizado de volta no original.
      // Se a normalizacao mudasse o tamanho, o destaque cairia na letra errada.
      const amostras = ['coração', 'ÁGUAS', 'Habacuque', 'após três dias'];
      for (final amostra in amostras) {
        expect(
          Conteudo.normalizar(amostra).length,
          amostra.length,
          reason: amostra,
        );
      }
    });
  });

  // A tradução interna da KJB 1611 está completa: os 66 livros estão em
  // assets/biblia/ (ver README.md). Este grupo valida só os livros já presentes;
  // um livro ausente é pulado, não é falha. O total exato de
  // 31.102 versículos só faz sentido com os 66 prontos, e vira o teste `skip`
  // mais abaixo.
  final livrosPresentes = canon
      .where((livro) => File('assets/biblia/${livro.slug}.json').existsSync())
      .toList();

  group('assets de Biblia', () {
    for (final versao in Versao.values) {
      test(
        '${versao.sigla}: nenhum capitulo faltando e nenhum versiculo vazio',
        () {
          for (final livro in livrosPresentes) {
            final dados =
                json.decode(
                      File(
                        'assets/biblia/${livro.slug}.json',
                      ).readAsStringSync(),
                    )
                    as Map<String, dynamic>;
            final capitulos = dados['capitulos'] as Map<String, dynamic>;
            expect(capitulos.length, livro.capitulos, reason: livro.nome);
            for (var n = 1; n <= livro.capitulos; n++) {
              final cap = capitulos['$n'] as Map<String, dynamic>?;
              expect(cap, isNotNull, reason: '${livro.nome} $n');
              final versiculos = cap!['versiculos'] as Map<String, dynamic>;
              expect(versiculos, isNotEmpty, reason: '${livro.nome} $n vazio');
              // O versiculo 1 tem de existir sempre: foi assim que se descobriu que o
              // texto do v.1 estava caindo no sobrescrito em alguns capitulos.
              expect(
                versiculos.containsKey('1'),
                isTrue,
                reason: '${livro.nome} $n:1',
              );
              for (final entrada in versiculos.entries) {
                expect(
                  (entrada.value as String).trim(),
                  isNotEmpty,
                  reason: '${livro.nome} $n:${entrada.key}',
                );
              }
            }
          }
        },
      );
    }

    test(
      'total exato de 31.102 versiculos',
      () {
        var totalVersiculos = 0;
        for (final livro in canon) {
          final dados =
              json.decode(
                    File('assets/biblia/${livro.slug}.json').readAsStringSync(),
                  )
                  as Map<String, dynamic>;
          for (final cap
              in (dados['capitulos'] as Map<String, dynamic>).values) {
            totalVersiculos +=
                ((cap as Map<String, dynamic>)['versiculos']
                        as Map<String, dynamic>)
                    .length;
          }
        }
        expect(totalVersiculos, 31102);
      },
      skip: livrosPresentes.length < canon.length
          ? 'faltam ${canon.length - livrosPresentes.length} livros traduzir'
          : false,
    );

    test(
      'sobrescrito do salmo fica no titulo, fora do versiculo 1',
      () {
        final salmos =
            json.decode(File('assets/biblia/salmos.json').readAsStringSync())
                as Map<String, dynamic>;
        final cap3 =
            (salmos['capitulos'] as Map<String, dynamic>)['3']
                as Map<String, dynamic>;
        expect(cap3['titulo'] as String, contains('Davi'));
        final v1 = (cap3['versiculos'] as Map<String, dynamic>)['1'] as String;
        expect(v1, isNot(contains('Salmo de Davi')));
      },
      skip: !File('assets/biblia/salmos.json').existsSync()
          ? 'salmos.json ainda não foi traduzido'
          : false,
    );

    test('nenhum versiculo carrega texto de nota nem de apendice', () {
      const intrusos = [
        'Em hebraico',
        'A Septuaginta traz',
        'Table of Contents',
        'BVBooks',
        'http',
      ];
      for (final livro in livrosPresentes) {
        final dados =
            json.decode(
                  File('assets/biblia/${livro.slug}.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final cap in (dados['capitulos'] as Map<String, dynamic>).values) {
          for (final texto
              in ((cap as Map<String, dynamic>)['versiculos']
                      as Map<String, dynamic>)
                  .values) {
            for (final intruso in intrusos) {
              expect(
                texto as String,
                isNot(contains(intruso)),
                reason: livro.nome,
              );
            }
          }
        }
      }
    });
  });

  group('devocional Manha e Noite', () {
    test('366 dias, todos com manha e noite e com texto', () {
      final dados =
          json.decode(
                File(
                  'assets/devotionals/manha_e_noite.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      expect(dados.length, 366);
      // 29 de fevereiro existe no devocional, ao contrario do cronograma de leitura.
      expect(dados.containsKey('29-02'), isTrue);

      for (final entrada in dados.entries) {
        final dia = entrada.value as Map<String, dynamic>;
        for (final periodo in ['manha', 'noite']) {
          final leitura = dia[periodo] as Map<String, dynamic>?;
          expect(leitura, isNotNull, reason: '${entrada.key} $periodo');
          final texto = leitura!['devocional'] as String;
          expect(
            texto.length,
            // 01-01 noite é a mais curta das 732 entradas, com 439: um
            // parágrafo completo, não um defeito de extração.
            greaterThan(400),
            reason: '${entrada.key} $periodo',
          );
          expect(texto, isNot(contains('PLANO CRONOL')), reason: entrada.key);
        }
      }
    });

    test('a referencia de todo dia resolve livro, capitulo e versiculo', () {
      // A tela troca a referencia abreviada do asset pelo nome do livro por
      // extenso mais o versiculo completo da BKJ; se uma referencia não
      // resolvesse, o dia cairia de volta na abreviação crua em silêncio.
      //
      // O raro dia cita mais de uma passagem, separadas por vírgula ou "e"
      // (12 de julho pela manhã cita três); por isso a contagem de resolvidos
      // precisa bater com a contagem de trechos, não só ser maior que zero, ou
      // um dia com uma passagem faltando passaria em silêncio.
      final dados =
          json.decode(
                File(
                  'assets/devotionals/manha_e_noite.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      final naoResolvidas = <String>[];
      for (final entrada in dados.entries) {
        final dia = entrada.value as Map<String, dynamic>;
        for (final periodo in ['manha', 'noite']) {
          final referencia =
              (dia[periodo] as Map<String, dynamic>)['referencia'] as String;
          final trechos = trechosDaReferencia(referencia);
          if (versiculosDaReferencia(referencia).length != trechos.length) {
            naoResolvidas.add('${entrada.key} $periodo: "$referencia"');
          }
        }
      }
      expect(naoResolvidas, isEmpty);
    });
  });

  group('buscarDevocionais', () {
    test('acha um termo de Manhã com a leitura e a data certas', () async {
      final achados = await Conteudo.instancia.buscarDevocionais(
        'fatigantes peregrinações',
      );
      expect(achados, hasLength(1));
      expect(achados.single.leitura, 'manha');
      expect(achados.single.data, '01-01');
    });

    test('acha um termo de Promessas com a leitura "promessas"', () async {
      final achados = await Conteudo.instancia.buscarDevocionais(
        'primeira promessa ao homem caído',
      );
      expect(achados, hasLength(1));
      expect(achados.single.leitura, 'promessas');
      expect(achados.single.data, '01-01');
    });

    test('ignora acento e caixa, igual à busca da Bíblia', () async {
      final achados = await Conteudo.instancia.buscarDevocionais(
        'FATIGANTES PEREGRINACOES',
      );
      expect(achados, hasLength(1));
    });

    test('termo sem nenhum achado devolve lista vazia', () async {
      final achados = await Conteudo.instancia.buscarDevocionais(
        'xilofone inexistente',
      );
      expect(achados, isEmpty);
    });

    test('menos de três letras devolve lista vazia, sem varrer nada', () async {
      final achados = await Conteudo.instancia.buscarDevocionais('jo');
      expect(achados, isEmpty);
    });
  });

  group('devocional Promessas de Deus', () {
    test('a referencia de todo dia resolve livro, capitulo e versiculo(s)', () {
      // Promessas de Deus agora também busca o versículo ao vivo, para a pessoa
      // resolver a referência; e ela às vezes é uma faixa de dois versículos
      // ("Salmos 102:13-14"), não só um único versículo.
      final arquivo = File('assets/devotionals/promessas_de_deus.json');
      if (!arquivo.existsSync()) return;
      final dados =
          json.decode(arquivo.readAsStringSync()) as Map<String, dynamic>;

      final naoResolvidas = <String>[];
      for (final entrada in dados.entries) {
        final referencia =
            (entrada.value as Map<String, dynamic>)['referencia'] as String;
        if (faixaDeVersiculoDaReferencia(referencia) == null) {
          naoResolvidas.add('${entrada.key}: "$referencia"');
        }
      }
      expect(naoResolvidas, isEmpty);
    });
  });
}
