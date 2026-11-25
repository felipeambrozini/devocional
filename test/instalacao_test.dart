import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/instalacao.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instalação controlada pelo teste: o navegador de verdade só existe na web.
class _InstalacaoFalsa extends InstalacaoDoApp {
  _InstalacaoFalsa({
    this.disponivel = true,
    this.temConviteDoNavegador = false,
    this.aceita = true,
    this.falha = false,
  });

  final bool falha;

  @override
  bool disponivel;

  @override
  bool temConviteDoNavegador;

  final bool aceita;
  int pedidos = 0;

  @override
  Future<bool> pedir() async {
    pedidos++;
    temConviteDoNavegador = false;
    notifyListeners();
    if (falha) throw StateError('prompt() recusado pelo navegador');
    return aceita;
  }

  void mudar({bool? disponivel}) {
    if (disponivel != null) this.disponivel = disponivel;
    notifyListeners();
  }
}

Widget _app(InstalacaoDoApp instalacao) => MaterialApp(
  home: Scaffold(body: TabernaculoItemDeInstalar(instalacao: instalacao)),
);

Widget _hoje(Estado estado, InstalacaoDoApp instalacao) => MaterialApp(
  home: Scaffold(
    // Numa lista, como na Hoje: com fonte grande o cartão passa da tela e
    // rola, em vez de estourar.
    body: ListenableBuilder(
      listenable: estado,
      builder: (context, _) => ListView(
        children: [
          TabernaculoCartaoDeInstalar(estado: estado, instalacao: instalacao),
        ],
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('cartão da Hoje', () {
    testWidgets('aparece, instala pelo convite e some com Agora não', (
      tester,
    ) async {
      final estado = Estado(await SharedPreferences.getInstance());
      final instalacao = _InstalacaoFalsa(temConviteDoNavegador: true);
      await tester.pumpWidget(_hoje(estado, instalacao));
      expect(find.text('Instalar como app'), findsOneWidget);

      await tester.tap(find.text('Instalar'));
      await tester.pump();
      expect(instalacao.pedidos, 1);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agora não'));
      await tester.pump();
      expect(find.text('Instalar como app'), findsNothing);
      expect(estado.conviteDeInstalarDispensado, isTrue);
    });

    testWidgets('atende às diretrizes de toque, rótulo e contraste', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(_hoje(estado, _InstalacaoFalsa()));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('com fonte em 200%, os botões quebram linha sem estourar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: _hoje(estado, _InstalacaoFalsa()),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Instalar'), findsOneWidget);
    });

    testWidgets('dispensado fica dispensado no próximo carregamento', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'convite_de_instalar_dispensado': true,
      });
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(_hoje(estado, _InstalacaoFalsa()));
      expect(find.text('Instalar como app'), findsNothing);
    });

    testWidgets('fora da web, ou já instalado, não aparece', (tester) async {
      final estado = Estado(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        _hoje(estado, _InstalacaoFalsa(disponivel: false)),
      );
      expect(find.text('Instalar como app'), findsNothing);
    });
  });

  test('fora da web nunca oferece instalar', () async {
    final instalacao = InstalacaoDoApp.instancia;
    expect(instalacao.disponivel, isFalse);
    expect(instalacao.temConviteDoNavegador, isFalse);
    expect(await instalacao.pedir(), isFalse);
  });

  testWidgets('some quando não está disponível', (tester) async {
    final instalacao = _InstalacaoFalsa(disponivel: false);
    await tester.pumpWidget(_app(instalacao));
    expect(find.text('Instalar como app'), findsNothing);

    instalacao.mudar(disponivel: true);
    await tester.pump();
    expect(find.text('Instalar como app'), findsOneWidget);
  });

  testWidgets('com convite do navegador, pede a ele e avisa o aceite', (
    tester,
  ) async {
    final instalacao = _InstalacaoFalsa(temConviteDoNavegador: true);
    await tester.pumpWidget(_app(instalacao));

    await tester.tap(find.text('Instalar como app'));
    await tester.pump();

    expect(instalacao.pedidos, 1);
    expect(find.text('Tabernáculo instalado'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    // Deixa a snackbar fechar sozinha: o timer dela não pode sobrar.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('recusado no navegador, não avisa nada', (tester) async {
    final instalacao = _InstalacaoFalsa(
      temConviteDoNavegador: true,
      aceita: false,
    );
    await tester.pumpWidget(_app(instalacao));

    await tester.tap(find.text('Instalar como app'));
    await tester.pump();

    expect(instalacao.pedidos, 1);
    expect(find.text('Tabernáculo instalado'), findsNothing);
  });

  testWidgets('se a janela do navegador falha, mostra o caminho pelo menu', (
    tester,
  ) async {
    final instalacao = _InstalacaoFalsa(
      temConviteDoNavegador: true,
      falha: true,
    );
    await tester.pumpWidget(_app(instalacao));

    await tester.tap(find.text('Instalar como app'));
    await tester.pumpAndSettle();

    expect(instalacao.pedidos, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('sem convite, mostra o caminho pelo menu do sistema', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final instalacao = _InstalacaoFalsa();
    await tester.pumpWidget(_app(instalacao));

    await tester.tap(find.text('Instalar como app'));
    await tester.pumpAndSettle();

    expect(instalacao.pedidos, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Adicionar à Tela de Início'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  test('lembretes pedem instalar só no iPhone fora do app instalado', () {
    final naAba = _InstalacaoFalsa();
    final instalado = _InstalacaoFalsa(disponivel: false);
    expect(lembretesPedemInstalar(naAba, TargetPlatform.iOS), isTrue);
    expect(lembretesPedemInstalar(instalado, TargetPlatform.iOS), isFalse);
    expect(lembretesPedemInstalar(naAba, TargetPlatform.android), isFalse);
    expect(lembretesPedemInstalar(naAba, TargetPlatform.macOS), isFalse);
    // Fora da web (Android/iOS nativos), nunca.
    expect(
      lembretesPedemInstalar(InstalacaoDoApp.instancia, TargetPlatform.iOS),
      isFalse,
    );
  });

  test('os passos do iPhone levam aos lembretes', () {
    expect(passosParaInstalar(TargetPlatform.iOS).last, contains('lembretes'));
  });

  test('cada sistema tem o próprio caminho', () {
    expect(
      passosParaInstalar(TargetPlatform.iOS).join(' '),
      contains('Compartilhar'),
    );
    expect(
      passosParaInstalar(TargetPlatform.android).join(' '),
      contains('Instalar app'),
    );
    expect(
      passosParaInstalar(TargetPlatform.macOS).join(' '),
      contains('Adicionar ao Dock'),
    );
    expect(
      passosParaInstalar(TargetPlatform.windows).join(' '),
      contains('barra de endereço'),
    );
  });
}
