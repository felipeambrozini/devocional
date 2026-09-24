import 'package:felipe_ambrozini/dados/config_admin.dart';
import 'package:felipe_ambrozini/dados/recursos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  group('Recursos.planos', () {
    tearDown(() {
      Recursos.planosForcado = null;
      Recursos.planoPersonalizadoForcado = null;
      ConfigAdmin.instancia.redefinirParaTeste();
    });

    test('forcado tem prioridade sobre todo o resto', () {
      Recursos.planosForcado = false;
      ConfigAdmin.instancia.definirParaTeste(emailsPlanos: const []);
      expect(Recursos.planos, isFalse);
    });

    test('lista vazia mantém o interruptor global', () {
      expect(Recursos.planos, isTrue);
      Recursos.planoPersonalizadoForcado = false;
      expect(Recursos.planos, isFalse);
    });

    test('lista em uso sem login fecha', () {
      ConfigAdmin.instancia.definirParaTeste(emailsPlanos: ['a@x.com']);
      expect(Recursos.planos, isFalse);
    });
  });
}
