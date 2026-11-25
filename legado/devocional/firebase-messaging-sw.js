// Service worker de despedida do endereço antigo (/devocional/).
//
// Quem usou o app antes da versão 1.28 tem um worker registrado com escopo
// /devocional/: ele guarda o app velho para abrir offline e recebe os
// lembretes. O navegador procura atualização deste arquivo ao abrir uma página
// do escopo e ao receber um push; quando acha esta versão, ela entra no lugar
// da antiga, se desregistra e manda as janelas abertas para /tabernaculo/, onde
// o app novo registra o próprio worker e a própria inscrição de lembretes. A
// inscrição antiga morre junto, e a Function apaga o token quando o FCM disser
// que ele não existe mais.
//
// Os caches são do domínio inteiro, não do escopo: o app novo usa os mesmos
// (`devocional-offline` e o áudio baixado em `devocional-audio`). Daqui só
// saem as entradas do build antigo, com caminho em /devocional/; o áudio
// baixado fica.

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (evento) => {
  evento.waitUntil(
    (async () => {
      try {
        const cache = await caches.open('devocional-offline');
        const chaves = await cache.keys();
        await Promise.all(
          chaves
            .filter((requisicao) =>
              new URL(requisicao.url).pathname.startsWith('/devocional/')
            )
            .map((requisicao) => cache.delete(requisicao))
        );
      } catch (_) {
        // Sem acesso ao cache: sobra espaço ocupado, nada quebra.
      }
      await self.registration.unregister();
      const janelas = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      await Promise.all(
        janelas.map((janela) => {
          const url = new URL(janela.url);
          if (!url.pathname.startsWith('/devocional')) return null;
          const caminho = url.pathname.replace(/^\/devocional(?=\/|$)/, '/tabernaculo');
          return janela
            .navigate((caminho === '/tabernaculo' ? '/tabernaculo/' : caminho) + url.search + url.hash)
            .catch(() => null);
        })
      );
    })()
  );
});
