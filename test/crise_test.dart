import 'package:devocional/dados/crise.dart';
import 'package:devocional/dados/personas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pedeApoioEmCrise', () {
    test('reconhece sinais de crise com ou sem acento e caixa', () {
      expect(pedeApoioEmCrise('Não quero mais viver'), isTrue);
      expect(pedeApoioEmCrise('penso em SUICÍDIO'), isTrue);
      expect(pedeApoioEmCrise('às vezes quero morrer'), isTrue);
      expect(pedeApoioEmCrise('vou tirar a própria vida'), isTrue);
    });

    test('ignora conversa comum', () {
      expect(pedeApoioEmCrise('Como orar quando estou triste?'), isFalse);
      expect(pedeApoioEmCrise('O que Spurgeon diz sobre a morte?'), isFalse);
    });
  });

  test('toda persona recebe a orientação do CVV no sistema', () {
    final agora = DateTime(2026, 11, 8, 9, 5);
    for (final persona in [personaSpurgeon, personaFelipe]) {
      expect(instrucaoDoSistema(persona, agora), contains('188'));
    }
  });
}
