/// Fachada condicional para ajustar a URL visível na barra de endereço sem
/// navegar — ver [removerParametroDaUrl] em `url_da_pagina_web.dart`. Fora da
/// web (VM de teste incluída) é um no-op em `url_da_pagina_io.dart`: não há
/// barra de endereço, e `dart:js_interop` não existe fora da web. Mesma
/// costura condicional de `espelho_do_tema.dart`.
library;

export 'url_da_pagina_io.dart' if (dart.library.js_interop) 'url_da_pagina_web.dart';
