// Service worker do FCM: entrega o lembrete diário quando o app está em
// segundo plano ou fechado (ver lib/data/lembretes.dart e
// functions/src/index.ts). O Flutter web tem o próprio service worker
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

// Ícones por tema: a página espelha o tema efetivo do app no Cache Storage
// (lib/data/espelho_do_tema.dart) — localStorage não serve, é invisível para
// o service worker. Sem espelho (primeira visita, storage limpo), cai no
// ícone fixo de sempre.
const ICONE_PADRAO = '/devocional/icons/Icon-192.png';
const ICONE_CLARO = '/devocional/icons/notificacao-tema-claro.png';
const ICONE_ESCURO = '/devocional/icons/notificacao-tema-escuro.png';

async function lerTemaEspelhado() {
  try {
    const cache = await caches.open('devocional-preferencias');
    const resposta = await cache.match('/devocional/__modo-do-tema');
    return resposta ? await resposta.text() : null;
  } catch (_) {
    return null;
  }
}

// Sem exibição automática do navegador em segundo plano — por isso o
// `showNotification` manual aqui. A mensagem é data-only (o Android também
// recebe data-only, para o handler de fundo exibir via notificação local —
// ver lib/data/lembretes.dart), então título e corpo vêm em `data`, junto com
// `chave` ("manha", "promessas" ou "noite") e `minutos`. Tudo vem da Cloud
// Function agendada (functions/src/index.ts).
mensageria.onBackgroundMessage(async (mensagem) => {
  const dados = mensagem.data || {};
  const tema = await lerTemaEspelhado();
  const icone =
    tema === 'escuro'
      ? ICONE_ESCURO
      : tema === 'claro'
        ? ICONE_CLARO
        : ICONE_PADRAO;
  self.registration.showNotification(dados.titulo || 'Devocional', {
    body: dados.corpo || '',
    icon: icone,
    data: { chave: dados.chave },
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
