import 'package:felipe_ambrozini/dados/voz.dart';
import 'package:felipe_ambrozini/widgets/botao_de_voz.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chaves de áudio', () {
    test('chaveDeCapitulo e chaveDaIntroducao geram formato esperado', () {
      expect(chaveDeCapitulo('joao', 3), 'capitulo:joao.3');
      expect(chaveDaIntroducao('genesis'), 'introducao:genesis');
    });
  });

  group('velocidade', () {
    test('cicla de 1x até 2x e volta a 1x', () async {
      final voz = Voz.instancia;
      final vistas = <String>[];
      for (var i = 0; i < Voz.velocidades.length; i++) {
        vistas.add(rotuloDaVelocidade(voz.velocidade));
        await voz.proximaVelocidade();
      }
      expect(vistas, ['1x', '1,25x', '1,5x', '1,75x', '2x']);
      expect(voz.velocidade, 1.0);
    });
  });
}
