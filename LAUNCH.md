# Lançamento público (1º de janeiro de 2027)

O público do lançamento é a web e o PWA em
`https://www.felipeambrozini.com.br/devocional/`. O aplicativo Android continua
só para testadores, pelo Firebase App Distribution, sem listagem em loja; iOS
não é distribuído ao público.

Este arquivo separa o que já está no código do que depende de console ou DNS.
A última seção lista o roteiro de virada.

## Pronto no código

- **Offline no PWA.** Um service worker único
  (`web/firebase-messaging-sw.js`) cuida do cache offline e do push do
  lembrete. O build usa `--web-content-hash --no-web-resources-cdn`; o
  `precache_manifest.json` gerado alimenta o `install` (shell, fontes,
  CanvasKit da variante do motor, ícones, capas) e o conteúdo entra em cache
  conforme é lido. Navegação é rede-primeiro com teto de 4 s e cai no shell em
  cache.
  O `flutter_service_worker.js` não é registrado e é removido no deploy.
- **PWA e SEO.** `web/manifest.json` com `id`, `scope`, `lang`, `dir`,
  `start_url`, `categories` e ícones maskable; `web/index.html` com
  `lang="pt-BR"`, canonical, Open Graph, tema claro/escuro, JSON-LD e
  carregamento com tela de espera. `robots.txt`, `sitemap.xml` e `llms.txt` na
  raiz do domínio.
- **Portão de 18 anos.** `DevocionalPortaoDeIdade` precede o chat; a
  declaração fica por aparelho/navegador (`Estado.maiorDeIdade`) e não sobe
  para a nuvem.
- **Denúncia de resposta da IA.** "Denunciar resposta" nas falas das personas
  grava `denuncias/{id}` (create-only, uid da própria conta) com pergunta,
  resposta, motivo e detalhe opcional, sem e-mail nem nome no texto.
- **Monitoramento de erros.** Beacon no `index.html` e
  `lib/dados/monitoramento.dart` enviam falha técnica para a Function
  `registrarErro` via `/devocional/api/erro`; agregação por hash em `erros`,
  limite no cliente e no servidor, sem PII, sem query string e sem texto
  digitado. Sem Sentry e sem Analytics.
- **Cache e cabeçalhos.** Shell e entrypoints sem cache; arquivo com hash
  imutável por um ano; `canvaskit/**` por uma hora; segurança
  (`nosniff`, CSP de frame-ancestors, HSTS, Referrer-Policy,
  Permissions-Policy) em todas as respostas.
- **Smoke test pós-deploy.** `tool/smoke_web.mjs` roda no fim do
  `deploy-web.yml`, espera o SHA do commit no service worker publicado e
  confere shell, manifestos, rewrite da API, cabeçalhos e rota interna. Falha
  o job, não a visita.
- **Testes.** `flutter analyze`, `flutter test`, testes das regras no emulador
  e testes das Functions rodam antes do deploy.

## Depende de console ou DNS (fora do repositório)

Estes itens não se resolvem em código e precisam ser feitos à mão antes ou
depois da virada:

1. **DNS do apex.** `felipeambrozini.com.br` sem registro A/AAAA: hoje só
   `www` (CNAME para `devocional-15815.web.app`) responde. Publicar o apex e
   redirecionar para `www` no Firebase Hosting.
2. **OAuth consent screen.** Publicar o app (sair de "Testing") para que
   contas fora da lista de testadores possam entrar com Google.
3. **Firestore: PITR e backup.** Ligar point-in-time recovery e a exportação
   agendada no console; nenhum dos dois tem configuração no repositório.
4. **Permissão do service account do deploy.** Já concedido neste projeto
   (19/11/2026): **Cloud Functions Admin**
   (`roles/cloudfunctions.admin`) na conta de serviço de
   `FIREBASE_SERVICE_ACCOUNT`. Publicar a primeira Function HTTPS pública
   (`registrarErro`, `invoker: public`) exige
   `cloudfunctions.functions.setIamPolicy`, que o papel usado para Hosting e
   Firestore não dá. Num projeto novo, conceder antes do primeiro deploy.
5. **Orçamento e cotas.** Alertas de orçamento no Cloud Billing e limite de
   cota para a Gemini API e para a Function pública de erro.
6. **Restrições da chave Gemini.** Restringir a chave web por referenciador e
   a Android/iOS por pacote/assinatura no Console do Google Cloud.
7. **Teste em aparelho real.** iPhone (Safari, instalar na tela de início e
   push) e Android (Chrome e APK de testador) com rede instável e offline.
   O comportamento do service worker e do CanvasKit varia por motor.

## Roteiro de virada

1. Confirmar os itens de console/DNS acima.
2. Rodar localmente `fvm flutter analyze && fvm flutter test`,
   `npm --prefix functions test` e `npm --prefix test_regras test`.
3. Fazer o push para `main`: o `deploy-web.yml` publica functions, Hosting,
   regras do Firestore e do Storage, e roda o smoke test com o SHA do commit.
4. Conferir no console do Firebase a coleção `erros` (vazia ou só com falhas
   esperadas) e abrir o site publicado no celular: instalar como app, abrir um
   capítulo, ativar o modo avião e reabrir a mesma leitura.
5. Divulgar o link público. O Android segue pelo App Distribution.
