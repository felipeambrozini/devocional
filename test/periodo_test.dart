import 'package:flutter_test/flutter_test.dart';
import 'package:felipe_ambrozini/data/modelos.dart';

/// A virada entre manhã e noite segue só o horário do aparelho: 0h-17h59 é
/// manhã, 18h-23h59 é noite.
void main() {
  test('antes das 18h e devocional da manha', () {
    expect(Periodo.pelaHora(0), Periodo.manha);
    expect(Periodo.pelaHora(17), Periodo.manha);
  });

  test('a partir das 18h e devocional da noite', () {
    expect(Periodo.pelaHora(18), Periodo.noite);
    expect(Periodo.pelaHora(23), Periodo.noite);
  });
}
