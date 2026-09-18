import 'package:felipe_ambrozini/dados/config_admin.dart';
import 'package:felipe_ambrozini/dados/recursos.dart';
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

  group('Recursos interruptores remotos', () {
    tearDown(() {
      ConfigAdmin.instancia.redefinirParaTeste();
      Recursos.planoPersonalizadoForcado = null;
      Recursos.ouvirTextosForcado = null;
      Recursos.cronogramaForcado = null;
      Recursos.devocionalManhaForcado = null;
      Recursos.devocionalNoiteForcado = null;
      Recursos.promessasForcado = null;
    });

    test('padrão é tudo ligado', () {
      expect(Recursos.planoPersonalizado, isTrue);
      expect(Recursos.ouvirTextos, isTrue);
      expect(Recursos.cronograma, isTrue);
      expect(Recursos.devocionalManha, isTrue);
      expect(Recursos.devocionalNoite, isTrue);
      expect(Recursos.promessas, isTrue);
    });

    test('forçado desliga sem Firestore', () {
      Recursos.planoPersonalizadoForcado = false;
      Recursos.ouvirTextosForcado = false;
      Recursos.cronogramaForcado = false;
      Recursos.devocionalManhaForcado = false;
      Recursos.devocionalNoiteForcado = false;
      Recursos.promessasForcado = false;
      expect(Recursos.planoPersonalizado, isFalse);
      expect(Recursos.ouvirTextos, isFalse);
      expect(Recursos.cronograma, isFalse);
      expect(Recursos.devocionalManha, isFalse);
      expect(Recursos.devocionalNoite, isFalse);
      expect(Recursos.promessas, isFalse);
    });

    test('config semeada desliga sem forçado', () {
      ConfigAdmin.instancia.definirParaTeste(
        planoPersonalizadoAtivo: false,
        cronogramaAtivo: false,
      );
      expect(Recursos.planoPersonalizado, isFalse);
      expect(Recursos.cronograma, isFalse);
      expect(Recursos.ouvirTextos, isTrue);
    });
  });

  group('Recursos admin', () {
    test('sem login não é admin, e teste nunca é web', () {
      expect(Recursos.ehAdmin, isFalse);
      expect(Recursos.adminNaWeb, isFalse);
    });
  });
}
