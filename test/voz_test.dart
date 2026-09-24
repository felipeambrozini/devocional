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
    setUp(() {
      final voz = Voz.instancia;
      voz.aoMudarVelocidade = null;
      voz.restaurarVelocidade(1.0);
    });

    tearDown(() {
      final voz = Voz.instancia;
      voz.aoMudarVelocidade = null;
      voz.restaurarVelocidade(1.0);
    });

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

    test('restaura a guardada e ignora valor desconhecido', () {
      final voz = Voz.instancia;
      voz.restaurarVelocidade(1.5);
      expect(voz.velocidade, 1.5);
      // Gravado por versão futura ou corrompido: fica onde estava.
      voz.restaurarVelocidade(9.0);
      expect(voz.velocidade, 1.5);
    });

    test('trocar de velocidade avisa quem guarda a escolha', () async {
      final voz = Voz.instancia;
      final guardadas = <double>[];
      voz.aoMudarVelocidade = (v) async => guardadas.add(v);
      await voz.proximaVelocidade();
      expect(guardadas, [1.25]);
    });
  });

  group('streams', () {
    test('sem player, posicao e duracao devolvem a mesma instancia', () {
      final voz = Voz.instancia;
      expect(identical(voz.posicao, voz.posicao), isTrue);
      expect(identical(voz.duracao, voz.duracao), isTrue);
    });
  });
}
