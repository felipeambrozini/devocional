/// Onde o [AudioOffline] guarda os MP3 baixados, por plataforma.
///
/// Fora da web, uma pasta no disco do aparelho (`armazem_de_audio_io.dart`).
/// Na web e no PWA, o Cache Storage do navegador
/// (`armazem_de_audio_web.dart`), com a chave igual à URL do áudio, para o
/// service worker (`web/firebase-messaging-sw.js`) responder dali quando o
/// player pede o arquivo. `dart:js_interop` só existe na web, por isso a
/// troca é por import condicional, a mesma costura de
/// `espelho_do_tema.dart`.
///
/// Tudo é endereçado pelo caminho relativo do MP3 ("biblia/joao/3.mp3", ver
/// `caminhoRelativoParaChave` em `voz.dart`).
library;

import 'dart:typed_data';

export 'armazem_de_audio_io.dart'
    if (dart.library.js_interop) 'armazem_de_audio_web.dart';

/// O que o [AudioOffline] precisa de um lugar para guardar áudio.
abstract interface class ArmazemDeAudio {
  /// Se dá para baixar aqui. Na web, só com o service worker no controle da
  /// página: sem ele, o arquivo ficaria guardado e o player buscaria na rede
  /// do mesmo jeito.
  bool get suportado;

  Future<bool> existe(String relativo);

  /// Guarda [bytes] em [relativo]. [url] é o endereço do arquivo na nuvem,
  /// a chave do cache na web.
  Future<void> gravar(String relativo, String url, Uint8List bytes);

  /// Os arquivos guardados, com o tamanho de cada um em bytes.
  Future<List<(String, int)>> listar();

  /// Quantos arquivos há direto em [pasta] (`livros/<slug>`).
  Future<int> contarNaPasta(String pasta);

  /// Apaga tudo que começa com [prefixo] ("biblia/joao/"); vazio apaga tudo.
  Future<void> apagar(String prefixo);

  /// Pede ao navegador para não apagar o que foi baixado quando faltar
  /// espaço. Fora da web não faz nada.
  Future<void> pedirParaGuardar();
}
