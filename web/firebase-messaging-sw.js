// Service worker do app: entrega o lembrete diário quando o app está em
// segundo plano ou fechado (ver lib/dados/lembretes.dart e
// functions/src/index.ts) E mantém o app inteiro disponível offline.
//
// É o ÚNICO service worker do site, de propósito: o loader do Flutter
// registraria o flutter_service_worker.js no mesmo escopo e um derrubaria o
// outro (ver web/flutter_bootstrap.js). O registro mora em web/index.html.
//
// O cache offline usa o `precache_manifest.json` que o build gera com
// `--web-content-hash`: ele lista cada arquivo com o hash no nome, então o
// cache guarda nomes imutáveis e uma versão nova do app nunca mistura arquivo
// velho com arquivo novo. O núcleo (HTML, bootstrap, main.dart.js, fontes,
// CanvasKit, ícones) é pré-cacheado na instalação; o conteúdo (capítulos,
// devocionais, comentários) entra no cache conforme é lido e fica disponível
// na próxima vez mesmo sem rede.
//
// Os placeholders __ENTRE_UNDERSCORES__ abaixo são preenchidos no build do
// CI (.github/workflows/deploy-web.yml) com os mesmos secrets do Firebase já
// usados no --dart-define do app. Para testar localmente, troque à mão pelos
// valores do seu .env.json (ver README.md) — nunca comitar o resultado.
//
// O `__BUILD_ID__` é trocado pelo SHA do commit: é o que muda os bytes deste
// arquivo a cada deploy e faz o navegador instalar a versão nova (sem isso, o
// texto do worker ficaria idêntico e o `install` — que pré-cacheia o build
// novo e limpa o velho — nunca rodaria de novo).
const BUILD_ID = '__BUILD_ID__';
//
// A versão do SDK JS precisa acompanhar a que o firebase_core_web carrega na
// página (`supportedFirebaseJsSdkVersion`): a página registra por FID
// (`register()`, SDK 12.14+), e um SW mais antigo, ao renovar a inscrição no
// `pushsubscriptionchange`, volta ao modelo por token e desfaz o registro.
try {
  importScripts(
    'https://www.gstatic.com/firebasejs/13.3.0/firebase-app-compat.js'
  );
  importScripts(
    'https://www.gstatic.com/firebasejs/13.3.0/firebase-messaging-compat.js'
  );

  firebase.initializeApp({
    apiKey: '__FIREBASE_API_KEY_WEB__',
    appId: '__FIREBASE_APP_ID_WEB__',
    messagingSenderId: '__FIREBASE_MESSAGING_SENDER_ID__',
    projectId: '__FIREBASE_PROJECT_ID__',
    authDomain: '__FIREBASE_AUTH_DOMAIN__',
    storageBucket: '__FIREBASE_STORAGE_BUCKET__',
  });

  // Instanciar é o que liga o tratamento do `pushsubscriptionchange` do SDK.
  firebase.messaging();
} catch (erro) {
  // Sem o SDK (gstatic fora do ar, config incompleta), o push do lembrete fica
  // de fora, mas o cache offline não: o resto do arquivo não usa `firebase`.
  console.warn('Devocional: Firebase Messaging indisponível', erro);
}

// Ícones por tema: a página espelha o tema efetivo do app no Cache Storage
// (lib/dados/espelho_do_tema.dart) — localStorage não serve, é invisível para
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

// A mensagem é data-only (o Android também recebe data-only, para o handler
// de fundo exibir via notificação local — ver lib/dados/lembretes.dart), então
// título e corpo vêm em `data`, junto com `chave` ("manha", "promessas" ou
// "noite") e `minutos`. Tudo vem da Cloud Function agendada
// (functions/src/index.ts).
//
// Listener próprio de `push`, e não `onBackgroundMessage`: o SDK só chama
// aquele handler se nenhuma aba do app estiver visível — com o app aberto na
// tela, ele repassa a mensagem à página (`onMessage`), que na web não exibe
// nada, e o lembrete sumia. Aqui exibe sempre; o listener do SDK continua
// registrado, mas sem `notification` no payload nem handler de fundo, não
// mostra nada por conta própria — então não duplica.
self.addEventListener('push', (evento) => {
  let mensagem = null;
  try {
    mensagem = evento.data && evento.data.json();
  } catch (_) {}
  if (!mensagem) return;
  evento.waitUntil(exibirLembrete(mensagem.data || {}));
});

