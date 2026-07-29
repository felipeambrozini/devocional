import 'dart:math' as math;

/// Nascer e pôr do sol de um dia num ponto da Terra.
class Sol {
  const Sol({required this.nascer, required this.porDoSol});

  /// Ambos no fuso local do aparelho.
  final DateTime nascer;
  final DateTime porDoSol;

  /// Verdadeiro entre o nascer e o pôr do sol, ou seja, com o sol no céu.
  bool ehDia(DateTime momento) =>
      !momento.isBefore(nascer) && momento.isBefore(porDoSol);
}

const _grau = math.pi / 180;

/// Nascer e pôr do sol pelo algoritmo solar do NOAA, sem rede e sem chave.
///
/// Preciso a menos de um minuto nas latitudes habitadas, que é folga de sobra
/// para virar um devocional. Devolve nulo quando o dia não tem nascer nem pôr
/// do sol, o que acontece nos círculos polares: aí o chamador usa o horário
/// fixo como recurso.
Sol? solDoDia(DateTime dia, double latitude, double longitude) {
  // Dia juliano ao meio-dia UTC da data local, base de todo o resto.
  final meioDia = DateTime.utc(dia.year, dia.month, dia.day, 12);
  final julianoDoDia =
      meioDia.millisecondsSinceEpoch / Duration.millisecondsPerDay + 2440587.5;
  final seculos = (julianoDoDia - 2451545) / 36525;

  final mediaGeometrica =
      280.46646 + seculos * (36000.76983 + seculos * 0.0003032);
  final anomaliaMedia = 357.52911 + seculos * (35999.05029 - 0.0001537 * seculos);
  final excentricidade =
      0.016708634 - seculos * (0.000042037 + 0.0000001267 * seculos);

  final anomalia = anomaliaMedia * _grau;
  final centro = math.sin(anomalia) *
          (1.914602 - seculos * (0.004817 + 0.000014 * seculos)) +
      math.sin(2 * anomalia) * (0.019993 - 0.000101 * seculos) +
      math.sin(3 * anomalia) * 0.000289;
  final longitudeVerdadeira = mediaGeometrica + centro;
  final aparente = longitudeVerdadeira -
      0.00569 -
      0.00478 * math.sin((125.04 - 1934.136 * seculos) * _grau);

  final obliquidadeMedia = 23 +
      (26 +
              (21.448 -
                      seculos *
                          (46.815 + seculos * (0.00059 - seculos * 0.001813))) /
                  60) /
          60;
  final obliquidade = obliquidadeMedia +
      0.00256 * math.cos((125.04 - 1934.136 * seculos) * _grau);

  final declinacao = math.asin(
    math.sin(obliquidade * _grau) * math.sin(aparente * _grau),
  );

  // Equação do tempo, em minutos: a diferença entre o sol real e o sol médio.
  final y = math.pow(math.tan(obliquidade * _grau / 2), 2).toDouble();
  final equacaoDoTempo = 4 /
      _grau *
      (y * math.sin(2 * mediaGeometrica * _grau) -
          2 * excentricidade * math.sin(anomalia) +
          4 *
              excentricidade *
              y *
              math.sin(anomalia) *
              math.cos(2 * mediaGeometrica * _grau) -
          0.5 * y * y * math.sin(4 * mediaGeometrica * _grau) -
          1.25 * excentricidade * excentricidade * math.sin(2 * anomalia));

  // 90.833 graus, e não 90: desconta a refração atmosférica e o raio do disco
  // solar, então o instante é o do primeiro contato do sol com o horizonte.
  final cosseno = math.cos(90.833 * _grau) /
          (math.cos(latitude * _grau) * math.cos(declinacao)) -
      math.tan(latitude * _grau) * math.tan(declinacao);
  if (cosseno.abs() > 1) return null; // sol da meia-noite ou noite polar

  final anguloHorario = math.acos(cosseno) / _grau;
  final meioDiaSolar = 720 - 4 * longitude - equacaoDoTempo; // minutos UTC

  DateTime local(double minutosUtc) => DateTime.utc(dia.year, dia.month, dia.day)
      .add(Duration(milliseconds: (minutosUtc * 60000).round()))
      .toLocal();

  return Sol(
    nascer: local(meioDiaSolar - 4 * anguloHorario),
    porDoSol: local(meioDiaSolar + 4 * anguloHorario),
  );
}
