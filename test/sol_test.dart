import 'package:flutter_test/flutter_test.dart';
import 'package:felipe_ambrozini/data/sol.dart';

/// Confere o cálculo solar contra horários publicados, em UTC para não depender
/// do fuso da máquina que roda o teste.
void main() {
  ({int hora, int minuto}) utc(DateTime d) {
    final u = d.toUtc();
    return (hora: u.hour, minuto: u.minute);
  }

  void confere(
    String onde,
    DateTime dia,
    double lat,
    double lon, {
    required ({int hora, int minuto}) nascerUtc,
    required ({int hora, int minuto}) porDoSolUtc,
  }) {
    final sol = solDoDia(dia, lat, lon);
    expect(sol, isNotNull, reason: onde);

    int minutos(({int hora, int minuto}) t) => t.hora * 60 + t.minuto;
    final erroNascer = (minutos(utc(sol!.nascer)) - minutos(nascerUtc)).abs();
    final erroPor = (minutos(utc(sol.porDoSol)) - minutos(porDoSolUtc)).abs();

    // Dois minutos de folga cobrem o arredondamento das tabelas publicadas.
    expect(erroNascer, lessThanOrEqualTo(2), reason: '$onde, nascer');
    expect(erroPor, lessThanOrEqualTo(2), reason: '$onde, por do sol');
  }

  test('Sao Paulo no solsticio de junho', () {
    // 21/06/2026: nascer 06:47 e por do sol 17:28 no horario de Brasilia (UTC-3).
    confere(
      'Sao Paulo',
      DateTime(2026, 6, 21),
      -23.55,
      -46.63,
      nascerUtc: (hora: 9, minuto: 47),
      porDoSolUtc: (hora: 20, minuto: 28),
    );
  });

  test('Sao Paulo no solsticio de dezembro', () {
    // 21/12/2026: nascer 05:17 e por do sol 18:53 no horario de Brasilia.
    confere(
      'Sao Paulo',
      DateTime(2026, 12, 21),
      -23.55,
      -46.63,
      nascerUtc: (hora: 8, minuto: 17),
      porDoSolUtc: (hora: 21, minuto: 53),
    );
  });

  test('Londres no equinocio de marco', () {
    // 20/03/2026: nascer 06:02 e por do sol 18:14 UTC.
    confere(
      'Londres',
      DateTime(2026, 3, 20),
      51.48,
      -0.0,
      nascerUtc: (hora: 6, minuto: 2),
      porDoSolUtc: (hora: 18, minuto: 14),
    );
  });

  test('acima do circulo polar no verao nao tem por do sol', () {
    expect(solDoDia(DateTime(2026, 6, 21), 78.22, 15.63), isNull);
  });

  test('acima do circulo polar no inverno nao tem nascer do sol', () {
    expect(solDoDia(DateTime(2026, 12, 21), 78.22, 15.63), isNull);
  });

  test('ehDia cobre so o intervalo entre nascer e por do sol', () {
    final sol = solDoDia(DateTime(2026, 6, 21), -23.55, -46.63)!;
    expect(sol.ehDia(sol.nascer), isTrue);
    expect(sol.ehDia(sol.nascer.subtract(const Duration(minutes: 1))), isFalse);
    expect(sol.ehDia(sol.porDoSol.subtract(const Duration(minutes: 1))), isTrue);
    expect(sol.ehDia(sol.porDoSol), isFalse);
  });
}