async function exibirLembrete(dados) {
  const tema = await lerTemaEspelhado();
  const icone =
    tema === 'escuro'
      ? ICONE_ESCURO
      : tema === 'claro'
        ? ICONE_CLARO
        : ICONE_PADRAO;
  return self.registration.showNotification(dados.titulo || 'Devocional', {
    body: dados.corpo || '',
    icon: icone,
    // Tag por slot, não fixa: uma reentrega do mesmo lembrete (o FCM garante
    // "pelo menos uma vez", duplicata acontece) substitui a anterior em vez
    // de empilhar, mas os 4 slots do dia continuam independentes — a manhã
    // dispara dois avisos de propósito (devocional + promessas), e uma tag
    // única faria o segundo apagar o primeiro antes do usuário ver.
    tag: dados.chave || 'lembrete-devocional',
    data: { chave: dados.chave },
  });
}

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
    // includeUncontrolled: sem isto, uma aba aberta antes deste service
    // worker assumir o controle (comum com várias abas, ou logo após o SW
    // atualizar) fica de fora do matchAll — e o código abriria uma aba nova
    // em vez de reaproveitar a existente.
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((janelas) => {
        const aberta = janelas[0];
        if (aberta && 'navigate' in aberta) {
          return aberta.navigate(url).then((janelaNavegada) =>
            janelaNavegada
              ? janelaNavegada.focus()
              : self.clients.openWindow(url)
          );
        }
        return self.clients.openWindow(url);
      })
  );
});

// --- cache offline ------------------------------------------------------- //

// Nome fixo: os nomes dos arquivos já carregam o hash do conteúdo. Na
// ativação, o que não pertence ao build atual é apagado; um nome versionado
// exigiria saber a versão antes do primeiro fetch, e offline ela não está em
// lugar nenhum.
const CACHE = 'devocional-offline';
const ESCOPO = self.registration.scope;
const INDICE = new URL('index.html', ESCOPO).href;
const MANIFESTO = new URL('precache_manifest.json', ESCOPO).href;

// Nome com hash no meio — o que o `--web-content-hash` produz. Arquivo
// assim nunca muda: pode sair do cache sem revalidar.
const ARQUIVO_COM_HASH = /\.[0-9a-f]{8,}\.(?:js|json|bin|wasm|ttf|otf|frag|png|webp|woff2?)$/i;

/// O Flutter serve a mesma build para todos os navegadores, mas escolhe uma
/// variante do CanvasKit conforme o motor: Chromium usa `canvaskit/chromium/`,
/// o resto usa `canvaskit/`. Pré-cachear a variante errada desperdiça vários
/// MB; se a detecção errar, o cache de runtime completa na primeira visita
/// controlada pelo service worker.
function varianteDoCanvasKit() {
  const blink =
    navigator.vendor === 'Google Inc.' || navigator.userAgent.includes('Edg/');
  return blink ? 'canvaskit/chromium/' : 'canvaskit/';
}

/// O que precisa estar no aparelho para o app abrir sem rede e desenhar a
/// primeira tela. O resto (conteúdo) entra conforme é usado.
function ehNucleo(url, variante) {
  if (
    url === 'index.html' ||
    url === 'flutter_bootstrap.js' ||
    url === 'flutter.js' ||
    url === 'manifest.json' ||
    url === 'version.json'
  ) {
    return true;
  }
  if (url.startsWith('main.dart.')) return url.endsWith('.js');
  if (url.startsWith('icons/')) return true;
  if (url.startsWith('assets/assets/fontes/')) return true;
  // Capas e ilustrações somam ~0,5 MB: sem elas a primeira tela abriria offline
  // com os espaços vazios. O resto de `assets/assets/` (Bíblia, comentários,
  // devocionais, livros) é grande demais para o install e entra conforme é lido.
  if (url.startsWith('assets/assets/imagens/')) return true;
  // Manifestos de asset, fontes padrão do Flutter, shaders: sem eles o
  // primeiro frame quebra. NOTICES é 1,5 MB de licenças e não entra.
  if (
    url.startsWith('assets/') &&
    !url.startsWith('assets/assets/') &&
    !url.startsWith('assets/NOTICES')
  ) {
    return true;
  }
  if (url.startsWith('canvaskit/')) {
    // .symbols são 1,3 MB por arquivo e nenhum navegador os pede.
    if (url.endsWith('.symbols')) return false;
    if (url.startsWith('canvaskit/chromium/')) {
      return variante === 'canvaskit/chromium/';
    }
    // Só os arquivos da raiz (canvaskit.js/wasm), não as pastas
    // skwasm/webparagraph/wimp, que esta build não usa.
    return variante === 'canvaskit/' && !url.slice('canvaskit/'.length).includes('/');
  }
  return false;
}

async function lerManifesto() {
  const resposta = await fetch(MANIFESTO, {cache: 'no-store'});
  if (!resposta.ok) throw new Error(`precache_manifest.json: ${resposta.status}`);
  return resposta.json();
}

