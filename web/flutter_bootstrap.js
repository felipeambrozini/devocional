{{flutter_js}}
{{flutter_build_config}}

// Bootstrap próprio (Flutter usa este arquivo quando ele existe em web/).
//
// O `load()` vai SEM `serviceWorkerSettings` de propósito. Com elas, o loader
// registra o flutter_service_worker.js no mesmo escopo do service worker que
// o index.html registra — e o app fica com um só dos dois: sem o cache
// offline e sem o push do lembrete, dependendo de quem vence a corrida. O
// service worker do app é o firebase-messaging-sw.js, que cuida das duas
// coisas (ver o comentário no topo daquele arquivo).
_flutter.loader.load();
