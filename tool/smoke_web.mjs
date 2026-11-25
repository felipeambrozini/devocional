#!/usr/bin/env node
// Smoke test do Tabernáculo publicado.
//
// Roda depois do deploy (ver .github/workflows/deploy-web.yml) e responde a
// uma pergunta só: o que está no ar é o build que acabou de ser publicado, e
// o caminho do app (shell, service worker, offline, API de erro) responde como
// o esperado? Não é um teste de navegador: sem Playwright, só HTTP — o que
// pega deploy quebrado, cache velho e rewrite ausente, que é o que mais
// acontece.
//
// Uso:
//   node tool/smoke_web.mjs
//   SMOKE_BUILD_ID=<sha> node tool/smoke_web.mjs
//   SMOKE_BASE_URL=http://localhost:5000 node tool/smoke_web.mjs
//
// Com SMOKE_BUILD_ID, espera o service worker publicado conter o SHA antes de
// checar o resto: é o sinal de que o Hosting já está servindo o build novo, e
// evita falha por propagação de CDN.

const BASE = (process.env.SMOKE_BASE_URL || 'https://www.felipeambrozini.com.br')
  .replace(/\/+$/, '');
const APP = '/tabernaculo';
const BUILD_ID = process.env.SMOKE_BUILD_ID || '';
const ESPERA_MS = Number(process.env.SMOKE_ESPERA_MS || 5000);
const TENTATIVAS = Number(process.env.SMOKE_TENTATIVAS || 24);

let falhas = 0;

function ok(nome) {
  console.log(`ok    ${nome}`);
}

function falhou(nome, detalhe) {
  falhas++;
  console.log(`FALHA ${nome}\n      ${detalhe}`);
}

function conferir(condicao, mensagem) {
  if (!condicao) throw new Error(mensagem);
}

async function pedir(caminho, opcoes = {}) {
  return fetch(BASE + caminho, {
    redirect: 'manual',
    signal: AbortSignal.timeout(60000),
    ...opcoes,
  });
}

async function esperar(descricao, verificacao) {
  let ultimo;
  for (let tentativa = 1; tentativa <= TENTATIVAS; tentativa++) {
    try {
      await verificacao();
      return;
    } catch (erro) {
      ultimo = erro;
      if (tentativa < TENTATIVAS) {
        await new Promise((resolver) => setTimeout(resolver, ESPERA_MS));
      }
    }
  }
  throw new Error(
    `${descricao} não ficou pronto em ${(TENTATIVAS * ESPERA_MS) / 1000}s: ` +
    `${ultimo?.message ?? ultimo}`,
  );
}

async function caso(nome, verificacao) {
  try {
    await verificacao();
    ok(nome);
  } catch (erro) {
    falhou(nome, erro.message);
  }
}

// O build novo chega ao CDN alguns segundos depois do deploy. O worker tem o
// SHA do commit no corpo (substituído no CI), então ele é o marcador exato.
if (BUILD_ID) {
  try {
    await esperar('o build novo no ar', async () => {
      const resposta = await pedir(`${APP}/firebase-messaging-sw.js`);
      conferir(resposta.ok, `status ${resposta.status}`);
      const texto = await resposta.text();
      conferir(texto.includes(BUILD_ID), 'service worker ainda é o anterior');
    });
    ok(`build ${BUILD_ID.slice(0, 12)} já está no ar`);
  } catch (erro) {
    falhou('build novo no ar', erro.message);
  }
}

await caso('página inicial responde com HTML e metadados', async () => {
  const resposta = await pedir(`${APP}/`);
  conferir(resposta.status === 200, `status ${resposta.status}`);
  conferir(
    (resposta.headers.get('content-type') || '').includes('text/html'),
    'content-type não é HTML',
  );
  const html = await resposta.text();
  conferir(html.includes('lang="pt-BR"'), 'falta lang="pt-BR"');
  conferir(html.includes('rel="manifest"'), 'falta o manifest');
  conferir(
    html.includes("register('/tabernaculo/firebase-messaging-sw.js'"),
    'o index.html não registra o service worker do app',
  );
  conferir(html.includes('/tabernaculo/api/erro'), 'falta o beacon de erro');
  conferir(
    (resposta.headers.get('cache-control') || '').includes('no-cache'),
    'index.html sem no-cache',
  );
  conferir(
    resposta.headers.get('x-content-type-options') === 'nosniff',
    'falta X-Content-Type-Options',
  );
  conferir(
    (resposta.headers.get('content-security-policy') || '')
      .includes("frame-ancestors 'none'"),
    'falta a CSP de frame-ancestors',
  );
  conferir(
    (resposta.headers.get('strict-transport-security') || '')
      .includes('max-age='),
    'falta HSTS',
  );
});

