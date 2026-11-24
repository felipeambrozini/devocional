import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'armazem_de_audio.dart';

/// O cache onde ficam os MP3 baixados na web. O mesmo nome está em
/// `web/firebase-messaging-sw.js` (`CACHE_DE_AUDIO`), que responde dali. É
/// separado do `devocional-offline` do app: a limpeza de build do service
/// worker não pode levar o áudio da pessoa junto.
const nomeDoCacheDeAudio = 'devocional-audio';

/// O armazém de áudio da web e do PWA: o Cache Storage do navegador, com a
/// URL do áudio na nuvem como chave. [baseUrl] é a raiz dessas URLs
/// (`AUDIO_BASE_URL`), para ir da chave ao caminho relativo e de volta.
ArmazemDeAudio criarArmazemDeAudio(String Function() baseUrl) =>
    _ArmazemNoNavegador(baseUrl);

class _ArmazemNoNavegador implements ArmazemDeAudio {
  _ArmazemNoNavegador(this._baseUrl);

  final String Function() _baseUrl;

  String get _raiz {
    final base = _baseUrl();
    return base.endsWith('/') ? base : '$base/';
  }

  String _url(String relativo) => '$_raiz$relativo';

  Future<web.Cache> _cache() =>
      web.window.caches.open(nomeDoCacheDeAudio).toDart;

  @override
  bool get suportado {
    try {
      // Sem service worker no controle (primeira visita antes do
      // `clients.claim`, `flutter run` de desenvolvimento, navegador sem
      // suporte), o áudio guardado nunca seria servido.
      return web.window.navigator.serviceWorker.controller != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> existe(String relativo) async {
    final achado = await (await _cache()).match(_url(relativo).toJS).toDart;
    return achado != null;
  }

  @override
  Future<void> gravar(String relativo, String url, Uint8List bytes) async {
    final cabecalhos = web.Headers()
      ..set('Content-Type', 'audio/mpeg')
      ..set('Content-Length', '${bytes.length}');
    await (await _cache())
        .put(
          _url(relativo).toJS,
          web.Response(bytes.toJS, web.ResponseInit(headers: cabecalhos)),
        )
        .toDart;
  }

  Future<List<String>> _chaves() async {
    final pedidos = (await (await _cache()).keys().toDart).toDart;
    final raiz = _raiz;
    return [
      for (final pedido in pedidos)
        if (pedido.url.startsWith(raiz)) pedido.url.substring(raiz.length),
    ];
  }

  @override
  Future<List<(String, int)>> listar() async {
    final cache = await _cache();
    final arquivos = <(String, int)>[];
    for (final relativo in await _chaves()) {
      final resposta = await cache.match(_url(relativo).toJS).toDart;
      final tamanho = int.tryParse(
        resposta?.headers.get('Content-Length') ?? '',
      );
      arquivos.add((relativo, tamanho ?? 0));
    }
    return arquivos;
  }

  @override
  Future<int> contarNaPasta(String pasta) async {
    final prefixo = '$pasta/';
    return (await _chaves())
        .where(
          (r) =>
              r.startsWith(prefixo) &&
              !r.substring(prefixo.length).contains('/'),
        )
        .length;
  }

  @override
  Future<void> apagar(String prefixo) async {
    final cache = await _cache();
    for (final relativo in await _chaves()) {
      if (relativo.startsWith(prefixo)) {
        await cache.delete(_url(relativo).toJS).toDart;
      }
    }
  }

  @override
  Future<void> pedirParaGuardar() async {
    try {
      // Sem isto o navegador pode apagar o cache quando falta espaço, e o
      // Safari apaga o que o site guardou depois de dias sem visita (o PWA
      // instalado na tela inicial fica de fora dessa regra).
      await web.window.navigator.storage.persist().toDart;
    } catch (_) {
      // Navegador que não oferece: segue sem a garantia.
    }
  }
}
