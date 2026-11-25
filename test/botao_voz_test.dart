import 'package:devocional/dados/audio_offline.dart';
import 'package:devocional/dados/voz.dart';
import 'package:devocional/funcoes/aviso.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Voz.instancia.parar();
    Voz.baseUrlForTest = 'https://test.audio';
    // Evita bater no path_provider de verdade: sem plugin registrado em
    // teste de widget, a checagem de disponibilidade nunca resolveria.
    AudioOffline.temOfflineParaTeste = (_) => false;
  });
  tearDown(() {
    Voz.baseUrlForTest = null;
    AudioOffline.temOfflineParaTeste = null;
  });

  Widget montar({String chave = 'capitulo:joao.3'}) => MaterialApp(
    home: Scaffold(body: TabernaculoBotaoDeVoz(chave: chave)),
  );

  group('TabernaculoBotaoDeVoz', () {
    testWidgets('em repouso mostra "Ouvir" e anuncia o rótulo completo', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(montar());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ouvir'), findsOneWidget);
      expect(find.bySemanticsLabel('Ouvir na voz de Spurgeon'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('sem base de áudio configurada, o botão não aparece', (
      tester,
    ) async {
      Voz.baseUrlForTest = '';
      await tester.pumpWidget(montar());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ouvir'), findsNothing);
    });

    testWidgets('com base configurada mas o arquivo ainda não gerado (HEAD não '
        'encontra), o botão não aparece', (tester) async {
      Voz.disponibilidadeRemotaParaTeste = false;
      addTearDown(() => Voz.disponibilidadeRemotaParaTeste = null);
      await tester.pumpWidget(montar());
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Ouvir'), findsNothing);
    });

    testWidgets(
      'sem rede para checar (não sem áudio), o botão aparece desabilitado '
      'em vez de sumir',
      (tester) async {
        Voz.semRedeParaTeste = true;
        addTearDown(() => Voz.semRedeParaTeste = false);
        await tester.pumpWidget(montar());
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Sem conexão. Toque para tentar'), findsOneWidget);
        expect(find.text('Ouvir'), findsNothing);
      },
    );

    testWidgets('com o que se ouve, o rótulo e o sem-rede dizem o quê', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TabernaculoBotaoDeVoz(
              chave: 'comentario:joao.1.1',
              oQueOuvir: 'o comentário',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Ouvir o comentário'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ouvir o comentário na voz de Spurgeon'),
        findsOneWidget,
      );
      semantica.dispose();

      Voz.semRedeParaTeste = true;
      addTearDown(() => Voz.semRedeParaTeste = false);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TabernaculoBotaoDeVoz(
              chave: 'comentario:joao.1.2',
              oQueOuvir: 'o comentário',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Áudio do comentário sem conexão. Toque para tentar'),
        findsOneWidget,
      );
    });

    // A fonte de teste desenha cada letra como um quadrado do tamanho da
    // fonte, então medir se "Ouvir o comentário" cabe em 2x não diria nada
    // sobre a Montserrat de verdade. O que se guarda aqui é a regra: em
    // repouso o rótulo quebra em até duas linhas e não corta com reticências.
    testWidgets('em repouso o rótulo quebra linha em vez de cortar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TabernaculoBotaoDeVoz(
              chave: 'comentario:joao.1.1',
              oQueOuvir: 'o comentário',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final rotulo = tester.renderObject<RenderParagraph>(
        find.text('Ouvir o comentário'),
      );
      expect(rotulo.maxLines, 2);
      expect(rotulo.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('o erro de leitura oferece "Tentar de novo"', (tester) async {
      // Disponível na checagem (default de teste = tudo disponível), mas
      // sem base real pra tocar de fato — simula o arquivo ter sumido do
      // Storage entre a checagem e o toque.
      await tester.pumpWidget(montar());
      await tester.pump(const Duration(milliseconds: 500));
      Voz.baseUrlForTest = '';
      await tester.tap(find.text('Ouvir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('não disponível'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      await tester.pump(duracaoDeErro);
      await tester.pumpAndSettle();
    });
  });
}
