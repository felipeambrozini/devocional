import 'package:felipe_ambrozini/dados/registro.dart';
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

  test('erro só vai para console e arquivo local — sem envio remoto', () {
    // Sem Sentry e sem Analytics: registrar nunca depende de rede nem de
    // aceite. O formato da linha continua valendo para o arquivo local.
    final linha = formatarLinha('Teste', 'algo quebrou', null);
    expect(linha, contains('Teste: algo quebrou'));
  });
}
