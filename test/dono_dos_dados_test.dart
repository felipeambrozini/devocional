import 'dart:convert';

import 'package:devocional/dados/estado.dart';
import 'package:devocional/dados/nuvem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Os dados pessoais do aparelho têm dono (`dono_dos_dados`): a conta que
/// entra depois de outra não funde nem sobe o que era da anterior (ver
/// `assegurarDonoDosDados` e `sincroniasDaConta` em `lib/dados/nuvem.dart`).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Nuvem.instancia.redefinirParaTestes());

  /// O aparelho com os dados da conta A e uma marca de envio pendente dela.
  Future<Estado> aparelhoDaContaA({String? dono}) async {
    SharedPreferences.setMockInitialValues({
      'sincronia_pendente_copia': true,
      chaveDoDonoDosDados: ?dono,
    });
    final estado = await Estado.abrir();
    await estado.alternarFavorito('joao', 3, 16);
    await estado.definirNota('romanos', 8, 28, 'segredo da conta A');
    await estado.alternarLido('2026-11-20');
    return estado;
  }

  /// A cópia que a conta B tem na nuvem: um favorito só dela. Montada num
  /// aparelho à parte, antes de [aparelhoDaContaA] trocar as prefs.
  Future<Map<String, dynamic>> documentoDaContaB() async {
    SharedPreferences.setMockInitialValues({});
    final estadoB = await Estado.abrir();
    await estadoB.alternarFavorito('salmos', 23, 1);
    return {'copia': json.decode(estadoB.exportar())};
  }

  test('outra conta: limpa antes de fundir e nada da conta A sobe', () async {
    final documentoB = await documentoDaContaB();
    final estado = await aparelhoDaContaA(dono: 'conta-a');
    final favoritosAoPuxar = <List<String>>[];
    final enviados = <String>[];

    final sincronias = sincroniasDaConta(
      estado: estado,
      conferirDono: () => Nuvem.instancia.conferirDono(estado, 'conta-b'),
      lerDocumento: ({soServidor = false}) async {
        favoritosAoPuxar.add([
          for (final m in estado.marcacoes) '${m.livro} ${m.capitulo}',
        ]);
        return documentoB;
      },
      empurrarCampo: (campo, copia) async => enviados.add(copia),
    );
    await Future.wait([for (final s in sincronias) s.comecar()]);
    for (final s in sincronias) {
      await s.despejar();
    }

    expect(
      favoritosAoPuxar.first,
      isEmpty,
      reason: 'a cópia da conta A sai antes da primeira leitura da conta B',
    );
    expect(estado.ehFavorito('joao', 3, 16), isFalse);
    expect(estado.ehFavorito('salmos', 23, 1), isTrue);
    expect(estado.foiLido('2026-11-20'), isFalse);
    for (final copia in enviados) {
      expect(copia, isNot(contains('segredo da conta A')));
      expect(copia, isNot(contains('2026-11-20')));
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(chaveDoDonoDosDados), 'conta-b');
    expect(
      prefs.getKeys().where((k) => k.startsWith('sincronia_pendente_')),
      isEmpty,
      reason: 'a marca pendente da conta A não reenvia para a B',
    );
  });

  test('o Sair também espera a conferência antes de ler a conta', () async {
    final estado = await aparelhoDaContaA(dono: 'conta-a');
    final favoritosAoLer = <int>[];
    final sincronias = sincroniasDaConta(
      estado: estado,
      conferirDono: () => Nuvem.instancia.conferirDono(estado, 'conta-b'),
      lerDocumento: ({soServidor = false}) async {
        favoritosAoLer.add(estado.marcacoes.length);
        return null;
      },
      empurrarCampo: (campo, copia) async {},
    );

    await sincronias.first.garantirNaNuvem();

    expect(favoritosAoLer, [0]);
  });

  test('mesma conta: nada é limpo', () async {
    final estado = await aparelhoDaContaA(dono: 'conta-a');

    await Nuvem.instancia.conferirDono(estado, 'conta-a');

    expect(estado.ehFavorito('joao', 3, 16), isTrue);
    expect(estado.comNota.single.nota, 'segredo da conta A');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(chaveDoDonoDosDados), 'conta-a');
  });

  test('sem dono gravado: adota a conta que entra sem limpar', () async {
    final estado = await aparelhoDaContaA();

    await Nuvem.instancia.conferirDono(estado, 'conta-a');

    expect(estado.ehFavorito('joao', 3, 16), isTrue);
    expect(estado.foiLido('2026-11-20'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(chaveDoDonoDosDados), 'conta-a');
  });

  test('as puxadas da mesma entrada dividem uma conferência só', () async {
    final estado = await aparelhoDaContaA(dono: 'conta-a');

    final primeira = Nuvem.instancia.conferirDono(estado, 'conta-b');
    final segunda = Nuvem.instancia.conferirDono(estado, 'conta-b');

    expect(identical(primeira, segunda), isTrue);
    await primeira;
  });

  test('a limpeza do Apagar e do Sair tira os dados e o dono', () async {
    final estado = await aparelhoDaContaA(dono: 'conta-a');

    await limparAparelhoDaConta(estado, cancelarLembretes: () async {});

    expect(estado.marcacoes, isEmpty);
    expect(estado.foiLido('2026-11-20'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(chaveDoDonoDosDados), isFalse);
    expect(prefs.containsKey('sincronia_pendente_copia'), isFalse);
  });

  test('Sair sem consentimento desloga e só então limpa', () async {
    final passos = <String>[];

    await sairSemConsentimento(
      deslogar: () async => passos.add('deslogar'),
      limparAparelho: () async => passos.add('limpar'),
    );

    expect(passos, ['deslogar', 'limpar']);
  });

  test('Sair sem consentimento que não desloga não limpa nada', () async {
    final passos = <String>[];

    await expectLater(
      sairSemConsentimento(
        deslogar: () async => throw Exception('sem rede'),
        limparAparelho: () async => passos.add('limpar'),
      ),
      throwsException,
    );

    expect(passos, isEmpty);
  });
}
