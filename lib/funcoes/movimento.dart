/// Prefere reduzir movimento do sistema operacional/navegador.
///
/// Fora da web sempre falso: no Android/iOS o sistema já comunica isso pelo
/// `MediaQuery.disableAnimationsOf`, que o chamador consulta separado. Na
/// web, `prefers-reduced-motion: reduce` não é garantido pelo Flutter, então
/// é lido direto da mídia CSS (ver `movimento_web.dart`).
library;

export 'movimento_io.dart' if (dart.library.js_interop) 'movimento_web.dart';