await caso('bootstrap é o próprio, sem o service worker do Flutter', async () => {
  const resposta = await pedir(`${APP}/flutter_bootstrap.js`);
  conferir(resposta.status === 200, `status ${resposta.status}`);
  const texto = await resposta.text();
  // O loader do Flutter carrega a biblioteca inteira no arquivo e cita
  // `serviceWorkerSettings` no código dela; o que importa é a chamada final,
  // que é a nossa e vai sem settings. Procurar a string no arquivo daria
  // falso negativo em todo build.
  conferir(
    /_flutter\.loader\.load\(\s*\)\s*;?\s*$/.test(texto),
    'o load() final não é o nosso, sem serviceWorkerSettings',
  );
});

await caso('manifest PWA tem escopo, idioma e ícones', async () => {
  const resposta = await pedir(`${APP}/manifest.json`);
  conferir(resposta.status === 200, `status ${resposta.status}`);
  const manifest = await resposta.json();
  conferir(manifest.lang === 'pt-BR', 'lang ausente ou diferente de pt-BR');
  conferir(typeof manifest.scope === 'string', 'falta scope');
  conferir(manifest.display === 'standalone', 'display não é standalone');
  conferir(
    Array.isArray(manifest.icons) && manifest.icons.length >= 4,
    'faltam os ícones',
  );
});

await caso('precache_manifest.json lista o build com hash', async () => {
  const resposta = await pedir(`${APP}/precache_manifest.json`);
  conferir(resposta.status === 200, `status ${resposta.status}`);
  const manifesto = await resposta.json();
  conferir(
    Array.isArray(manifesto.entries) && manifesto.entries.length > 100,
    'manifesto vazio ou pequeno demais',
  );
  const principal = manifesto.entries.find((entrada) =>
    /^main\.dart\.[0-9a-f]+\.js$/.test(entrada.url));
  conferir(principal, 'main.dart com hash não está no manifesto');
  const comHash = manifesto.entries.filter((entrada) => entrada.urlHashed);
  conferir(comHash.length > 100, 'quase nada tem hash de conteúdo');

  // O arquivo principal precisa existir e ser servido como imutável; sem
  // isso, o cache offline guarda um nome que o Hosting não serve.
  const arquivo = await pedir(`${APP}/${principal.url}`, {method: 'HEAD'});
  conferir(arquivo.status === 200, `main.dart: status ${arquivo.status}`);
  conferir(
    (arquivo.headers.get('cache-control') || '').includes('immutable'),
    'main.dart com hash não é imutável',
  );
});

await caso('service worker tem push e cache offline', async () => {
  const resposta = await pedir(`${APP}/firebase-messaging-sw.js`);
  conferir(resposta.status === 200, `status ${resposta.status}`);
  conferir(
    (resposta.headers.get('content-type') || '').includes('javascript'),
    'content-type não é JavaScript',
  );
  conferir(
    (resposta.headers.get('cache-control') || '').includes('no-cache'),
    'worker sem no-cache',
  );
  const texto = await resposta.text();
  conferir(
    texto.includes('firebase-messaging-compat'),
    'falta o SDK de mensagens',
  );
  conferir(
    texto.includes("addEventListener('fetch'"),
    'falta o handler de cache offline',
  );
  conferir(
    texto.includes('precache_manifest.json'),
    'o worker não usa o manifesto do build',
  );
  conferir(
    !texto.includes('__FIREBASE_API_KEY_WEB__'),
    'os secrets do Firebase não foram preenchidos no worker',
  );
});

await caso('rota interna cai no index.html do app', async () => {
  const resposta = await pedir(`${APP}/hoje`);
  conferir(resposta.status === 200, `status ${resposta.status}`);
  conferir(
    (resposta.headers.get('content-type') || '').includes('text/html'),
    'rota interna não devolve HTML',
  );
  const html = await resposta.text();
  conferir(html.includes('<title>Tabernáculo</title>'), 'não é o index do app');
});

await caso('API de erro está publicada pelo rewrite', async () => {
  // GET de propósito: a Function responde 405 JSON, o que prova o rewrite e a
  // Function juntos. Um 404 aqui costuma ser a Function ainda subindo.
  let ultima = null;
  for (let tentativa = 1; tentativa <= 12; tentativa++) {
    const resposta = await pedir(`${APP}/api/erro`);
    if (resposta.status === 405) {
      conferir(
        (resposta.headers.get('content-type') || '').includes('application/json'),
        '405 sem JSON',
      );
      return;
    }
    ultima = resposta.status;
    await new Promise((resolver) => setTimeout(resolver, ESPERA_MS));
  }
  throw new Error(`status ${ultima} (esperado 405)`);
});

await caso('robots.txt e sitemap continuam na raiz', async () => {
  const robots = await pedir('/robots.txt');
  conferir(robots.status === 200, `robots: status ${robots.status}`);
  conferir((await robots.text()).includes('Sitemap:'), 'robots sem sitemap');
  const sitemap = await pedir('/sitemap.xml');
  conferir(sitemap.status === 200, `sitemap: status ${sitemap.status}`);
});

console.log(falhas === 0 ? '\nSite publicado ok.' : `\n${falhas} falha(s).`);
process.exit(falhas === 0 ? 0 : 1);
