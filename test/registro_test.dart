import 'package:felipe_ambrozini/data/registro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatarLinha', () {
    test('traz origem e erro, terminada em quebra de linha', () {
      final linha = formatarLinha('Teste', 'algo quebrou', null);
      expect(linha, contains('Teste: algo quebrou'));
      expect(linha, endsWith('\n'));
    });

    test('inclui a pilha quando informada', () {
      final linha = formatarLinha('Teste', 'algo quebrou', StackTrace.current);
      expect(linha, contains('registro_test.dart'));
    });
  });

  test(
    'envioRemotoPermitido começa desligado — nada de Sentry sem aceite',
    () {
      expect(Registro.envioRemotoPermitido, isFalse);
    },
  );
}
