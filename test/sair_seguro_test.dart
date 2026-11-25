import 'dart:async';

import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sair da conta só depois de tudo confirmado na nuvem (ver `Nuvem.sair` e
/// `sairEmOrdem` em `lib/dados/nuvem.dart`).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Um aparelho com um pouco de cada dado pessoal e alguns ajustes.
  Future<Estado> estadoCheio() async {
    final estado = await Estado.abrir();
    await estado.alternarFavorito('joao', 3, 16);
    await estado.definirNota('romanos', 8, 28, 'nota pessoal');
    await estado.alternarLido('2026-11-20');
    await estado.registrarLeitura('joao', 3);
    final plano = await estado.criarPlano(
      titulo: 'Plano pessoal',
      livros: const ['marcos'],
      dias: 4,
    );
    await estado.alternarLidoNoPlano(plano.id, 1);
    await estado.novaConversa('spurgeon', titulo: 'conversa pessoal');
    await estado.definirLembretesAtivos(true);
    await estado.definirHorariosDeLembrete(
      minutosManha: 7 * 60 + 15,
      minutosPromessas: 8 * 60,
      minutosLeitura: 9 * 60 + 30,
      minutosNoite: 21 * 60,
    );
    await estado.leituraDeLivros.registrarPosicao('alfabeto_de_ouro', 2, 0.5);
    await estado.leituraDeLivros.alternarLido('alfabeto_de_ouro', 1);
    await estado.leituraDeLivros.concluir('outro_livro');
    await estado.leituraDeLivros.alternarDestaque('alfabeto_de_ouro', 2, 3);
    await estado.progressoDosDias.registrar('2026-11-21', 'joao/4');
    // Ajustes do aparelho, que ficam depois de sair.
    await estado.definirEscalaDeLeitura(1.3);
    await estado.registrarConsentimentoDaNuvem();
    await estado.registrarMaiorDeIdade(true);
    await estado.dispensarAjuda();
    return estado;
  }

  /// As cinco sincronias que a `Nuvem` liga, com um `empurrar` de teste.
  List<Sincronia> cincoSincronias(
    Estado estado,
    Future<void> Function(String copia) empurrar,
  ) => [
    Sincronia(estado: estado, puxar: () async => null, empurrar: empurrar),
    Sincronia(
      estado: estado,
      serializar: estado.serializarConversas,
      fundir: estado.fundirConversas,
      puxar: () async => null,
      empurrar: empurrar,
    ),
    Sincronia(
      estado: estado,
      serializar: estado.serializarLembretes,
      fundir: (r) async => estado.fundirLembretes(r),
      puxar: () async => null,
      empurrar: empurrar,
    ),
    Sincronia(
      estado: estado,
      serializar: estado.serializarPlanos,
      fundir: estado.fundirPlanos,
      puxar: () async => null,
      empurrar: empurrar,
    ),
    Sincronia(
      estado: estado,
      serializar: estado.serializarLeituraDeLivros,
      fundir: estado.fundirLeituraDeLivros,
      puxar: () async => null,
      empurrar: empurrar,
    ),
  ];

  group('garantirNaNuvem', () {
    test('garantirNaNuvem envia o estado atual mesmo sem pendência', () async {
      final estado = await Estado.abrir();
      var falhar = true;
      final enviados = <String>[];
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => null,
        empurrar: (copia) async {
          if (falhar) throw Exception('sem rede');
          enviados.add(copia);
        },
        atraso: Duration.zero,
      );
      await sincronia.comecar();
      await estado.alternarFavorito('joao', 3, 16);
      // O envio do debounce falha e nada fica na fila: hoje só a próxima
      // mudança tentaria de novo.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(enviados, isEmpty);

      falhar = false;
      await sincronia.garantirNaNuvem();

      expect(enviados, [estado.exportar()]);
      sincronia.parar();
    });

    test('garantirNaNuvem não reenvia o que a conta já confirmou', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito('joao', 3, 16);
      var envios = 0;
      final sincronia = Sincronia(
        estado: estado,
        // Conta em dia: subir de novo só arriscaria pisar num envio mais
        // novo de outro aparelho.
        puxar: () async => estado.exportar(),
        empurrar: (_) async => envios++,
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      await sincronia.garantirNaNuvem();

      expect(envios, 0);
      sincronia.parar();
    });

    test('garantirNaNuvem propaga a falha do envio', () async {
      final estado = await Estado.abrir();
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => null,
        empurrar: (_) async => throw Exception('sem rede'),
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      await expectLater(sincronia.garantirNaNuvem(), throwsException);
      sincronia.parar();
    });

    test('garantirNaNuvem lança se nunca conseguiu puxar a conta', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito('joao', 3, 16);
      var envios = 0;
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => throw Exception('sem rede'),
        empurrar: (_) async => envios++,
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      await expectLater(sincronia.garantirNaNuvem(), throwsException);
      expect(envios, 0, reason: 'sem puxar antes, o envio apagaria a conta');
      sincronia.parar();
    });

    test('garantirNaNuvem estoura o prazo de um envio que não volta', () async {
      final estado = await Estado.abrir();
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => null,
        empurrar: (_) => Completer<void>().future,
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      await expectLater(
        sincronia.garantirNaNuvem(prazo: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
      sincronia.parar();
    });
  });

  group('sair', () {
    test('sair não limpa nem desloga se um envio falha', () async {
      final estado = await estadoCheio();
      final copiaAntes = estado.exportar();
      final sincronias = cincoSincronias(estado, (_) async {
        throw Exception('sem rede');
      });
      for (final s in sincronias) {
        await s.comecar();
      }
      var deslogou = false;

      await expectLater(
        sairEmOrdem(
          garantir: () async {
            await Future.wait([
              for (final s in sincronias) s.garantirNaNuvem(),
            ]);
          },
          limpar: estado.limparDadosPessoais,
          deslogar: () async => deslogou = true,
        ),
        throwsA(isA<SairDaContaFalhou>()),
      );

      expect(deslogou, isFalse);
      expect(estado.exportar(), copiaAntes);
      expect(estado.planosDoUsuario, hasLength(1));
      expect(estado.leituraDeLivros.todosOsDestaques, hasLength(1));
      for (final s in sincronias) {
        s.parar();
      }
    });

    test(
      'sair com tudo confirmado limpa o pessoal e mantém os ajustes',
      () async {
        final estado = await estadoCheio();
        var avisos = 0;
        estado.addListener(() => avisos++);

        await estado.limparDadosPessoais();

        expect(avisos, 1, reason: 'notifica uma vez só');
        void conferirVazio(Estado e) {
          expect(e.marcacoes, isEmpty);
          expect(e.diasLidosEmTodosOsAnos, 0);
          expect(e.ultimaLeitura, isNull);
          expect(e.planosDoUsuario, isEmpty);
          expect(e.diasLidosDoPlano('qualquer'), 0);
          expect(e.conversasDe('spurgeon'), isEmpty);
          expect(e.lembretesAtivos, isFalse);
          expect(e.minutosLembreteManha, Estado.minutosPadraoManha);
          expect(e.minutosLembreteNoite, Estado.minutosPadraoNoite);
          expect(e.leituraDeLivros.livrosEmLeitura, isEmpty);
          expect(e.leituraDeLivros.quantosLidos('alfabeto_de_ouro'), 0);
          expect(e.leituraDeLivros.vezesConcluido('outro_livro'), 0);
          expect(e.leituraDeLivros.todosOsDestaques, isEmpty);
          expect(e.progressoDosDias.lidosDoDia('2026-11-21'), isEmpty);
          expect(e.escalaDeLeitura, 1.3);
          expect(e.consentimentoDaNuvem, isTrue);
          expect(e.maiorDeIdade, isTrue);
          expect(e.ajudaDispensada, isTrue);
        }

        conferirVazio(estado);
        // E nas prefs: reabrir o app não traz nada de volta.
        conferirVazio(await Estado.abrir());
      },
    );

    test(
      'depois de limpar, entrar com outra conta não sobe nada da anterior',
      () async {
        final estado = await estadoCheio();
        await estado.limparDadosPessoais();

        SharedPreferences.setMockInitialValues({});
        final novo = await Estado.abrir();
        // Os serializadores do Estado são os mesmos que a Nuvem passa às
        // cinco sincronias: depois da limpeza, sobem o mesmo que um aparelho
        // novo.
        expect(estado.exportar(), novo.exportar());
        expect(estado.serializarConversas(), novo.serializarConversas());
        expect(estado.serializarLembretes(), novo.serializarLembretes());
        expect(estado.serializarPlanos(), novo.serializarPlanos());
        expect(
          estado.serializarLeituraDeLivros(),
          novo.serializarLeituraDeLivros(),
        );
      },
    );
  });
}
