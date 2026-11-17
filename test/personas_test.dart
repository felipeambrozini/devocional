import 'package:devocional/dados/personas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('persona do Spurgeon', () {
    final sistema = personaSpurgeon.sistema;

    test('traz os fatos da vida e os limites que evitam informação falsa', () {
      for (final trecho in [
        'Kelvedon',
        '6 de janeiro de 1850',
        'Menton',
        'nunca esteve nos Estados Unidos',
        'Contra informação falsa',
      ]) {
        expect(sistema, contains(trecho));
      }
    });

    test('não repete a frase apócrifa como se fosse dele', () {
      expect(sistema, isNot(contains('faço um caminho direto')));
    });

    test('o bloco de fatos não usa travessão, que o modelo imitaria', () {
      final fatos = sistema.substring(sistema.indexOf('Fatos da sua vida'));
      expect(fatos, isNot(contains('—')));
      expect(fatos, isNot(contains(' - ')));
    });
  });

  group('persona do Spurgeon, instruções do projeto', () {
    final sistema = personaSpurgeon.sistema;

    test('traz o que das instruções unificadas vale para ele', () {
      for (final trecho in [
        'Hebreus',
        'peso de eternidade',
        'Miquéias 6:9',
        'Salmo 91:9-10',
        'Devocional do Dia',
      ]) {
        expect(sistema, contains(trecho));
      }
    });

    test('fica nos tetos padrão de pergunta e resposta', () {
      expect(personaSpurgeon.maxTokensDeResposta, 2048);
      expect(personaSpurgeon.maxCaracteresDaPergunta, 2000);
    });
  });

  group('persona do Felipe', () {
    final sistema = personaFelipe.sistema;

    test('traz as instruções unificadas do projeto', () {
      for (final trecho in [
        'Cordeiro',
        'Pai querido',
        'Esboço Dinâmico',
        'Pacotes de Cortes',
        'Perfil 4, Rei Glorificado',
        'urna eletrônica',
        '#CharlesSpurgeon',
        '1500 caracteres',
        'As 365 Lições que Jesus me Ensinou',
      ]) {
        expect(sistema.toUpperCase(), contains(trecho.toUpperCase()));
      }
    });

    test('cabe sermão inteiro na resposta e transcrição na pergunta', () {
      expect(personaFelipe.maxTokensDeResposta, greaterThan(8000));
      expect(
        personaFelipe.maxCaracteresDaPergunta,
        greaterThanOrEqualTo(15000),
      );
    });
  });

  group('limite de assunto', () {
    final agora = DateTime(2026, 11, 17, 14, 30);

    test('as duas personas recusam fora do tema com a mesma frase', () {
      expect(respostaForaDoTema, 'Não posso ajudar com isso.');
      for (final persona in todasAsPersonas) {
        final sistema = instrucaoDoSistema(persona, agora);
        expect(sistema, contains('"$respostaForaDoTema"'));
        expect(sistema, contains('receitas culinárias'));
        expect(sistema, contains(persona.escopo));
      }
    });

    test('o escopo do Felipe inclui Flutter, o do Spurgeon não', () {
      expect(personaFelipe.escopo, contains('Flutter'));
      expect(personaSpurgeon.escopo, isNot(contains('Flutter')));
    });

    test('a orientação de crise vem depois e prevalece sobre o limite', () {
      for (final persona in todasAsPersonas) {
        final sistema = instrucaoDoSistema(persona, agora);
        expect(
          sistema.indexOf('CVV'),
          greaterThan(sistema.indexOf(respostaForaDoTema)),
        );
        expect(sistema, contains('crise abaixo prevalece'));
      }
    });
  });
}
