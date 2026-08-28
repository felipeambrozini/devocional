import 'package:felipe_ambrozini/data/voz.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chaves de áudio', () {
    test('chaveDeCapitulo e chaveDaIntroducao geram formato esperado', () {
      expect(chaveDeCapitulo('joao', 3), 'capitulo:joao.3');
      expect(chaveDaIntroducao('genesis'), 'introducao:genesis');
    });
  });
}
