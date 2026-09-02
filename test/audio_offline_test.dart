import 'dart:io';

import 'package:felipe_ambrozini/data/audio_offline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Aponta `getApplicationDocumentsPath` para um diretório temporário só
/// desta suíte — sem isto, `AudioOffline` bateria no path_provider de
/// verdade (sem plugin registrado em teste, ele lançaria).
class _PathProviderFalso extends PathProviderPlatform {
  _PathProviderFalso(this.caminho);

  final String caminho;

  @override
  Future<String?> getApplicationDocumentsPath() async => caminho;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('audio_offline_test');
    PathProviderPlatform.instance = _PathProviderFalso(tmp.path);
    // audioBaseUrl é const (String.fromEnvironment): só dá para trocar em
    // runtime por este override, mesmo problema que Voz.baseUrlForTest
    // resolve do lado da leitura em voz.
    AudioOffline.baseUrlParaTeste = 'https://audio.test';
    // AudioOffline é um singleton: sem isto, a contagem em memória de um
    // teste vazaria para o próximo, que aponta para outro diretório
    // temporário vazio.
    await AudioOffline.instancia.atualizarContagens();
  });

  tearDown(() async {
    AudioOffline.baseUrlParaTeste = null;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('baixarCategoria', () {
    test('cancelar() interrompe o lote e preserva o que já baixou', () async {
      final off = AudioOffline.instancia;
      var pedidos = 0;
      final cliente = MockClient((requisicao) async {
        pedidos++;
        // Cancela assim que o primeiro arquivo já tiver sido escrito, para
        // provar que o loop para antes do fim do lote (introducao tem 66
        // chaves — bem mais que os 2-3 que devem ser pedidos aqui).
        if (pedidos == 2) off.cancelar();
        return http.Response.bytes(List.filled(10, 0), 200);
      });

      await off.baixarCategoria('introducao', cliente: cliente);

      expect(
        pedidos,
        lessThan(66),
        reason: 'cancelar() deveria ter parado o loop bem antes do fim',
      );
      expect(off.baixando, isFalse);
      await off.atualizarContagens();
      expect(
        off.contagemPorCategoria['introducao'],
        greaterThan(0),
        reason: 'o que já baixou antes do cancelamento continua no disco',
      );
    });

    test('soma incremental bate com o disco no fim do lote', () async {
      final off = AudioOffline.instancia;
      final cliente = MockClient(
        (requisicao) async => http.Response.bytes(List.filled(100, 0), 200),
      );

      // A menor categoria (66 chaves): o que importa aqui é o lote
      // terminar sem cancelamento, não o tamanho dele.
      await off.baixarCategoria('introducao', cliente: cliente);

      final baixadosDoLoteInteiro = off.contagemPorCategoria['introducao'];
      final bytesDoLoteInteiro = off.tamanhoTotalBytes;

      await off.atualizarContagens();

      expect(off.contagemPorCategoria['introducao'], baixadosDoLoteInteiro);
      expect(off.tamanhoTotalBytes, bytesDoLoteInteiro);
    });
  });
}
