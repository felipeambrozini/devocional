Este documento descreve as diretrizes e práticas de segurança aplicadas ao projeto **Devocional**, incluindo o processo para reporte de vulnerabilidades, arquitetura de proteção de dados e gestão de segredos.

---

## 1. Versões Suportadas

Apenas a versão mais recente em execução no ambiente de produção (Web via Firebase Hosting, em `https://www.felipeambrozini.com.br/devocional/`) e os builds oficiais do aplicativo Android recebem atualizações diretas de segurança.

| Plataforma | Suporte a Correções de Segurança |
| :--- | :--- |
| Web (Firebase Hosting) | :white_check_mark: Suportado (Versão Atual) |
| Android (APK / App) | :white_check_mark: Suportado (Versão Atual) |
| Builds legados ou não oficiais | :x: Não suportado |

---

## 2. Arquitetura de Segurança e Privacidade de Dados

O aplicativo foi projetado com o princípio de exposição mínima de dados e processamento prioritariamente local.

### 2.1 Ausência de Cookies e Publicidade
O aplicativo **não grava nenhum cookie**, não tem anúncio e não vende nem compartilha dados com terceiros para fins de publicidade. Na web, as preferências e o progresso ficam no `localStorage` (via `shared_preferences`) e a sessão do Firebase Auth no `IndexedDB` — armazenamento estritamente necessário ao funcionamento, sob o domínio do próprio app. Por isso não há banner de consentimento de cookies: não existe cookie de terceiro nem finalidade de rastreamento que o exija sob a LGPD. A coleta remota opcional (erro e uso anônimo) é descrita em 2.4, à parte, porque depende de aceite explícito do usuário.

### 2.2 Armazenamento Local
Progresso de leitura, anotações e versículos favoritos são salvos localmente por meio do `shared_preferences` em todas as plataformas (Android, iOS e web). Quem não entra com conta usa o app inteiro assim, sem nada saindo do aparelho.

### 2.3 Sincronização na Nuvem e Autenticação
- **Plataformas:** A sincronização com a nuvem (Firebase) está disponível em Android, iOS e web — `nuvemSuportada` (`lib/data/nuvem.dart`) não distingue plataforma. O login nativo (Android/iOS) usa `GoogleSignIn.instance.authenticate()` mais `signInWithCredential`; a web usa `signInWithPopup` em desktop e `signInWithRedirect` em navegador mobile, onde o popup falha ao trocar o token com a janela original por causa do armazenamento particionado do navegador.
- **Segurança no Firestore:** Cada usuário autenticado possui acesso exclusivo ao seu próprio documento localizado no caminho `usuarios/{uid}`.
- **Regras de Acesso:** O acesso aos dados no Cloud Firestore é protegido por regras rígidas de segurança (`firestore.rules`), garantindo que apenas o proprietário autenticado (`request.auth.uid == userId`) possa ler ou escrever em seu respetivo documento. A remoção de dados locais não apaga registros na nuvem, atuando a sincronização por fusão (*merge*). Apagar a conta (Sobre → Conta e privacidade) remove também a foto de perfil e a participação em planos compartilhados, além do documento e da própria conta.

### 2.4 Coleta Remota Opcional (Sentry e Analytics)
Na primeira abertura, o app pergunta se o usuário autoriza o envio de dois tipos de informação sem identificação: erro técnico (Sentry, web e Android) e uso anônimo por tela (Firebase Analytics). As duas ficam desligadas por padrão — `Registro.envioRemotoPermitido` começa `false` e o `beforeSend` do Sentry descarta qualquer evento até a resposta chegar (`lib/main.dart`); a aplicação da escolha aos dois SDKs vive em `lib/data/coleta.dart`, único ponto que liga Firebase Analytics à decisão do usuário. A resposta pode ser revista a qualquer momento em Sobre. Nenhum dos dois canais recebe o texto lido, escrito ou de conversas.

---

## 3. Gestão de Chaves de API e Segredos

### 3.1 Injeção de Variáveis em Tempo de Compilação
As chaves e parâmetros necessários para o funcionamento dos serviços integrados (Firebase, IA Gemini, Sentry) não são mantidos estáticos no código-fonte. Eles são injetados exclusivamente em tempo de compilação via parâmetros `--dart-define`, lidos por `String.fromEnvironment` em `lib/data/google.dart`, `lib/firebase_options.dart` e nos poucos outros pontos que os usam diretamente. Nenhum trafega como *asset* do aplicativo — o arquivo local `.env.json` serve apenas ao `--dart-define-from-file` durante o desenvolvimento e nunca é empacotado no build:

- `FIREBASE_API_KEY_WEB`, `FIREBASE_API_KEY_ANDROID`, `FIREBASE_API_KEY_IOS`
- `GEMINI_API_KEY_WEB`, `GEMINI_API_KEY_ANDROID`, `GEMINI_API_KEY_IOS`
- `FCM_VAPID_KEY` (chave pública do Web Push, para o lembrete diário na web)
- `AUDIO_BASE_URL` (origem dos MP3 pré-gerados da leitura em voz alta)
- `RECAPTCHA_V3_SITE_KEY` (App Check na web, ver 3.3)
- `EMAILS_COM_CONVERSAS` (allowlist do chat com IA, ver `lib/data/recursos.dart` — nenhum e-mail fica versionado no repositório)
- `SENTRY_DSN` (destino do reporte de erro remoto, ver 2.4 — vazio localiza o SDK em modo no-op)
- `EMAIL_DE_CONTATO` (destino de "Relatar um problema" em Sobre; vazio esconde o item)

