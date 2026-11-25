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

    test(
      'garantirNaNuvem puxa do servidor, funde e envia mesmo com o cache em dia',
      () async {
        final estado = await Estado.abrir();
        await estado.alternarFavorito('joao', 3, 16);
        // O que só o servidor tem (outro aparelho subiu depois): o cache
        // local do Firestore ainda diz que a conta está em dia.
        final doServidor = await () async {
          SharedPreferences.setMockInitialValues({});
          final outro = await Estado.abrir();
          await outro.alternarFavorito('joao', 3, 16);
          await outro.alternarFavorito('romanos', 8, 28);
          return outro.exportar();
        }();
        final enviados = <String>[];
        final sincronia = Sincronia(
          estado: estado,
          puxar: () async => estado.exportar(),
          puxarDoServidor: () async => doServidor,
          empurrar: (copia) async => enviados.add(copia),
          atraso: const Duration(seconds: 30),
        );
        await sincronia.comecar();
        expect(enviados, isEmpty, reason: 'pelo cache, nada a subir');

        await sincronia.garantirNaNuvem();

        expect(estado.marcacoes, hasLength(2), reason: 'fundiu o do servidor');
        expect(enviados, [estado.exportar()], reason: 'subiu a união');
        sincronia.parar();
      },
    );

    test(
      'garantirNaNuvem falha sem servidor, mesmo com o cache em dia',
      () async {
        final estado = await Estado.abrir();
        await estado.alternarFavorito('joao', 3, 16);
        var envios = 0;
        final sincronia = Sincronia(
          estado: estado,
          // O cache pode refletir uma escrita que o servidor nunca recebeu.
          puxar: () async => estado.exportar(),
          puxarDoServidor: () async => throw Exception('sem servidor'),
          empurrar: (_) async => envios++,
          atraso: const Duration(seconds: 30),
        );
        await sincronia.comecar();

        await expectLater(sincronia.garantirNaNuvem(), throwsException);
        expect(envios, 0);
        sincronia.parar();
      },
    );

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

  group('mudança durante a espera do Sair', () {
    test('a mudança sobe antes de limpar, nunca é apagada sem subir', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito('joao', 3, 16);
      final primeiro = Completer<void>();
      final enviados = <String>[];
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => null,
        empurrar: (copia) async {
          enviados.add(copia);
          if (enviados.length == 1) await primeiro.future;
        },
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();
      var deslogou = false;

      final saida = sairComSincronias(
        sincronias: [sincronia],
        pararSincronias: sincronia.parar,
        limparAparelho: estado.limparDadosPessoais,
        deslogar: () async => deslogou = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(enviados, hasLength(1));
      // A pessoa mexe enquanto o primeiro envio espera o servidor.
      await estado.definirNota('romanos', 8, 28, 'nota tardia');
      primeiro.complete();
      await saida;

      expect(enviados.last, contains('nota tardia'));
      expect(estado.marcacoes, isEmpty);
      expect(deslogou, isTrue);
    });

    test('mudança que não para de chegar faz o Sair falhar sem limpar', () async {
      final estado = await Estado.abrir();
      var dia = 10;
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => null,
        empurrar: (_) async {
          // Cada envio vem acompanhado de mais uma mudança.
          await estado.alternarLido('2026-11-${dia++}');
        },
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();
      var deslogou = false;

      await expectLater(
        sairComSincronias(
          sincronias: [sincronia],
          pararSincronias: sincronia.parar,
          limparAparelho: estado.limparDadosPessoais,
          deslogar: () async => deslogou = true,
        ),
        throwsA(isA<SairDaContaFalhou>()),
      );
      expect(deslogou, isFalse);
      expect(estado.diasLidosEmTodosOsAnos, greaterThan(0));
      sincronia.parar();
    });

    test('sincronia desligada faz o Sair falhar sem limpar', () async {
      final estado = await estadoCheio();
      final copiaAntes = estado.exportar();
      await expectLater(
        sairComSincronias(
          sincronias: [null],
          pararSincronias: () {},
          limparAparelho: estado.limparDadosPessoais,
          deslogar: () async {},
        ),
        throwsA(isA<SairDaContaFalhou>()),
      );
      expect(estado.exportar(), copiaAntes);
    });
  });

  group('parar() cerca as puxadas em andamento', () {
    test(
      'parar() durante o primeiro puxar: ao resolver, o Estado não muda e nenhum ouvinte fica',
      () async {
        final estado = await Estado.abrir();
        final remota = await () async {
          SharedPreferences.setMockInitialValues({});
          final outro = await Estado.abrir();
          await outro.alternarFavorito('romanos', 8, 28);
          return outro.exportar();
        }();
        final puxada = Completer<String?>();
        var envios = 0;
        final sincronia = Sincronia(
          estado: estado,
          puxar: () => puxada.future,
          empurrar: (_) async => envios++,
          atraso: Duration.zero,
        );
        final comecou = sincronia.comecar();
        sincronia.parar();
        puxada.complete(remota);
        await comecou;

        expect(estado.marcacoes, isEmpty, reason: 'a conta antiga não entra');
        await estado.alternarFavorito('joao', 3, 16);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(envios, 0, reason: 'nenhum ouvinte ficou pendurado');
      },
    );

    test(
      'parar() durante a retomada do puxar no envio: nada funde nem sobe',
      () async {
        final estado = await Estado.abrir();
        final remota = await () async {
          SharedPreferences.setMockInitialValues({});
          final outro = await Estado.abrir();
          await outro.alternarFavorito('romanos', 8, 28);
          return outro.exportar();
        }();
        var puxadas = 0;
        final retomada = Completer<String?>();
        var envios = 0;
        final sincronia = Sincronia(
          estado: estado,
          puxar: () {
            if (++puxadas == 1) throw Exception('sem rede');
            return retomada.future;
          },
          empurrar: (_) async => envios++,
          atraso: Duration.zero,
        );
        await sincronia.comecar();
        await estado.alternarFavorito('joao', 3, 16);
        await Future<void>.delayed(Duration.zero);
        expect(puxadas, 2, reason: 'o envio está esperando a retomada');

        sincronia.parar();
        retomada.complete(remota);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(estado.marcacoes, hasLength(1), reason: 'nada da conta entrou');
        expect(envios, 0);
      },
    );
  });

  group('rodada 2', () {
    test('o Sair não ressuscita um favorito removido antes da confirmação', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito('joao', 3, 16);
      final noServidor = estado.exportar();
      final enviados = <String>[];
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => noServidor,
        puxarDoServidor: () async => noServidor,
        empurrar: (copia) async => enviados.add(copia),
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      // Tira o favorito e sai dentro do debounce: o servidor ainda o tem.
      await estado.alternarFavorito('joao', 3, 16);
      expect(estado.marcacoes, isEmpty);
      await sincronia.garantirNaNuvem();

      expect(estado.marcacoes, isEmpty, reason: 'a fusão não o devolveu');
      expect(enviados, [estado.exportar()]);
      expect(enviados.single, isNot(contains('joao')));
      sincronia.parar();
    });

    test('o que chegou de outro aparelho ainda é fundido no Sair', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito('joao', 3, 16);
      final noCache = estado.exportar();
      final doServidor = await () async {
        SharedPreferences.setMockInitialValues({});
        final outro = await Estado.abrir();
        await outro.alternarFavorito('joao', 3, 16);
        await outro.alternarFavorito('romanos', 8, 28);
        return outro.exportar();
      }();
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => noCache,
        puxarDoServidor: () async => doServidor,
        empurrar: (_) async {},
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      await sincronia.garantirNaNuvem();

      expect(estado.marcacoes, hasLength(2));
      sincronia.parar();
    });

    test('_garantir parado durante a fusão não envia', () async {
      final estado = await Estado.abrir();
      final doServidor = await () async {
        SharedPreferences.setMockInitialValues({});
        final outro = await Estado.abrir();
        await outro.alternarFavorito('romanos', 8, 28);
        return outro.exportar();
      }();
      var envios = 0;
      late final Sincronia sincronia;
      sincronia = Sincronia(
        estado: estado,
        puxar: () async => null,
        puxarDoServidor: () async => doServidor,
        // O Sair parou esta sincronia enquanto a fusão gravava.
        fundir: (remota) async => sincronia.parar(),
        empurrar: (_) async => envios++,
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();

      await expectLater(sincronia.garantirNaNuvem(), throwsStateError);
      expect(envios, 0);
    });

    test('entre parar as sincronias e limpar não há espera', () async {
      final estado = await Estado.abrir();
      final sincronia = Sincronia(
        estado: estado,
        puxar: () async => null,
        empurrar: (_) async {},
        atraso: const Duration(seconds: 30),
      );
      await sincronia.comecar();
      final passos = <String>[];

      await sairComSincronias(
        sincronias: [sincronia],
        pararSincronias: () {
          sincronia.parar();
          passos.add('parar');
          // Qualquer espera entre parar e limpar deixaria isto rodar antes.
          scheduleMicrotask(() => passos.add('outra tarefa'));
        },
        limparAparelho: () async => passos.add('limpar'),
        deslogar: () async {},
      );

      expect(passos, ['parar', 'limpar', 'outra tarefa']);
    });

    test(
      'limparAoSair zera a memória antes de qualquer espera e cancela os lembretes depois',
      () async {
        final estado = await estadoCheio();
        var cancelamentos = 0;

        final limpeza = limparAoSair(
          estado,
          cancelarLembretes: () async => cancelamentos++,
        );
        // Sem await: a memória já está limpa.
        expect(estado.marcacoes, isEmpty);
        expect(estado.planosDoUsuario, isEmpty);
        expect(estado.leituraDeLivros.todosOsDestaques, isEmpty);
        await limpeza;

        expect(cancelamentos, 1, reason: 'os lembretes estavam ligados');
        expect((await Estado.abrir()).marcacoes, isEmpty);
      },
    );

    test('limparAoSair com lembretes desligados não cancela nada', () async {
      final estado = await Estado.abrir();
      await estado.alternarFavorito('joao', 3, 16);
      var cancelamentos = 0;

      await limparAoSair(estado, cancelarLembretes: () async => cancelamentos++);

      expect(cancelamentos, 0);
      expect(estado.marcacoes, isEmpty);
    });

    test('limparAoSair segue limpando se cancelar os lembretes falha', () async {
      final estado = await estadoCheio();

      await limparAoSair(
        estado,
        cancelarLembretes: () async => throw Exception('plugin'),
      );

      expect((await Estado.abrir()).marcacoes, isEmpty);
    });

    test('Sair tocado duas vezes devolve o mesmo Sair em andamento', () async {
      final primeiro = Nuvem.instancia.sair();
      final segundo = Nuvem.instancia.sair();
      expect(identical(primeiro, segundo), isTrue);
      // Sem Firebase nos testes, o signOut falha: só importa que é um só.
      await expectLater(primeiro, throwsA(anything));
      expect(Nuvem.instancia.saindo, isFalse);
    });
  });
}
