import 'package:flutter_test/flutter_test.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/sol.dart';

/// A virada entre manhã e noite segue o sol do lugar, com o horário fixo das
/// 18h só como recurso. Os horários vêm do próprio cálculo solar para o teste
/// não depender do fuso da máquina.
void main() {
  const saoPaulo = (-23.55, -46.63);
  final dezembro = DateTime(2026, 12, 21);

  test('sem lugar conhecido cai no horario fixo das 18h', () {
    expect(Periodo.peloSol(DateTime(2026, 12, 21, 17, 59), null),
        Periodo.manha);
    expect(Periodo.peloSol(DateTime(2026, 12, 21, 18), null), Periodo.noite);
  });

  test('com lugar, a virada acompanha o por do sol e nao as 18h', () {
    final sol = solDoDia(dezembro, saoPaulo.$1, saoPaulo.$2)!;
    // Em Sao Paulo em dezembro o sol se poe depois das 18h, então às 18h em
    // ponto ainda é dia e o devocional continua sendo o da manhã.
    expect(sol.porDoSol.hour, greaterThanOrEqualTo(18));
    expect(Periodo.peloSol(sol.porDoSol.subtract(const Duration(minutes: 1)),
        saoPaulo), Periodo.manha);
    expect(Periodo.peloSol(sol.porDoSol, saoPaulo), Periodo.noite);
  });

  test('antes do nascer do sol ainda e noite', () {
    final sol = solDoDia(dezembro, saoPaulo.$1, saoPaulo.$2)!;
    expect(Periodo.peloSol(sol.nascer.subtract(const Duration(minutes: 1)),
        saoPaulo), Periodo.noite);
    expect(Periodo.peloSol(sol.nascer, saoPaulo), Periodo.manha);
  });

  test('noite polar cai no horario fixo em vez de estourar', () {
    const svalbard = (78.22, 15.63);
    expect(solDoDia(dezembro, svalbard.$1, svalbard.$2), isNull);
    expect(Periodo.peloSol(DateTime(2026, 12, 21, 10), svalbard),
        Periodo.manha);
    expect(Periodo.peloSol(DateTime(2026, 12, 21, 20), svalbard),
        Periodo.noite);
  });
}
