import 'package:felipe_ambrozini/funcoes/dialogos.dart';
import 'package:felipe_ambrozini/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DevocionalLarguraDeLeitura', () {
    testWidgets('numa janela larga, centraliza e limita a largura do conteúdo', (
      tester,
    ) async {
      // Simula uma janela bem mais larga que o limite de leitura.
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const chave = Key('conteudo');
      await tester.pumpWidget(
        const MaterialApp(
          home: DevocionalLarguraDeLeitura(
            maxWidth: 720,
            child: ColoredBox(
              key: chave,
              color: Colors.red,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(chave)).width, 720);
      // Centralizado: a mesma folga (240) sobra de cada lado dos 1200 disponíveis.
      expect(tester.getTopLeft(find.byKey(chave)).dx, 240);
    });

    testWidgets(
      'numa janela estreita, como no celular, não encolhe o conteúdo',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const chave = Key('conteudo');
        await tester.pumpWidget(
          const MaterialApp(
            home: DevocionalLarguraDeLeitura(
              maxWidth: 720,
              child: ColoredBox(
                key: chave,
                color: Colors.red,
                child: SizedBox.expand(),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(chave)).width, 400);
        expect(tester.getTopLeft(find.byKey(chave)).dx, 0);
      },
    );
  });

  group('confirmarRemocao', () {
    Widget appComBotao(
      void Function(bool) aoConfirmar, {
      bool comNota = false,
    }) {
      return MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              aoConfirmar(
                await confirmarRemocao(
                  context,
                  referencia: 'Gênesis 1:1',
                  comNota: comNota,
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      );
    }

    testWidgets('cancelar não remove', (tester) async {
      bool? resultado;
      await tester.pumpWidget(appComBotao((r) => resultado = r));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Remover dos favoritos?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(resultado, isFalse);
    });

    testWidgets('confirmar remove, e o aviso muda quando há anotação', (
      tester,
    ) async {
      bool? resultado;
      await tester.pumpWidget(appComBotao((r) => resultado = r, comNota: true));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('a anotação serão removidos'), findsOneWidget);
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();

      expect(resultado, isTrue);
    });
  });

  group('DevocionalLivrosEscolhidos', () {
    const seteLivros = [
      'genesis',
      'exodo',
      'levitico',
      'numeros',
      'deuteronomio',
      'josue',
      'juizes',
    ];

    Widget appComLivros(List<String> livros) {
      return MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DevocionalLivrosEscolhidos(
              livros: livros,
              aoRemover: (slug) => setState(() => livros.remove(slug)),
              aoRestaurar: (slugs, indice) => setState(() {
                var ponto = indice;
                if (ponto < 0) ponto = 0;
                if (ponto > livros.length) ponto = livros.length;
                for (final slug in slugs) {
                  if (!livros.contains(slug)) {
                    livros.insert(ponto, slug);
                    ponto++;
                  }
                }
              }),
            ),
          ),
        ),
      );
    }

    testWidgets('com 7+ livros, colapsa no resumo e expande em Ver todos', (
      tester,
    ) async {
      await tester.pumpWidget(appComLivros([...seteLivros]));
      await tester.pumpAndSettle();

      expect(find.text('7 livros: Gênesis…Juízes'), findsOneWidget);
      expect(find.text('Ver todos (7)'), findsOneWidget);
      expect(find.text('7 · Juízes'), findsNothing);

      await tester.tap(find.text('Ver todos (7)'));
      await tester.pumpAndSettle();

      expect(find.text('7 · Juízes'), findsOneWidget);
      expect(find.text('Ver menos'), findsOneWidget);
    });

    testWidgets('remover um chip mostra Desfazer, que recoloca no ponto', (
      tester,
    ) async {
      await tester.pumpWidget(appComLivros(['genesis', 'exodo']));
      await tester.pumpAndSettle();

      // O excluir do chip é só-ícone: pega pelo nome acessível, que é o
      // que o leitor de tela anuncia.
      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();

      expect(find.text('Gênesis removido.'), findsOneWidget);
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(find.text('1 · Gênesis'), findsOneWidget);
      expect(find.text('2 · Êxodo'), findsOneWidget);
    });

    testWidgets('Limpar tira todos e o Desfazer traz de volta', (tester) async {
      await tester.pumpWidget(appComLivros(['genesis', 'exodo']));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      expect(find.text('2 livros removidos.'), findsOneWidget);
      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(find.text('1 · Gênesis'), findsOneWidget);
      expect(find.text('2 · Êxodo'), findsOneWidget);
    });
  });
}
