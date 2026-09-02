import 'package:felipe_ambrozini/data/recursos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('allowlistDeEmails', () {
    test('vazio não libera ninguém', () {
      expect(allowlistDeEmails(''), isEmpty);
    });

    test('separa por vírgula', () {
      expect(
        allowlistDeEmails('a@x.com,b@y.com'),
        {'a@x.com', 'b@y.com'},
      );
    });

    test('ignora espaço em volta de cada e-mail', () {
      expect(
        allowlistDeEmails(' a@x.com , b@y.com '),
        {'a@x.com', 'b@y.com'},
      );
    });

    test('normaliza caixa', () {
      expect(allowlistDeEmails('Felipe@Exemplo.com'), {'felipe@exemplo.com'});
    });

    test('vírgula sobrando não vira e-mail vazio', () {
      expect(allowlistDeEmails('a@x.com,,b@y.com,'), {'a@x.com', 'b@y.com'});
    });
  });

  group('Recursos.conversas', () {
    tearDown(() => Recursos.conversasForcado = null);

    test('conversasForcado tem prioridade sobre a allowlist', () {
      Recursos.conversasForcado = true;
      expect(Recursos.conversas, isTrue);
    });

    test('sem login e sem override, fica fechado', () {
      Recursos.conversasForcado = null;
      expect(Recursos.conversas, isFalse);
    });
  });
}
