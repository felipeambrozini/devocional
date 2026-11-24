import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'armazem_de_audio.dart';

/// O armazém de áudio do app instalado: a pasta `audio_offline/` nos
/// documentos do aparelho. [baseUrl] não é usado aqui: no disco o caminho
/// relativo basta.
ArmazemDeAudio criarArmazemDeAudio(String Function() baseUrl) =>
    _ArmazemNoDisco();

class _ArmazemNoDisco implements ArmazemDeAudio {
  @override
  bool get suportado => true;

  Future<Directory> _raiz() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/audio_offline');
  }

  Future<File> _arquivo(String relativo) async =>
      File('${(await _raiz()).path}/$relativo');

  @override
  Future<bool> existe(String relativo) async =>
      (await _arquivo(relativo)).exists();

  @override
  Future<void> gravar(String relativo, String url, Uint8List bytes) async {
    final arquivo = await _arquivo(relativo);
    await arquivo.parent.create(recursive: true);
    await arquivo.writeAsBytes(bytes);
  }

  @override
  Future<List<(String, int)>> listar() async {
    final raiz = await _raiz();
    if (!await raiz.exists()) return const [];
    // `Directory.list()` devolve o separador nativo (`\` no Windows do
    // desenvolvimento, `/` no Android e no iOS): normalizar antes de cortar a
    // raiz evita a contagem sempre zerada num dos dois mundos.
    final prefixo = '${raiz.path.replaceAll('\\', '/')}/';
    final arquivos = <(String, int)>[];
    await for (final e in raiz.list(recursive: true)) {
      if (e is! File) continue;
      final caminho = e.path.replaceAll('\\', '/');
      if (!caminho.startsWith(prefixo)) continue;
      arquivos.add((caminho.substring(prefixo.length), await e.length()));
    }
    return arquivos;
  }

  @override
  Future<int> contarNaPasta(String pasta) async {
    final alvo = Directory('${(await _raiz()).path}/$pasta');
    if (!await alvo.exists()) return 0;
    var total = 0;
    await for (final e in alvo.list()) {
      if (e is File) total++;
    }
    return total;
  }

  @override
  Future<void> apagar(String prefixo) async {
    final raiz = await _raiz();
    final alvo = prefixo.isEmpty ? raiz : Directory('${raiz.path}/$prefixo');
    if (await alvo.exists()) await alvo.delete(recursive: true);
  }

  @override
  Future<void> pedirParaGuardar() async {}
}
