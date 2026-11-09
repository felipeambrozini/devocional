import 'package:devocional/dados/contato.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mailtoPara codifica espaço como %20, nunca como +', () {
    final uri = mailtoPara(
      'alguem@exemplo.com',
      assunto: 'Devocional: relatar um problema',
      corpo: 'Versão 1.17.1+37, Web\n\nDescreva o que aconteceu:\n',
    );

    expect(
      uri.toString(),
      'mailto:alguem@exemplo.com'
      '?subject=Devocional%3A%20relatar%20um%20problema'
      '&body=Vers%C3%A3o%201.17.1%2B37%2C%20Web%0A%0A'
      'Descreva%20o%20que%20aconteceu%3A%0A',
    );
  });
}
