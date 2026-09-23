import 'dart:convert';
import 'dart:io';

import 'package:felipe_ambrozini/dados/canon.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guarda o formato dos comentários de Spurgeon por versículo enquanto são
/// escritos aos poucos, livro por livro, versículo por versículo.
///
/// Diferente de introducao_test.dart, não exige as 66 livros completos: um
/// comentário por versículo é uma escala muito maior, e o app trata a
/// ausência de arquivo, ou de um versículo dentro dele, como "ainda não
/// escrito", não como erro.
void main() {
  final diretorio = Directory('assets/comentarios');
  final arquivos =
      (diretorio.existsSync() ? diretorio.listSync() : <FileSystemEntity>[])
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final arquivo in arquivos) {
    final slug = arquivo.uri.pathSegments.last.replaceAll('.json', '');

    group('comentários de $slug', () {
      late Map<String, dynamic> cru;

      setUp(() {
        cru = json.decode(arquivo.readAsStringSync()) as Map<String, dynamic>;
      });

      test('o slug é um livro do canon e casa com o nome do arquivo', () {
        expect(cru['slug'], slug);
        final livro = livroPorSlug(slug);
        expect(livro, isNotNull, reason: '$slug não está no canon');
        expect(cru['book'], livro!.nome);
      });

      test('cada capítulo e versículo comentado existe no livro', () {
        final livro = livroPorSlug(slug)!;
        final capitulos = cru['capitulos'] as Map<String, dynamic>? ?? {};
        for (final entradaDeCapitulo in capitulos.entries) {
          final capitulo = int.parse(entradaDeCapitulo.key);
          expect(
            capitulo,
            inInclusiveRange(1, livro.capitulos),
            reason: '$slug não tem capítulo ${entradaDeCapitulo.key}',
          );
          final versiculos = entradaDeCapitulo.value as Map<String, dynamic>;
          for (final entradaDeVersiculo in versiculos.entries) {
            expect(
              int.parse(entradaDeVersiculo.key),
              greaterThan(0),
              reason:
                  '$slug $capitulo:${entradaDeVersiculo.key} tem número '
                  'inválido',
            );
          }
        }
      });

      test('nenhum comentário está vazio, raquítico ou usa travessão', () {
        final capitulos = cru['capitulos'] as Map<String, dynamic>? ?? {};
        for (final entradaDeCapitulo in capitulos.entries) {
          final versiculos = entradaDeCapitulo.value as Map<String, dynamic>;
          for (final entradaDeVersiculo in versiculos.entries) {
            final referencia =
                '$slug ${entradaDeCapitulo.key}:${entradaDeVersiculo.key}';
            final corpo = entradaDeVersiculo.value as String;
            expect(corpo.trim(), isNotEmpty, reason: referencia);
            expect(
              // ignore: deprecated_member_use
              corpo.split(RegExp(r'\s+')).length,
              greaterThan(20),
              reason: '$referencia tem texto curto demais',
            );
            for (final proibido in ['—', '–', '--', ' -', '- ']) {
              expect(
                corpo,
                isNot(contains(proibido)),
                reason: '$referencia usa $proibido',
              );
            }
          }
        }
      });
    });
  }
}
