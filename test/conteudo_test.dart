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

  group('assets de Biblia', () {
    for (final versao in Versao.values) {
      test('${versao.sigla}: 66 arquivos de livro mais o index', () {
        final dir = Directory('assets/bible/${versao.pasta}');
        expect(dir.existsSync(), isTrue, reason: 'falta ${dir.path}');
        final arquivos = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .map((f) => f.uri.pathSegments.last)
            .toSet();
        expect(arquivos.length, 67);
        expect(arquivos, contains('index.json'));
        for (final livro in canon) {
          expect(arquivos, contains('${livro.slug}.json'), reason: livro.nome);
        }
      });

      test(
        '${versao.sigla}: nenhum capitulo faltando e nenhum versiculo vazio',
        () {
          var totalVersiculos = 0;
          for (final livro in canon) {
            final dados =
                json.decode(
                      File(
                        'assets/bible/${versao.pasta}/${livro.slug}.json',
                      ).readAsStringSync(),
                    )
                    as Map<String, dynamic>;
            final capitulos = dados['chapters'] as Map<String, dynamic>;
            expect(capitulos.length, livro.capitulos, reason: livro.nome);
            for (var n = 1; n <= livro.capitulos; n++) {
              final cap = capitulos['$n'] as Map<String, dynamic>?;
              expect(cap, isNotNull, reason: '${livro.nome} $n');
              final versiculos = cap!['verses'] as Map<String, dynamic>;
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
              totalVersiculos += versiculos.length;
            }
          }
          // A BKJ fecha no canon; a NVT segue a NLT, que divide dois versiculos
          // diferente (3 João 1:15 e Apocalipse 12:18).
          expect(totalVersiculos, versao == Versao.bkj ? 31102 : 31104);
        },
      );
    }

    test('a palavra SENHOR nao se perdeu no versalete da NVT', () {
      // A NVT grafa SENHOR como 'S' no corpo mais 'ENHOR' em versalete, num span
      // separado do PDF. Tratar esse span como nota de rodape apagava a palavra da
      // Biblia inteira, deixando 'o S é meu pastor'.
      final salmos =
          json.decode(File('assets/bible/nvt/salmos.json').readAsStringSync())
              as Map<String, dynamic>;
      final versiculo =
          ((salmos['chapters'] as Map<String, dynamic>)['23']
                  as Map<String, dynamic>)['verses']
              as Map<String, dynamic>;
      expect(versiculo['1'], contains('SENHOR'));
      expect(versiculo['1'], isNot(contains(' S ')));
    });

    test('sobrescrito do salmo fica no titulo, fora do versiculo 1', () {
      for (final versao in Versao.values) {
        final salmos =
            json.decode(
                  File(
                    'assets/bible/${versao.pasta}/salmos.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final cap3 =
            (salmos['chapters'] as Map<String, dynamic>)['3']
                as Map<String, dynamic>;
        expect(cap3['title'] as String, contains('Davi'), reason: versao.sigla);
        final v1 = (cap3['verses'] as Map<String, dynamic>)['1'] as String;
        expect(v1, isNot(contains('Salmo de Davi')), reason: versao.sigla);
      }
    });

    test('nenhum versiculo carrega texto de nota nem de apendice', () {
      const intrusos = [
        'Em hebraico',
        'A Septuaginta traz',
        'Table of Contents',
        'BVBooks',
        'http',
      ];
      for (final versao in Versao.values) {
        for (final livro in canon) {
          final dados =
              json.decode(
                    File(
                      'assets/bible/${versao.pasta}/${livro.slug}.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>;
          for (final cap
              in (dados['chapters'] as Map<String, dynamic>).values) {
            for (final texto
                in ((cap as Map<String, dynamic>)['verses']
                        as Map<String, dynamic>)
                    .values) {
              for (final intruso in intrusos) {
                expect(
                  texto as String,
                  isNot(contains(intruso)),
                  reason: '${versao.sigla} ${livro.nome}',
                );
              }
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
                  'assets/devotional/morning_evening.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      expect(dados.length, 366);
      // 29 de fevereiro existe no devocional, ao contrario do cronograma de leitura.
      expect(dados.containsKey('02-29'), isTrue);

      for (final entrada in dados.entries) {
        final dia = entrada.value as Map<String, dynamic>;
        for (final periodo in ['manha', 'noite']) {
          final leitura = dia[periodo] as Map<String, dynamic>?;
          expect(leitura, isNotNull, reason: '${entrada.key} $periodo');
          final texto = leitura!['text'] as String;
          expect(
            texto.length,
            greaterThan(500),
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
                  'assets/devotional/morning_evening.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      final naoResolvidas = <String>[];
      for (final entrada in dados.entries) {
        final dia = entrada.value as Map<String, dynamic>;
        for (final periodo in ['manha', 'noite']) {
          final referencia =
              (dia[periodo] as Map<String, dynamic>)['reference'] as String;
          final trechos = referencia.split(RegExp(r'[,;]\s*|\s+e\s+'));
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
        'cansativa peregrinação',
      );
      expect(achados, hasLength(1));
      expect(achados.single.leitura, 'manha');
      expect(achados.single.data, '01-01');
    });

    test('acha um termo de Promessas com a leitura "promessas"', () async {
      final achados = await Conteudo.instancia.buscarDevocionais(
        'primeira promessa dada',
      );
      expect(achados, hasLength(1));
      expect(achados.single.leitura, 'promessas');
      expect(achados.single.data, '01-01');
    });

    test('ignora acento e caixa, igual à busca da Bíblia', () async {
      final achados = await Conteudo.instancia.buscarDevocionais(
        'CANSATIVA PEREGRINACAO',
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
      // poder trocar entre BKJ e NVT; e a referência às vezes é uma faixa de
      // dois versículos ("Salmos 102:13-14"), não só um único versículo.
      final arquivo = File('assets/devotional/promises.json');
      if (!arquivo.existsSync()) return;
      final dados =
          json.decode(arquivo.readAsStringSync()) as Map<String, dynamic>;

      final naoResolvidas = <String>[];
      for (final entrada in dados.entries) {
        final referencia =
            (entrada.value as Map<String, dynamic>)['reference'] as String;
        if (faixaDeVersiculoDaReferencia(referencia) == null) {
          naoResolvidas.add('${entrada.key}: "$referencia"');
        }
      }
      expect(naoResolvidas, isEmpty);
    });
  });
}
