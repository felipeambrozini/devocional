import 'package:geolocator/geolocator.dart';

import 'estado.dart';

/// Descobre onde o aparelho está, só para saber a que horas o sol nasce e se põe.
///
/// Falha em silêncio de propósito: sem permissão, sem GPS ligado ou sem suporte
/// da plataforma, o lugar continua sendo o último conhecido, e o devocional cai
/// no horário fixo. Nenhum caminho daqui pode impedir o app de abrir.
Future<void> atualizarLugar(Estado estado) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      return;
    }

    // Precisão baixa e de propósito: a cidade já dá o horário do sol com erro
    // de menos de um minuto, e pedir menos precisão gasta menos bateria.
    final posicao = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
    await estado.definirLugar(posicao.latitude, posicao.longitude);
  } catch (_) {
    // Nada a fazer: quem chama já funciona sem lugar nenhum.
  }
}
