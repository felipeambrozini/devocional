import 'package:flutter_test/flutter_test.dart';
import 'package:devocional/controladores/devocional_controlador.dart';
import 'package:devocional/dados/canon.dart';
import 'package:devocional/telas/devocional.dart';

void main() {
  group('link de compartilhar do devocional', () {
    test('leva a data mesmo quando a leitura é de hoje', () {
      final hoje = DateTime.now();
      final controlador = DevocionalControlador(
        dataInicial: hoje,
        leituraInicial: Leitura.manha,
      );
      addTearDown(controlador.dispose);
      final dia =
          '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-'
          '${hoje.day.toString().padLeft(2, '0')}';

      expect(
        controlador.linkDaLeitura(),
        '${enderecoDoSite}devocional/manha?data=$dia',
      );
    });

    test('leva a data escolhida no calendário', () {
      final controlador = DevocionalControlador(
        dataInicial: DateTime(2024, 3, 5),
        leituraInicial: Leitura.promessas,
      );
      addTearDown(controlador.dispose);

      expect(
        controlador.linkDaLeitura(),
        '${enderecoDoSite}devocional/promessas?data=2024-03-05',
      );
    });
  });
}
