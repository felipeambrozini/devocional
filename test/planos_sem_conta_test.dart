import 'package:devocional/controladores/leitor_de_livro_controlador.dart';
import 'package:devocional/controladores/novo_plano_controlador.dart';
import 'package:devocional/controladores/plano_controlador.dart';
import 'package:devocional/dados/dia_da_leitura.dart';
import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:devocional/dados/planos.dart';
import 'package:devocional/estilo/tema.dart';
import 'package:devocional/funcoes/marcar_dia_da_leitura.dart';
import 'package:devocional/telas/meu_plano.dart';
import 'package:devocional/telas/novo_plano.dart';
import 'package:devocional/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Os planos, locais ou compartilhados, e A Vida de Jesus só existem com
/// conta: nenhum caminho grava um plano sem ela (a tela de um plano, o novo
/// plano, o cartão da Hoje e o fim do capítulo aberto por um dia de plano).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    Nuvem.instancia.logadoForcado = null;
    Nuvem.instancia.carregandoContaForcado = null;
  });

  Future<Estado> abrir() async => Estado(await SharedPreferences.getInstance());

  Future<PlanoDoUsuario> planoLocal(Estado estado) => estado.criarPlano(
    titulo: 'Cartas',
    livros: const ['2joao', '3joao'],
    dias: 2,
  );

  Future<void> montar(
    WidgetTester tester,
    Estado estado,
    Widget tela, {
    Brightness brilho = Brightness.light,
  }) async {
    await tester.pumpWidget(
      EscopoDoEstado(
        estado: estado,
        child: MaterialApp(
          theme: construirTema(brilho: brilho),
          home: tela,
        ),
      ),
    );
    await tester.pump();
  }

  /// Um contexto qualquer com Scaffold, para as funções que mostram aviso.
  Future<BuildContext> contexto(WidgetTester tester) async {
    late BuildContext capturado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturado = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return capturado;
  }

  group('tela de um plano', () {
    testWidgets('plano local sem conta mostra o convite, sem dias', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      final plano = await planoLocal(estado);
      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.alternarLidoNoPlano(plano.id, 2);

      await montar(
        tester,
        estado,
        TelaDeUmPlano(estado: estado, planoId: plano.id, plano: plano),
      );

      expect(find.text('Entre para ver seus planos'), findsOneWidget);
      expect(find.byType(TabernaculoCartaoDeDia), findsNothing);
      expect(find.text('Fazer de novo'), findsNothing);
      expect(find.byTooltip('Opções do plano'), findsNothing);
    });

    testWidgets('A Vida de Jesus sem conta mostra o convite', (tester) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();

      await montar(
        tester,
        estado,
        TelaDeUmPlano(
          estado: estado,
          planoId: idDoPlanoDeJesus,
          plano: estado.planoDoUsuario(idDoPlanoDeJesus),
        ),
      );

      expect(find.text('Entre para ver seus planos'), findsOneWidget);
      expect(find.byType(TabernaculoCartaoDeDia), findsNothing);
    });

    testWidgets('restaurando a conta, a tela espera em vez de convidar', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      Nuvem.instancia.carregandoContaForcado = true;
      final estado = await abrir();
      final plano = await planoLocal(estado);

      await montar(
        tester,
        estado,
        TelaDeUmPlano(estado: estado, planoId: plano.id, plano: plano),
      );

      expect(find.byType(TabernaculoVerificandoConta), findsOneWidget);
      expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
      expect(find.byType(TabernaculoCartaoDeDia), findsNothing);
    });

    testWidgets('com conta, o plano local mostra os dias', (tester) async {
      Nuvem.instancia.logadoForcado = true;
      final estado = await abrir();
      final plano = await planoLocal(estado);

      await montar(
        tester,
        estado,
        TelaDeUmPlano(estado: estado, planoId: plano.id, plano: plano),
      );

      expect(find.byType(TabernaculoCartaoDeDia), findsNWidgets(2));
      expect(find.byType(TabernaculoCartaoDeEntrar), findsNothing);
    });

    testWidgets('sem conta, o controlador não marca dia de plano local', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      final plano = await planoLocal(estado);
      final controlador = PlanoControlador(
        estado: estado,
        planoId: plano.id,
        plano: plano,
      );
      addTearDown(controlador.dispose);
      final ctx = await contexto(tester);

      await controlador.alternarDia(ctx, 1);
      await tester.pump();

      expect(estado.foiLidoNoPlano(plano.id, 1), isFalse);
      expect(find.text('Entre na sua conta para marcar dias.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sem conta, Fazer de novo não zera o plano concluído', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      final plano = await planoLocal(estado);
      await estado.alternarLidoNoPlano(plano.id, 1);
      await estado.alternarLidoNoPlano(plano.id, 2);
      final controlador = PlanoControlador(
        estado: estado,
        planoId: plano.id,
        plano: plano,
      );
      addTearDown(controlador.dispose);
      final ctx = await contexto(tester);

      await controlador.fazerDeNovo(ctx);
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(estado.diasLidosDoPlano(plano.id), 2);
    });
  });

  group('novo plano', () {
    testWidgets('sem conta, o formulário dá lugar ao convite', (tester) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();

      await montar(tester, estado, TelaNovoPlano(estado: estado));

      expect(find.text('Entre para criar seus planos'), findsOneWidget);
      expect(find.text('Criar plano'), findsNothing);
    });

    testWidgets('restaurando a conta, o novo plano espera', (tester) async {
      Nuvem.instancia.logadoForcado = false;
      Nuvem.instancia.carregandoContaForcado = true;
      final estado = await abrir();

      await montar(tester, estado, TelaNovoPlano(estado: estado));

      expect(find.byType(TabernaculoVerificandoConta), findsOneWidget);
      expect(find.text('Criar plano'), findsNothing);
    });

    testWidgets('sem conta, criar não grava plano nenhum', (tester) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      final controlador = NovoPlanoControlador(estado: estado)
        ..livros.add('2joao');
      addTearDown(controlador.dispose);
      controlador.dias.text = '1';
      final ctx = await contexto(tester);

      await controlador.criar(ctx);

      expect(estado.planosParaExibir.where((p) => !p.fixo), isEmpty);
    });
  });

  testWidgets('sem conta, o cartão de plano da Hoje não marca o dia', (
    tester,
  ) async {
    Nuvem.instancia.logadoForcado = false;
    final estado = await abrir();
    final plano = await planoLocal(estado);
    await estado.alternarLidoNoPlano(plano.id, 1);

    await montar(
      tester,
      estado,
      Scaffold(body: TabernaculoPlanosEmAndamento(estado: estado)),
    );
    await tester.tap(find.byType(TabernaculoBotaoDeLido));
    await tester.pump();

    expect(estado.foiLidoNoPlano(plano.id, 2), isFalse);
  });

  group('fim do capítulo aberto por um dia de plano', () {
    testWidgets('sem conta, o dia de plano local não é marcado', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      final plano = await planoLocal(estado);
      final ctx = await contexto(tester);

      await marcarDiaDaLeituraAoTerminar(
        ctx,
        estado,
        DiaDaLeitura.doPlano(plano.id, 1, plano.diasDoPlano.first.itens)!,
      );
      await tester.pump();

      expect(estado.foiLidoNoPlano(plano.id, 1), isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sem conta, o capítulo lido não entra no andamento do dia', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      final plano = await planoLocal(estado);
      final dia = DiaDaLeitura.doPlano(
        plano.id,
        1,
        plano.diasDoPlano.first.itens,
      )!;
      final capitulo = dia.capitulos.first.split('.');
      final ctx = await contexto(tester);

      await registrarCapituloLidoDoDia(
        ctx,
        estado,
        dia,
        capitulo.first,
        int.parse(capitulo.last),
      );

      expect(estado.progressoDosDias.lidosDoDia(dia.chaveDoProgresso), isEmpty);
      expect(estado.foiLidoNoPlano(plano.id, 1), isFalse);
    });
  });

  testWidgets(
    'capítulo aberto antes da conta grava a posição quando ela chega',
    (tester) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      const slug = 'somente_pela_graca';
      final controlador = LeitorDeLivroControlador(
        estado: estado,
        slug: slug,
        capitulo: 2,
      );
      addTearDown(controlador.dispose);

      controlador.iniciar();
      expect(estado.leituraDeLivros.posicaoDe(slug), isNull);

      Nuvem.instancia.logadoForcado = true;
      Nuvem.instancia.avisarOuvintes();

      expect(estado.leituraDeLivros.posicaoDe(slug)?.capitulo, 2);
    },
  );

  for (final brilho in Brightness.values) {
    testWidgets('convites de plano sem conta no tema ${brilho.name}', (
      tester,
    ) async {
      Nuvem.instancia.logadoForcado = false;
      final estado = await abrir();
      final plano = await planoLocal(estado);

      for (final tela in [
        TelaDeUmPlano(estado: estado, planoId: plano.id, plano: plano),
        TelaNovoPlano(estado: estado),
      ]) {
        await montar(tester, estado, tela, brilho: brilho);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
    });
  }
}
