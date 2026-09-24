import 'package:felipe_ambrozini/dados/config_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => ConfigAdmin.instancia.redefinirParaTeste());

  group('normalizarEmails', () {
    test('entrada torta vira lista vazia, nunca exceção', () {
      expect(ConfigAdmin.normalizarEmails(null), isEmpty);
      expect(ConfigAdmin.normalizarEmails('a@x.com'), isEmpty);
      expect(ConfigAdmin.normalizarEmails([1, null, '']), isEmpty);
    });

    test('normaliza caixa e espaço, tira duplicata e o que não é e-mail', () {
      expect(
        ConfigAdmin.normalizarEmails([
          ' B@x.com ',
          'a@x.com',
          'b@X.com',
          'sem-arroba',
          '',
        ]),
        ['a@x.com', 'b@x.com'],
      );
    });
  });

  group('validarEmail', () {
    test('aceita e devolve normalizado', () {
      expect(
        ConfigAdmin.validarEmail('  Ana@Exemplo.com '),
        'ana@exemplo.com',
      );
    });

    test('recusa vazio, sem arroba e com espaço', () {
      expect(() => ConfigAdmin.validarEmail(''), throwsFormatException);
      expect(
        () => ConfigAdmin.validarEmail('sem-arroba'),
        throwsFormatException,
      );
      expect(
        () => ConfigAdmin.validarEmail('a @x.com'),
        throwsFormatException,
      );
    });
  });

  group('aplicarMapa', () {
    test('documento ainda inexistente marca carregado sem desligar nada', () {
      ConfigAdmin.instancia.aplicarMapa(null);
      expect(ConfigAdmin.instancia.carregado, isTrue);
      expect(ConfigAdmin.instancia.conversasAtivas, isTrue);
      expect(ConfigAdmin.instancia.emailsComConversas, isEmpty);
      expect(ConfigAdmin.instancia.emailsComPlanos, isEmpty);
    });

    test('aplica valores, normaliza e-mails e mantém ligado o ausente', () {
      ConfigAdmin.instancia.aplicarMapa({
        'conversasAtivas': false,
        'emailsComConversas': ['B@x.com', 'a@x.com'],
        'emailsComPlanos': ['C@x.com', 'a@x.com'],
        'manhaAtivo': false,
      });
      expect(ConfigAdmin.instancia.conversasAtivas, isFalse);
      expect(ConfigAdmin.instancia.emailsComConversas, ['a@x.com', 'b@x.com']);
      expect(ConfigAdmin.instancia.emailsComPlanos, ['a@x.com', 'c@x.com']);
      expect(ConfigAdmin.instancia.manhaAtivo, isFalse);
      expect(ConfigAdmin.instancia.cronogramaAtivo, isTrue);
    });

    test('tipo errado mantém o padrão ligado', () {
      ConfigAdmin.instancia.aplicarMapa({'conversasAtivas': 'sim'});
      expect(ConfigAdmin.instancia.conversasAtivas, isTrue);
    });
  });

  test('definir recusa campo desconhecido sem tocar no Firestore', () {
    expect(
      () => ConfigAdmin.instancia.definir('campoQueNaoExiste', true),
      throwsArgumentError,
    );
  });

  test('iniciar sem Firebase volta em silêncio', () async {
    await ConfigAdmin.instancia.iniciar();
    expect(ConfigAdmin.instancia.carregado, isFalse);
  });
}
