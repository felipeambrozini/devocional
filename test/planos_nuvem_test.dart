import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devocional/dados/planos_nuvem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('linkDoPlano', () {
    test('sem título usa só o id', () {
      expect(linkDoPlano('abc123'), endsWith('?plano=abc123'));
    });

    test('com título, o slug vem antes do id de verdade', () {
      final link = linkDoPlano('abc123', titulo: 'Gênesis em 30 dias');
      expect(link, endsWith('?plano=genesis-em-30-dias-abc123'));
    });

    test('título vazio ou só pontuação cai para o id puro', () {
      expect(linkDoPlano('abc123', titulo: '...'), endsWith('?plano=abc123'));
    });

    test('título gigante não estoura o link', () {
      final link = linkDoPlano(
        'abc123',
        titulo: 'Gênesis, Êxodo, Levítico, Números e Deuteronômio inteiros',
      );
      final slug = Uri.parse(link).queryParameters['plano']!;
      expect(slug.length, lessThanOrEqualTo(50 + 1 + 'abc123'.length));
      expect(slug, endsWith('-abc123'));
    });
  });

  group('idDoParametroDePlano', () {
    test('sem slug devolve o próprio parâmetro', () {
      expect(idDoParametroDePlano('abc123'), 'abc123');
    });

    test('com slug na frente, devolve só o último trecho', () {
      expect(idDoParametroDePlano('genesis-em-30-dias-abc123'), 'abc123');
    });

    test('é o inverso de linkDoPlano', () {
      final link = linkDoPlano('hlj2pu6uw801b99b', titulo: 'Gênesis e Êxodo');
      final parametro = Uri.parse(link).queryParameters['plano']!;
      expect(idDoParametroDePlano(parametro), 'hlj2pu6uw801b99b');
    });
  });

  group('nomeDoParticipante', () {
    test('usa o nome do perfil quando existe', () {
      expect(nomeDoParticipante('Felipe Ambrozini'), 'Felipe Ambrozini');
    });

    test('sem nome, cai em "Participante" — nunca no e-mail', () {
      expect(nomeDoParticipante(null), 'Participante');
      expect(nomeDoParticipante(''), 'Participante');
      expect(nomeDoParticipante('   '), 'Participante');
    });
  });

  group('atualizacaoDeEntrada', () {
    test('não grava o mapa inteiro, para repetir não zerar o progresso', () {
      final campos = atualizacaoDeEntrada('u1', 'Ana');

      expect(campos.keys, {'participantes.u1.nome', 'participantes.u1.lidos'});
      expect(campos['participantes.u1.nome'], 'Ana');
      expect(campos['participantes.u1.lidos'], isA<FieldValue>());
      expect(campos['participantes.u1.lidos'], isNot(isA<List>()));
    });

    test('sem nome no perfil, entra como Participante', () {
      expect(
        atualizacaoDeEntrada('u1', null)['participantes.u1.nome'],
        'Participante',
      );
    });
  });

  group('atualizacaoDeDia', () {
    test('marcar e desmarcar mexem só naquele dia, no servidor', () {
      final marcar = atualizacaoDeDia('u1', 3, true);
      final desmarcar = atualizacaoDeDia('u1', 3, false);

      expect(marcar.keys, {'participantes.u1.lidos'});
      expect(desmarcar.keys, {'participantes.u1.lidos'});
      expect(marcar['participantes.u1.lidos'], isA<FieldValue>());
      expect(desmarcar['participantes.u1.lidos'], isA<FieldValue>());
      expect(
        marcar['participantes.u1.lidos'],
        isNot(equals(desmarcar['participantes.u1.lidos'])),
      );
    });
  });
}
