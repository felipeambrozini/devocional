import 'dart:convert';
import 'dart:io';

import 'package:devocional/dados/canon.dart';
import 'package:devocional/dados/config_admin.dart';
import 'package:devocional/dados/conteudo.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/recursos.dart';
import 'package:devocional/telas/biblia.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('comentário no capítulo', () {
    const trechoDeJoao1v1 = 'Três afirmações curtas, três muralhas';

    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() {
      ConfigAdmin.instancia.redefinirParaTeste();
      Recursos.comentarioNoCapituloForcado = null;
    });

    test('a flag nasce ligada, mesmo com o documento sem o campo', () {
      expect(Recursos.comentarioNoCapitulo, isTrue);
      ConfigAdmin.instancia.aplicarMapa({'bibliotecaAtiva': true});
      expect(Recursos.comentarioNoCapitulo, isTrue);
      ConfigAdmin.instancia.aplicarMapa({'comentarioNoCapituloAtivo': false});
      expect(Recursos.comentarioNoCapitulo, isFalse);
    });

    test('comentariosDoCapitulo devolve os 51 versículos de João 1', () async {
      final mapa = await Conteudo.instancia.comentariosDoCapitulo('joao', 1);
      expect(mapa.length, 51);
      expect(mapa[1], startsWith(trechoDeJoao1v1));
    });

    test('livro sem arquivo de comentário devolve vazio', () async {
      expect(await Conteudo.instancia.comentariosDoCapitulo('livro-x', 1), {});
    });

    Future<void> abrirLeitor(
      WidgetTester tester, {
      required bool flag,
      String livro = 'joao',
    }) async {
      Recursos.comentarioNoCapituloForcado = flag;
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirComentarioNoTexto(true);
      await tester.runAsync(() async {
        await Conteudo.instancia.capitulo(livro, 1);
        await Conteudo.instancia.introducao(livro);
        await Conteudo.instancia.comentariosDoCapitulo(livro, 1);
      });
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(home: TelaBiblia(livroInicial: livro)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('com a flag ligada mostra o comentário de 1:1', (tester) async {
      await abrirLeitor(tester, flag: true);
      expect(find.textContaining(trechoDeJoao1v1), findsOneWidget);
    });

    testWidgets('aberto num versículo pedido, o versículo continua à vista '
        'depois que os comentários entram', (tester) async {
      Recursos.comentarioNoCapituloForcado = true;
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirComentarioNoTexto(true);
      await tester.runAsync(() async {
        await Conteudo.instancia.capitulo('joao', 1);
        await Conteudo.instancia.introducao('joao');
        await Conteudo.instancia.comentariosDoCapitulo('joao', 1);
      });
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: const MaterialApp(
            home: TelaBiblia(livroInicial: 'joao', destacar: (14, 14)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final versiculo14 = find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('E o Verbo se fez carne'),
      );
      expect(versiculo14, findsOneWidget);
      final posicao = tester.getRect(versiculo14);
      expect(posicao.top, greaterThanOrEqualTo(0));
      expect(posicao.bottom, lessThanOrEqualTo(600));
    });

    testWidgets('aoCarregar roda uma vez, depois que os comentários entram', (
      tester,
    ) async {
      Recursos.comentarioNoCapituloForcado = true;
      await tester.runAsync(
        () => Conteudo.instancia.comentariosDoCapitulo('joao', 1),
      );
      var chamadas = 0;
      var comentariosNaTela = 0;
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirComentarioNoTexto(true);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: DevocionalComentariosDoCapitulo(
              livro: 'joao',
              capituloNumero: 1,
              aoCarregar: () => chamadas++,
              construir: (context, comentarios) {
                comentariosNaTela = comentarios?.length ?? 0;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(comentariosNaTela, 51);
      expect(chamadas, 1);
    });

    testWidgets('aoCarregar não roda com o recurso desligado', (tester) async {
      Recursos.comentarioNoCapituloForcado = false;
      var chamadas = 0;
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirComentarioNoTexto(true);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: DevocionalComentariosDoCapitulo(
              livro: 'joao',
              capituloNumero: 1,
              aoCarregar: () => chamadas++,
              construir: (context, comentarios) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(chamadas, 0);
    });

    testWidgets('por padrão o comentário não aparece junto do texto', (
      tester,
    ) async {
      Recursos.comentarioNoCapituloForcado = true;
      final estado = Estado(await SharedPreferences.getInstance());
      expect(estado.comentarioNoTexto, isFalse);
      expect(comentarioNoTextoAtivo(estado), isFalse);
    });

    testWidgets('com a flag desligada, não mostra', (tester) async {
      await abrirLeitor(tester, flag: false);
      expect(find.textContaining(trechoDeJoao1v1), findsNothing);
    });

    testWidgets('livro sem arquivo de comentário não mostra nada nem quebra', (
      tester,
    ) async {
      Recursos.comentarioNoCapituloForcado = true;
      final estado = Estado(await SharedPreferences.getInstance());
      await estado.definirComentarioNoTexto(true);
      await tester.pumpWidget(
        EscopoDoEstado(
          estado: estado,
          child: MaterialApp(
            home: DevocionalComentariosDoCapitulo(
              livro: 'livro-x',
              capituloNumero: 1,
              construir: (context, comentarios) =>
                  Text('comentários: ${comentarios?.length}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('comentários: 0'), findsOneWidget);
    });
  });
}