self.addEventListener('install', (evento) => {
  evento.waitUntil(
    (async () => {
      // Assume o controle já: o app não tem uma tela de "atualizando" e a
      // próxima navegação precisa pegar o build novo.
      await self.skipWaiting();
      try {
        const manifesto = await lerManifesto();
        const variante = varianteDoCanvasKit();
        const nucleo = manifesto.entries
          .filter((entrada) => ehNucleo(entrada.url, variante))
          .map((entrada) => new URL(entrada.url, ESCOPO).href);
        const cache = await caches.open(CACHE);
        console.info('Devocional: pré-cache do build', BUILD_ID);
        // `cache: 'reload'` fura o cache HTTP: nomes sem hash (index.html,
        // canvaskit.wasm, ícones) mudam de conteúdo sem mudar de URL, e sem
        // isto o install guardaria a cópia velha que o navegador ainda tem.
        // Um arquivo que falhou (rede instável, deploy no meio) não pode
        // derrubar a instalação inteira: o que entrou fica, o resto entra no
        // cache de runtime quando for pedido.
        await Promise.allSettled(
          nucleo.map(async (url) => {
            const resposta = await fetch(url, {cache: 'reload'});
            if (!resposta.ok) {
              throw new Error(`${url}: ${resposta.status}`);
            }
            await cache.put(url, resposta);
          })
        );
      } catch (erro) {
        console.warn('Devocional: pré-cache incompleto', erro);
      }
    })()
  );
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil(
    (async () => {
      try {
        const manifesto = await lerManifesto();
        const validos = new Set(
          manifesto.entries.map((entrada) => new URL(entrada.url, ESCOPO).pathname)
        );
        const cache = await caches.open(CACHE);
        const chaves = await cache.keys();
        await Promise.all(
          chaves.map((requisicao) => {
            const caminho = new URL(requisicao.url).pathname;
            // Navegações (`/devocional/hoje`) não estão no manifesto e são
            // sobrescritas a cada visita online; delas não se limpa nada.
            const doBuild =
              caminho.includes('/assets/') ||
              caminho.includes('/canvaskit/') ||
              /\/main\.dart\.[^/]+\.js$/.test(caminho);
            if (doBuild && !validos.has(caminho)) {
              return cache.delete(requisicao);
            }
            return Promise.resolve(false);
          })
        );
      } catch (_) {
        // Sem rede para ler o manifesto: mantém o cache como está. Um build
        // antigo a mais não quebra nada — os hashes novos não colidem.
      }
      await self.clients.claim();
    })()
  );
});

async function navegar(requisicao) {
  const cache = await caches.open(CACHE);
  // Rede primeiro para pegar o index.html novo; sem rede (ou rede que não
  // responde), o app shell em cache assume. O teto de 4 s evita ficar preso
  // no "carregando" quando a conexão existe mas não entrega.
  const controle = new AbortController();
  const relogio = setTimeout(() => controle.abort(), 4000);
  try {
    const resposta = await fetch(requisicao, {signal: controle.signal});
    clearTimeout(relogio);
    if (resposta && resposta.ok) {
      // Chave pela URL, não pelo Request de navegação: o Cache API não aceita
      // um Request com mode "navigate" como chave.
      cache.put(requisicao.url, resposta.clone()).catch(() => {});
    }
    return resposta;
  } catch (_) {
    clearTimeout(relogio);
    return (await cache.match(requisicao.url)) ||
      (await cache.match(INDICE)) ||
      new Response(
        '<!DOCTYPE html><meta charset="utf-8"><title>Devocional</title>' +
          '<p>Sem conexão. Abra o Devocional uma vez com internet para ' +
          'usá-lo offline.</p>',
        {status: 503, headers: {'Content-Type': 'text/html; charset=utf-8'}}
      );
  }
}

async function servir(requisicao, evento) {
  const cache = await caches.open(CACHE);
  const caminho = new URL(requisicao.url).pathname;
  const emCache = await cache.match(requisicao);

  if (emCache) {
    // Arquivo com hash no nome é imutável e o CanvasKit é grande demais para
    // baixar de novo em segundo plano a cada página: o install já o troca por
    // inteiro quando o build muda (o BUILD_ID muda os bytes do worker). Os
    // poucos arquivos pequenos sem hash (ícones, favicon) são revalidados.
    if (!ARQUIVO_COM_HASH.test(caminho) && !caminho.includes('/canvaskit/')) {
      evento.waitUntil(
        fetch(requisicao, {cache: 'no-store'})
          .then((resposta) => {
            if (resposta && resposta.ok) return cache.put(requisicao, resposta);
          })
          .catch(() => {})
      );
    }
    return emCache;
  }

  const resposta = await fetch(requisicao);
  if (resposta && resposta.ok && resposta.type === 'basic') {
    cache.put(requisicao, resposta.clone()).catch(() => {});
  }
  return resposta;
}

self.addEventListener('fetch', (evento) => {
  const requisicao = evento.request;
  if (requisicao.method !== 'GET') return;

  const url = new URL(requisicao.url);
  if (url.origin !== self.location.origin) return;
  // O próprio service worker e o manifesto do build não são conteúdo do app;
  // deixá-los passar direto evita servir uma versão velha do manifesto no
  // momento em que ele é mais necessário (a instalação).
  if (
    url.pathname.endsWith('/firebase-messaging-sw.js') ||
    url.pathname.endsWith('/precache_manifest.json') ||
    url.pathname.endsWith('/flutter_service_worker.js')
  ) {
    return;
  }
  // Requisição parcial (Range) não cabe no Cache Storage: o Cache API não
  // representa 206, e guardar o pedaço inteiro estragaria o áudio.
  if (requisicao.headers.has('range')) return;

  if (requisicao.mode === 'navigate') {
    evento.respondWith(navegar(requisicao));
    return;
  }
  evento.respondWith(servir(requisicao, evento));
});
