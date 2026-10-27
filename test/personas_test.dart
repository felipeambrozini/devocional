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
}
