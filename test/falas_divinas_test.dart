import 'dart:convert';
import 'dart:io';

import 'package:devocional/dados/canon.dart';
import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/modelos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('partesDoVersiculo', () {
    test('separa introdução narrada, fala e narração final', () {
      expect(
        partesDoVersiculo('E disse Deus: Haja luz. E houve luz.', [(14, 23)]),
        [
          ('E disse Deus: ', false),
          ('Haja luz.', true),
          (' E houve luz.', false),
        ],
      );
    });

    test('sem trechos devolve o versículo inteiro sem vermelho', () {
      expect(partesDoVersiculo('No princípio.', const []), [
        ('No princípio.', false),
      ]);
    });

    test('índice além do fim é aparado, não lança', () {
      expect(partesDoVersiculo('Abc', [(1, 99)]), [('A', false), ('bc', true)]);
    });
  });

  test('cada trecho cabe no seu versículo, em ordem e sem sobrepor', () {
    for (final livro in canon) {
      final falas =
          json.decode(
                File(
                  'assets/falas_divinas/${livro.slug}.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final capitulos =
          (json.decode(
                    File('assets/biblia/${livro.slug}.json').readAsStringSync(),
                  )
                  as Map<String, dynamic>)['capitulos']
              as Map<String, dynamic>;
      for (final MapEntry(key: cap, value: versiculos) in falas.entries) {
        for (final MapEntry(key: v, value: trechos)
            in (versiculos as Map<String, dynamic>).entries) {
          final texto = capitulos[cap]['versiculos'][v] as String?;
          final ref = '${livro.nome} $cap:$v';
          expect(texto, isNotNull, reason: ref);
          var anterior = 0;
          for (final trecho in trechos as List) {
            final [inicio as int, fim as int] = trecho as List;
            expect(inicio >= anterior && fim > inicio, isTrue, reason: ref);
            expect(fim <= texto!.length, isTrue, reason: ref);
            anterior = fim;
          }
        }
      }
    }
  });

  test('os assets batem com as correções manuais de tools/falas_divinas', () {
    final pasta = Directory('tools/falas_divinas/correcoes');
    if (!pasta.existsSync()) return;
    final arquivos = pasta.listSync().whereType<File>().where(
      (arquivo) => arquivo.path.endsWith('.json'),
    );
    for (final arquivo in arquivos) {
      final slug = arquivo.uri.pathSegments.last.replaceAll('.json', '');
      final correcoes =
          json.decode(arquivo.readAsStringSync()) as Map<String, dynamic>;
      final falas =
          json.decode(
                File('assets/falas_divinas/$slug.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final capitulos =
          (json.decode(File('assets/biblia/$slug.json').readAsStringSync())
                  as Map<String, dynamic>)['capitulos']
              as Map<String, dynamic>;
      for (final MapEntry(key: cap, value: versiculos) in correcoes.entries) {
        for (final MapEntry(key: v, value: trechos)
            in (versiculos as Map<String, dynamic>).entries) {
          final ref = '$slug $cap:$v';
          final texto = capitulos[cap]['versiculos'][v] as String;
          final esperado = <List<int>>[];
          var posicao = 0;
          for (final item in trechos as List) {
            // Um trecho é a string, ou [string, n] para a n-ésima ocorrência.
            final (trecho, numero) = item is String
                ? (item, 1)
                : (item[0] as String, item[1] as int);
            var inicio = -1;
            for (var vez = 0; vez < numero; vez++) {
              inicio = texto.indexOf(trecho, inicio + 1);
            }
            expect(
              inicio >= posicao,
              isTrue,
              reason: '$ref: "$trecho" fora de ordem',
            );
            esperado.add([inicio, inicio + trecho.length]);
            posicao = inicio + trecho.length;
          }
          final atual = [
            for (final trecho in (falas[cap]?[v] as List? ?? const []))
              (trecho as List).cast<int>(),
          ];
          expect(atual, esperado, reason: ref);
        }
      }
    }
  });

  test('o capítulo traz as falas: "Haja luz." em Gênesis 1:3', () async {
    final capitulo = await Conteudo.instancia.capitulo('genesis', 1);
    final (_, texto) = capitulo.versiculos[2];
    final vermelho = [
      for (final (pedaco, divino) in partesDoVersiculo(
        texto,
        capitulo.falasDivinas[3]!,
      ))
        if (divino) pedaco,
    ];
    expect(vermelho, ['Haja luz.']);
    expect(capitulo.falasDivinas.containsKey(1), isFalse);
  });

  test('a letra vermelha nasce ligada e persiste desligada', () async {
    SharedPreferences.setMockInitialValues({});
    final estado = Estado(await SharedPreferences.getInstance());
    expect(estado.letraVermelha, isTrue);

    await estado.definirLetraVermelha(false);

    final reaberto = Estado(await SharedPreferences.getInstance());
    expect(reaberto.letraVermelha, isFalse);
  });
}
