// Service worker do FCM: entrega o lembrete diário quando o app está em
// segundo plano ou fechado (ver lib/data/lembretes.dart e
// tool/enviar_lembretes.dart). O Flutter web tem o próprio service worker
// (flutter_service_worker.js, gerado no build); este é um segundo, registrado
// à parte em web/index.html — não há conflito, cada um cuida do próprio
// escopo de evento.
//
// Os placeholders __ENTRE_UNDERSCORES__ abaixo são preenchidos no build do
// CI (.github/workflows/deploy-web.yml) com os mesmos secrets do Firebase já
// usados no --dart-define do app. Para testar localmente, troque à mão pelos
// valores do seu .env.json (ver README.md) — nunca comitar o resultado.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js'
);

firebase.initializeApp({
  apiKey: '__FIREBASE_API_KEY_WEB__',
  appId: '__FIREBASE_APP_ID_WEB__',
  messagingSenderId: '__FIREBASE_MESSAGING_SENDER_ID__',
  projectId: '__FIREBASE_PROJECT_ID__',
  authDomain: '__FIREBASE_AUTH_DOMAIN__',
  storageBucket: '__FIREBASE_STORAGE_BUCKET__',
});

const mensageria = firebase.messaging();

// Sem exibição automática do navegador em segundo plano — por isso o
// `showNotification` manual aqui. `data.chave` vem de tool/enviar_lembretes.dart
// ("manha", "promessas" ou "noite"), o mesmo contrato do toque no Android.
mensageria.onBackgroundMessage((mensagem) => {
  const notificacao = mensagem.notification || {};
  const chave = mensagem.data && mensagem.data.chave;
  self.registration.showNotification(notificacao.title || 'Devocional', {
    body: notificacao.body || '',
    icon: '/devocional/icons/Icon-192.png',
    data: { chave: chave },
  });
});

// Reaproveita uma aba já aberta em vez de abrir outra; `?lembrete=<chave>` é
// o parâmetro que lib/main.dart (_abrirLeituraDoLembreteDoLink) já lê para
// os outros links da web.
self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  const chave = evento.notification.data && evento.notification.data.chave;
  const url = chave
    ? `/devocional/hoje?lembrete=${chave}`
    : '/devocional/hoje';

  evento.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((janelas) => {
      const aberta = janelas[0];
      if (aberta && 'navigate' in aberta) {
        return aberta.navigate(url).then((janelaNavegada) =>
          janelaNavegada ? janelaNavegada.focus() : self.clients.openWindow(url)
        );
      }
      return self.clients.openWindow(url);
    })
  );
});
