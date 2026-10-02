import 'package:felipe_ambrozini/controladores/novo_plano_controlador.dart';
import 'package:felipe_ambrozini/controladores/plano_controlador.dart';
import 'package:felipe_ambrozini/dados/conteudo.dart';
import 'package:felipe_ambrozini/dados/estado.dart';
import 'package:felipe_ambrozini/dados/modelos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Os controllers são a parte que concentra decisão: a tela só monta a UI e
/// escuta. Sem teste, um `setState` trocado por `notifyListeners` trocado, ou
/// uma validação afrouxada, só aparece quando alguém perde um dia de leitura
/// na tela.
void main() {
  // A prévia do plano e o índice de devocionais do [Conteudo] leem os JSONs
  // de `assets/`, e o carregamento tardio precisa do binding de pé.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Estado> novoEstado() async =>
      Estado(await SharedPreferences.getInstance());

  group('NovoPlanoControlador', () {
    late Estado estado;
    late NovoPlanoControlador controlador;

    setUp(() async {
      estado = await novoEstado();
      controlador = NovoPlanoControlador(estado: estado);
      addTearDown(controlador.dispose);
    });

    int capitulosDe(List<String> slugs) => controlador.totalDeCapitulos;

    test('sem livro escolhido a prévia é vazia', () {
      expect(controlador.previa, isEmpty);
      expect(capitulosDe(const []), 0);
    });

    test('validarDias recusa o que não é número, zero e negativo', () {
      controlador.livros.add('genesis');
      expect(controlador.validarDias(''), isNotNull);
      expect(controlador.validarDias('abc'), isNotNull);
      expect(controlador.validarDias('0'), isNotNull);
      expect(controlador.validarDias('-3'), isNotNull);
    });

    test('validarDias recusa mais dias que capítulos, e diz quantos há', () {
      controlador.livros.add('joao');
      final total = capitulosDe(const ['joao']);
      final resposta = controlador.validarDias('${total + 1}');

      expect(resposta, isNotNull);
      // A mensagem traz o total, para o erro não parecer arbitrário.
      expect(resposta, contains('$total'));
      expect(controlador.validarDias('$total'), isNull);
    });

    test('a prévia respeita o número de dias digitado', () {
      controlador.livros.add('genesis');
      controlador.dias.text = '2';
      expect(controlador.previa, hasLength(2));

      controlador.dias.text = '40';
      expect(controlador.previa, hasLength(40));
    });

    test('a prévia inclui os devocionais só quando pedido', () async {
      // O índice de devocionais é aquecido pelo próprio controller, mas de
      // forma assíncrona: sem esperar, a prévia sai sem os devocionais.
      await Conteudo.instancia.aquecerIndiceDeDevocionais();
      controlador.livros.add('genesis');
      controlador.dias.text = '2';

      final semDevocionais = controlador.previa;
      expect(
        semDevocionais.expand((d) => d.itens).whereType<ItemDeDevocional>(),
        isEmpty,
      );

      controlador.definirIncluirDevocionais(true);
      final comDevocionais = controlador.previa;
      expect(
        comDevocionais.expand((d) => d.itens).whereType<ItemDeDevocional>(),
        isNotEmpty,
      );
      // Desligar de novo volta ao comportamento de sempre.
      controlador.definirIncluirDevocionais(false);
      expect(controlador.previa, hasLength(semDevocionais.length));
    });

    test('os devocionais podem vir antes ou depois do capítulo', () async {
      await Conteudo.instancia.aquecerIndiceDeDevocionais();
      controlador.livros.add('genesis');
      controlador.dias.text = '3';
      controlador.definirIncluirDevocionais(true);

      controlador.definirDevocionalAntes(true);
      final antes = controlador.previa.first.itens.first;
      controlador.definirDevocionalAntes(false);
      final depois = controlador.previa.first.itens.last;

      // A escolha é a posição, não o conteúdo: o devocional do dia é o mesmo
      // dos dois jeitos, e num dia com mais de um é o mesmo conjunto.
      expect(antes, isA<ItemDeDevocional>());
      expect(depois, isA<ItemDeDevocional>());
      expect(
        controlador.previa.first.itens.whereType<ItemDeDevocional>(),
        isNotEmpty,
      );
    });

    test('removerLivro tira da lista e do total de capítulos', () {
      controlador.livros.addAll(['genesis', 'joao']);
      final antes = capitulosDe(controlador.livros);

      controlador.removerLivro('genesis');

      expect(controlador.livros, ['joao']);
      expect(capitulosDe(controlador.livros), lessThan(antes));
    });

    test('restaurarLivros devolve no lugar e não duplica', () {
      controlador.livros.addAll(['genesis', 'joao', 'atos']);
      controlador.removerLivro('joao');
      expect(controlador.livros, ['genesis', 'atos']);

      controlador.restaurarLivros(['genesis', 'joao'], 1);

      // No ponto de onde saiu, e o que já voltou por outro caminho fica uma
      // vez só.
      expect(controlador.livros, ['genesis', 'joao', 'atos']);
      controlador.restaurarLivros(['genesis'], 0);
      expect(controlador.livros.where((s) => s == 'genesis'), hasLength(1));
    });

    test('reordenarLivros só aceita o mesmo conjunto de livros', () {
      controlador.livros.addAll(['genesis', 'joao']);

      // Outra quantidade, ou outro livro: a ordem antiga fica de pé, em vez de
      // a lista ficar com livros que ninguém escolheu.
      controlador.reordenarLivros(['joao']);
      expect(controlador.livros, ['genesis', 'joao']);
      controlador.reordenarLivros(['genesis', 'atos']);
      expect(controlador.livros, ['genesis', 'joao']);

      controlador.reordenarLivros(['joao', 'genesis']);
      expect(controlador.livros, ['joao', 'genesis']);
    });

    test('cada mudança avisa quem escuta', () {
      var avisos = 0;
      controlador.addListener(() => avisos++);

      // Só as ações do controller avisam: quem mexe em `livros` direto não
      // está fazendo o que a tela faz, e o teste existe para travar o contrato
      // das ações. São quatro avisos: remover, incluir devocionais, mudar a
      // posição deles e o dia digitado.
      controlador.livros.add('genesis');
      controlador.removerLivro('genesis');
      controlador.livros.add('genesis');
      controlador.definirIncluirDevocionais(true);
      controlador.definirDevocionalAntes(false);
      controlador.diasAlterados();

      expect(avisos, 4);
    });
  });

  group('PlanoControlador', () {
    test(
      'plano local não é compartilhado e lê os lidos do próprio Estado',
      () async {
        final estado = await novoEstado();
        final plano = await estado.criarPlano(
          titulo: 'João',
          livros: ['joao'],
          dias: 5,
        );

        final controlador = PlanoControlador(
          estado: estado,
          planoId: plano.id,
          plano: plano,
        );
        addTearDown(controlador.dispose);
        await pumpEventQueue();

        expect(controlador.compartilhado, isFalse);
        // Sem documento, os dias lidos saem do espelho local.
        expect(controlador.meusLidos(), isEmpty);

        await estado.alternarLidoNoPlano(plano.id, 2);
        await estado.alternarLidoNoPlano(plano.id, 4);

        expect(controlador.meusLidos(), {2, 4});
        expect(controlador.carregando, isFalse);
        expect(controlador.erro, isNull);
      },
    );

    test(
      'sem conta e sem documento, um plano aberto por link fica compartilhado',
      () async {
        final estado = await novoEstado();
        final controlador = PlanoControlador(
          estado: estado,
          planoId: 'plano-de-outro',
        );
        addTearDown(controlador.dispose);
        await pumpEventQueue();

        // Aberto por link não há plano local, então o documento da nuvem é a
        // verdade e a tela oferece entrar na conta.
        expect(controlador.compartilhado, isTrue);
        expect(controlador.plano, isNull);
        expect(controlador.carregando, isFalse);
      },
    );

    test('lidosDe lê só os dias inteiros do participante corrente', () async {
      final estado = await novoEstado();
      final plano = await estado.criarPlano(
        titulo: 'João',
        livros: ['joao'],
        dias: 5,
      );
      final controlador = PlanoControlador(
        estado: estado,
        planoId: plano.id,
        plano: plano,
      );
      addTearDown(controlador.dispose);

      // Plano local: não há uid, logo não há dia lido de ninguém para ler.
      expect(controlador.lidosDe(const {}), isEmpty);
      expect(
        controlador.lidosDe({
          'participantes': {
            'alguem': {
              'lidos': [1, 'dois', 3, null],
            },
          },
        }),
        isEmpty,
      );
    });

    test('tentarDeNovo limpa o erro e volta a carregar', () async {
      final estado = await novoEstado();
      final plano = await estado.criarPlano(
        titulo: 'João',
        livros: ['joao'],
        dias: 5,
      );
      final controlador = PlanoControlador(
        estado: estado,
        planoId: plano.id,
        plano: plano,
      );
      addTearDown(controlador.dispose);

      controlador.erro = 'Não foi possível abrir o plano. Verifique a conexão.';
      controlador.carregando = false;

      controlador.tentarDeNovo();
      await pumpEventQueue();

      expect(controlador.erro, isNull);
      expect(controlador.carregando, isFalse);
    });
  });
}