Não há mais chave de Text-to-Speech: o áudio virou MP3 pré-gerado (ver `lib/data/voz.dart`), e as antigas `TTS_API_KEY_*` devem ser revogadas no Google Cloud Console, já que nenhum `String.fromEnvironment` no código as lê mais.

### 3.2 Proteção de Chaves Públicas
Conforme a arquitetura padrão para aplicações no lado do cliente (Web e Mobile), as chaves do Firebase e do Google Cloud presentes nos artefatos de compilação são consideradas públicas por desenho. A segurança dos serviços é assegurada por:

1. **Restrição de Origem no Google Cloud Console:** As chaves de API da Web são restritas por referenciador HTTP ao domínio de produção (`https://www.felipeambrozini.com.br/*`) e ao domínio do próprio projeto Firebase. Como o cabeçalho de referenciador é forjável por um cliente fora do navegador, as APIs Gemini e Text-to-Speech contam ainda com cota diária e alerta de faturamento no projeto, que é o limite efetivo de abuso.
2. **Restrição de Escopo de APIs:** As chaves do serviço de voz (Text-to-Speech) e de inteligência artificial possuem escopo limitado estritamente às APIs necessárias para a execução do app.
3. **Regras do Banco de Dados:** O acesso aos dados no Firestore independe da chave de API, sendo controlado integralmente pelas regras de autenticação do backend do Firebase.

### 3.3 Firebase App Check
Além da chave, o app se identifica ao Firestore e ao Auth com uma prova de que o pedido vem do próprio aplicativo, não de um cliente forjado com a mesma chave pública copiada do bundle (ver `lib/data/nuvem.dart`, função `Sincronia.iniciar`):

- **Web:** reCAPTCHA v3, com o *site key* também injetado por `--dart-define` (`RECAPTCHA_V3_SITE_KEY`).
- **Android:** Play Integrity, por atestação do próprio Google Play — sem chave de app.
- **iOS:** App Attest, com retorno a DeviceCheck em versões anteriores ao iOS 14 — sem chave de app.

A falha em ativar o App Check (site key ausente durante a migração, domínio ainda não registrado no console) não impede o app de abrir; a sincronização e o login simplesmente continuam sem essa camada extra até a configuração ser concluída no console do Firebase.

### 3.4 Lembrete Diário — Push com Reserva Local no Android

O lembrete diário é híbrido: uma Cloud Function agendada (`functions/src/index.ts`, `enviarLembretes`) lê a coleção `lembretes` do Firestore a cada minuto e envia push via FCM em Android e web; no Android, `flutter_local_notifications` ainda arma uma reserva local em T+5 min, para o caso de o push não chegar. A superfície de permissão local se resume a POST_NOTIFICATIONS, concedida em runtime — sem pedir a permissão especial de alarme exato: o agendamento local é sempre inexato de propósito (ver `lib/data/lembretes.dart`).

---

## 4. Segurança do Pipeline de Integração e Implantação (CI/CD)

- **Cabeçalhos de Segurança no Hosting:** O `firebase.json` define `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` negando geolocalização, câmera, microfone, pagamento e USB, e `Content-Security-Policy: frame-ancestors 'none'` (proteção contra *clickjacking*). O HTTPS e o `Strict-Transport-Security` são reforçados sobre o padrão do Firebase Hosting.
- **Fixação de Commit SHA no GitHub Actions:** Todas as ações do GitHub Actions utilizadas no fluxo de *deploy* automatizado (`.github/workflows/deploy-web.yml`) estão fixadas pelo SHA completo do *commit*, prevenindo riscos associados a *tags* mutáveis.
- **Versão Imutável do SDK:** A versão do SDK do Flutter é mantida fixa em `3.44.9` via `.fvmrc` e no pipeline de integração contínua, garantindo reproduzibilidade e prevenindo quebras não auditadas.
- **Segredos do Repositório:** As chaves de compilação de produção são gerenciadas através dos *GitHub Secrets* e disponibilizadas exclusivamente durante o processo de compilação automatizada.
- **Job agendado do lembrete diário:** não é um workflow do GitHub Actions — é a Cloud Function `enviarLembretes` (`functions/src/index.ts`), publicada por `deploy-web.yml` junto com `hosting` e `firestore:rules` (`firebase deploy --only hosting,firestore:rules,functions`), autenticada com o mesmo `FIREBASE_SERVICE_ACCOUNT` do deploy — nenhum segredo novo para esse fluxo.

---

## 5. Reportando uma Vulnerabilidade

Caso você identifique uma falha de segurança, vulnerabilidade de exposição de dados ou comportamento inadequado no aplicativo, pedimos que faça o reporte de maneira responsável.

### Como Reportar
**Não abra uma issue pública no GitHub para reportar vulnerabilidades de segurança.**

Em vez disso, utilize o recurso de **Security Advisories** na guia de segurança do repositório no GitHub ou entre em contato diretamente com o mantenedor do projeto.

Ao enviar o relatório, inclua:
1. Descrição clara da vulnerabilidade ou falha encontrada.
2. Passos detalhados para reprodução do problema.
3. Cenário e impacto potencial de exploração.
4. Sugestões de correção, caso possua.

### Prazos de Resposta
- **Confirmação do Recebimento:** Até 48 horas úteis.
- **Análise e Validação:** Até 5 dias úteis.
- **Aplicação da Correção:** As correções validadas serão aplicadas prioritariamente no pipeline e publicadas em produção assim que homologadas.
