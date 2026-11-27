# Política de Segurança

Este documento descreve as diretrizes e práticas de segurança aplicadas ao
projeto **Devocional**, incluindo o processo para reporte de vulnerabilidades,
arquitetura de proteção de dados e gestão de segredos.

---

## 1. Versões Suportadas

Apenas a versão mais recente em execução no ambiente de produção (Web via
Firebase Hosting, em `https://www.felipeambrozini.com.br/tabernaculo/`) e os
builds oficiais do aplicativo Android recebem atualizações diretas de segurança.

| Plataforma | Suporte a Correções de Segurança |
| :--- | :--- |
| Web (Firebase Hosting) | :white_check_mark: Suportado (Versão Atual) |
| Android (APK / App) | :white_check_mark: Suportado (Versão Atual) |
| Builds legados ou não oficiais | :x: Não suportado |

---

## 2. Arquitetura de Segurança e Privacidade de Dados

O aplicativo foi projetado com o princípio de exposição mínima de dados e
processamento prioritariamente local. Os pontos em que algo sai do aparelho
estão descritos abaixo: a sincronia da conta (2.3), o cadastro do lembrete
diário (2.2 e 3.4), o chat com IA, que fala com a API Gemini (2.5), as
denúncias de resposta (2.6) e os relatórios de erro próprios, sem PII (2.4).

### 2.1 Ausência de Cookies, Publicidade e SDKs de Terceiros

O aplicativo **não grava cookie próprio**, não tem anúncio, não vende nem
compartilha dados com terceiros para fins de publicidade e **não usa SDK de
terceiros para monitoramento nem Analytics**. O monitoramento é próprio e
mínimo (2.4): na web de release, erros técnicos vão para uma Cloud Function do
próprio projeto, sem texto digitado, sem conversa, sem e-mail e sem uid.
"Relatar um problema" (Sobre) abre e-mail com a versão já preenchida. Na web,
as preferências e o progresso ficam no `localStorage` (via
`shared_preferences`) e a sessão do Firebase Auth no `IndexedDB` —
armazenamento estritamente necessário ao funcionamento, sob o domínio do
próprio app. O único terceiro que pode gravar cookie é o reCAPTCHA v3 do App
Check (ver 3.3), para separar o app de scripts, sem finalidade de rastreamento
nem de anúncio; a política de privacidade o declara. Por isso não há banner de
cookies. O que há é o consentimento da LGPD para os dados sensíveis
da conta (favoritos, anotações, progresso, planos e conversas revelam convicção
religiosa): `TabernaculoConsentimentoDaNuvem` aparece antes do primeiro login no
aparelho e, para quem já tinha a sessão aberta, ao abrir o app
(`Estado.consentimentoDaNuvem`). Sem esse consentimento neste aparelho nenhuma
sincronia da conta começa, a dos planos (próprios e compartilhados) inclusive:
nada sobe nem desce. Consentir chama `Nuvem.aoConsentir`, que liga as sincronias
e traz os planos da conta.

### 2.2 Armazenamento Local

Progresso de leitura, anotações e versículos favoritos são salvos localmente por
meio do `shared_preferences` em todas as plataformas (Android, iOS e web). Quem
não entra com conta usa o app inteiro assim, e nada da leitura (progresso,
notas, favoritos) sai do aparelho. A única gravação remota sem conta é opcional:
ao ligar o lembrete diário, o app grava em `lembretes/{fid}` o identificador da
instalação do Firebase (FID), os quatro horários escolhidos e o fuso horário,
para a Cloud Function saber quando mandar o push (ver 2.3 e 3.4); desligar o
lembrete apaga o documento.

### 2.3 Sincronização na Nuvem e Autenticação

- **Plataformas:** A sincronização com a nuvem (Firebase) está disponível em
  Android, iOS e web — `Nuvem.iniciar` (`lib/dados/nuvem.dart`) não distingue
  plataforma. O login nativo (Android/iOS) usa
  `GoogleSignIn.instance.authenticate()` mais `signInWithCredential`; a web usa
  `signInWithPopup` em desktop e `signInWithRedirect` em navegador mobile, onde
  o popup falha ao trocar o token com a janela original por causa do
  armazenamento particionado do navegador.
- **Segurança no Firestore:** Os dados da conta (cópia de favoritos, notas e
  progresso, conversas, horários do lembrete, planos e leitura da Biblioteca)
  ficam num único documento por usuário, `usuarios/{uid}`. Os planos
  compartilhados e o cadastro do lembrete moram em coleções à parte, com regras
  próprias (abaixo).
- **Regras de Acesso (`firestore.rules`, publicadas pelo CI a cada push na
  `main`):** o padrão do Firestore nega tudo, e cada coleção abre só o
  necessário:
  - `usuarios/{uid}`: só o dono lê, cria, altera e apaga, com
    `request.auth.uid == uid` e login pelo provedor Google
    (`sign_in_provider == 'google.com'`). Toda escrita passa ainda por validação
    de esquema: só os campos do contrato (`copia`, `conversas`, `lembretes`,
    `planos`, `livros`, `atualizadoEm`), com tipos e tetos de tamanho.
  - `planos/{planoId}` (planos compartilhados): exige login Google. Qualquer
    participante lê o documento inteiro, inclusive o **nome e os dias lidos dos
    outros participantes**, que é o que mostra o progresso de todos. Cada um
    escreve só a própria entrada (entrar, marcar dias, sair); só o criador edita
    título, livros, dias e devocionais ou apaga o plano. Quem tem o link (o id
    do plano) pode se incluir como participante e, daí em diante, lê o plano.
  - `config/recursos` (interruptores do painel admin): leitura (`get`) pública,
    sem login, porque o gating precisa funcionar antes de qualquer login; listar
    é negado; só o dono (e-mail da conta Google mais provedor Google) escreve,
    com esquema validado. Não guarda dado de usuário.
  - `convidados/{email}` (convites do chat): cada conta Google lê só o próprio
    convite; só o dono lista, cria e apaga.
  - `lembretes/{fid}` (cadastro do lembrete diário): **sem login**, porque o
    lembrete não pede conta. O id é o FID da instalação (documentos legados usam
    o token FCM). O app grava só `fid` (ou `token`), `minutosManha`,
    `minutosPromessas`, `minutosLeitura`, `minutosNoite` e `fuso`; os campos de
    controle de envio (`ultimoEnvio*`, `proximoEnvio`) são gravados pela Cloud
    Function via Admin SDK. Qualquer cliente pode criar ou alterar um documento
    de formato válido e ler ou apagar um documento pelo id (`get`,
    `delete: if true`), mas listar a coleção é negado: só quem já conhece o
    identificador alcança o documento, e o pior abuso é reagendar o lembrete
    daquela instalação. Nenhum dado de conta ou de leitura passa por aqui.
  - `denuncias/{id}` (denúncia de resposta da IA): só cria, e só com login
    Google e `uid` igual ao da conta. O contrato aceita motivo de uma lista
    fixa, a persona, os ids de conversa e mensagem, a pergunta, a resposta, o
    detalhe e a versão, com tetos de tamanho (20.000 e 30.000 caracteres para
    pergunta e resposta). Ler, alterar e apagar é negado ao cliente: quem
    revisa é o dono, pelo Admin SDK/console.
  - `erros/{hash}` (relatório de erro da web): leitura e escrita negadas ao
    cliente. A Function `registrarErro` grava com o Admin SDK, agregando por
    hash; o app não fala com o Firestore para isso.
- **Regras do Storage (`storage.rules`):** `/audio/**` (os MP3 pré-gerados da
  leitura em voz alta) tem leitura pública e escrita negada ao app; o resto do
  bucket fica no padrão, que nega tudo.
- **Sincronização e exclusão:** A remoção de dados locais não apaga registros na
  nuvem, atuando a sincronização por fusão (*merge*). Apagar a conta (Sobre →
  Conta e privacidade) remove também a participação em planos compartilhados,
  além do documento e da própria conta.

### 2.4 Monitoramento de Erros Próprio, sem PII

O app não tem SDK de terceiros de reporte nem de medição. O que existe é um
canal próprio, só para falha técnica e só na web de release:

- **Origem:** o beacon do `web/index.html` captura `error` e
  `unhandledrejection` antes do primeiro frame; depois dele,
  `Registro.erro` chama `Monitoramento.registrar` (`lib/dados/monitoramento.dart`).
  Não roda em debug nem no Android/iOS (o APK é só de testadores).
- **Conteúdo:** origem, mensagem, pilha, arquivo e linha, contexto, caminho da
  página, versão do app e plataforma. Nunca vão texto digitado, histórico de
  conversa, e-mail, uid, cookie ou query string; o servidor
  (`functions/src/erro.ts`) recorta e rejeita o que estiver fora do contrato.
- **Destino e limites:** POST em `/tabernaculo/api/erro`, rewrite do Hosting para
  a Function `registrarErro` (`invoker: public`, `maxInstances: 10`), que grava
  em `erros/{hash}` com `FieldValue.increment(1)`. O cliente envia no máximo 5
  por sessão, um por mensagem distinta; o servidor aplica limite por cliente e
  por instância e recusa corpo acima de 32 KB. Falhar no envio não afeta o app.
- **Leitura:** só o dono, pelo console/Admin SDK; o cliente não tem acesso à
  coleção.
- **Retenção:** cada gravação põe `expiraEm` 90 dias depois da ocorrência
  (`expiracaoDoErro` em `functions/src/erro.ts`), e a política de TTL do
  Firestore no campo `expiraEm` do grupo `erros` apaga o documento depois
  dessa data. Falha que continua acontecendo empurra a data; a que parou sai
  90 dias depois da última vez, como a política de privacidade promete. A
  política de TTL mora no console (ligada em 27/11/2026), não no repositório.
  As denúncias não têm TTL: o dono apaga cada uma depois de revisar.

O registro local (`lib/dados/registro.dart`) continua no console e, fora da
web, em arquivo no aparelho.

### 2.5 Conversas com IA (Gemini)

Quando o chat está ligado para a conta (interruptor `conversasAtivas` em
`config/recursos` mais um convite em `convidados/{email}`, ver
`lib/dados/recursos.dart`), cada mensagem vai do próprio aparelho direto à API
Gemini do Google (`generativelanguage.googleapis.com`, em `lib/dados/ia.dart`),
com a chave Gemini da plataforma no cabeçalho `x-goog-api-key`. Junto com a
mensagem nova seguem as falas mais recentes daquela conversa e a instrução de
sistema da persona. Não há servidor próprio no meio: o processamento da resposta
é do Google, nos termos da Gemini API (plano pago por uso). Fora o Firebase da
própria conta (2.3), esse é o único serviço que recebe texto escrito pelo
leitor; quem não usa o chat não envia nada a ele.

O chat é restrito a maiores de 18 anos: `TelaChat` não monta histórico nem
campo de mensagem sem `Estado.maiorDeIdade == true`, declarado uma vez por
aparelho/navegador no portão de idade. É autodeclaração documentada no aviso,
não prova de idade.

### 2.6 Denúncias de Resposta da IA

Cada resposta das personas tem "Denunciar resposta". Ao enviar, o app grava
`denuncias/{id}` com a pergunta que antecedeu (se ainda estiver no histórico),
a resposta, o motivo escolhido (`inadequada`, `doutrina`, `fora_do_tema`,
`outro`), o detalhe opcional, a persona, os ids de conversa e mensagem, a
versão e a plataforma. O `uid` do documento é o da conta que denunciou e as
regras exigem que seja igual ao `request.auth.uid`; o e-mail e o nome não
entram no texto. A denúncia serve só para o mantenedor revisar conteúdo e
funcionamento do chat: não é pública, não é lida por outros usuários e não
altera a conversa.

---

## 3. Gestão de Chaves de API e Segredos

### 3.1 Injeção de Variáveis em Tempo de Compilação

No código Dart, as chaves e parâmetros dos serviços integrados (Firebase, IA
Gemini) não ficam escritos no código-fonte: chegam em tempo de compilação por
`--dart-define` (GitHub Secrets no CI) e são lidos por `String.fromEnvironment`
em `lib/dados/google.dart`, `lib/firebase_options.dart`, `lib/dados/nuvem.dart`
e nos poucos outros pontos que os usam diretamente. Nenhum trafega como *asset*
do aplicativo — o arquivo local `.env.json` serve apenas ao
`--dart-define-from-file` durante o desenvolvimento e nunca é empacotado no
build. Fora do Dart há dois caminhos diferentes, ambos com chaves públicas por
desenho (ver 3.2):

- `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist` são
  **versionados** no repositório, com a chave de API do Firebase de cada
  plataforma, como o plugin nativo do Firebase exige.
- `web/firebase-messaging-sw.js` (o service worker do push e do cache
  offline na web) não lê `--dart-define`: o CI (`deploy-web.yml`) troca os
  placeholders `__FIREBASE_...__` pelos secrets com `sed` antes do build.

Variáveis lidas pelo Dart:

- `FIREBASE_API_KEY_WEB`, `FIREBASE_API_KEY_ANDROID`, `FIREBASE_API_KEY_IOS`
- `FIREBASE_APP_ID_WEB`, `FIREBASE_APP_ID_ANDROID`, `FIREBASE_APP_ID_IOS`
- `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`,
  `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MEASUREMENT_ID`
- `FIREBASE_IOS_CLIENT_ID`, `FIREBASE_IOS_BUNDLE_ID`
- `GOOGLE_SERVER_CLIENT_ID` (client ID Web do projeto, para o login Google
  nativo no Android e no iOS, em `lib/dados/nuvem.dart`; não é segredo)
- `GEMINI_API_KEY_WEB`, `GEMINI_API_KEY_ANDROID`, `GEMINI_API_KEY_IOS`
- `FCM_VAPID_KEY` (chave pública do Web Push, para o lembrete diário na web)
- `AUDIO_BASE_URL` (origem dos MP3 pré-gerados da leitura em voz alta)
- `RECAPTCHA_V3_SITE_KEY` (App Check na web, ver 3.3)
- `EMAIL_DE_CONTATO` (destino de "Relatar um problema" em Sobre; vazio esconde o
  item)
- `WHATSAPP_NUMERO` (destino do botão "Falar no WhatsApp" em Conversas, para
  quem pede acesso fora da allowlist; vazio esconde o botão)

Não há mais chave de Text-to-Speech: o áudio virou MP3 pré-gerado (ver
`lib/dados/voz.dart`), e as antigas `TTS_API_KEY_*` devem ser revogadas no
Google Cloud Console, já que nenhum `String.fromEnvironment` no código as lê
mais. Também não há mais `EMAILS_COM_CONVERSAS`: os convidados do chat moram no
Firestore, um documento por conta em `convidados/{email}`, e o painel admin
(`/admin`, só web e só o dono) os edita sem reimplantar — nenhum e-mail fica
versionado no repositório. Cada conta lê apenas o próprio convite, e só o dono
lista a coleção: a lista não fica em `config/recursos` porque esse documento tem
leitura pública. Se o secret antigo ainda existir no GitHub, pode ser apagado;
antes de a configuração e o convite carregarem, o chat fica fechado.

### 3.2 Proteção de Chaves Públicas

Conforme a arquitetura padrão para aplicações no lado do cliente (Web e Mobile),
as chaves do Firebase e do Google Cloud presentes nos artefatos de compilação
são consideradas públicas por desenho. A segurança dos serviços é assegurada
por:

1. **Restrição de Origem no Google Cloud Console:** As chaves de API da Web são
   restritas por referenciador HTTP ao site de produção
   (`https://www.felipeambrozini.com.br/*`) e a `localhost`, para o
   desenvolvimento (ver o comentário em `lib/dados/google.dart`); as chaves
   Gemini de Android e iOS, ao pacote mais SHA-1 da assinatura e ao Bundle ID do
   app, respectivamente. Essa configuração mora no Google Cloud Console e não é
   verificável pelo repositório. Como o cabeçalho de referenciador é forjável
   por um cliente fora do navegador, a API Gemini conta ainda com cota diária e
   alerta de faturamento no projeto, que é o limite efetivo de abuso.
2. **Restrição de Escopo de APIs:** A chave da API Gemini possui escopo limitado
   estritamente à API de inteligência artificial necessária para o chat.
3. **Regras do Banco de Dados:** O acesso aos dados no Firestore independe da
   chave de API, sendo controlado integralmente pelas regras de segurança do
   Firebase (`firestore.rules` e `storage.rules`, ver 2.3).

### 3.3 Firebase App Check

Além da chave, o cliente obtém do Firebase App Check um token que atesta que o
pedido vem do próprio aplicativo, e não de um cliente forjado com a mesma chave
pública copiada do bundle. O SDK anexa esse token aos pedidos ao Firestore e ao
Auth (ver `lib/dados/nuvem.dart`: `Nuvem.iniciar` chama
`_assegurarTokenAppCheck`, que ativa os provedores e espera o primeiro token):

- **Web:** reCAPTCHA v3, com o *site key* também injetado por `--dart-define`
  (`RECAPTCHA_V3_SITE_KEY`); sem ele, o App Check nem é ativado na web.
- **Android:** Play Integrity, por atestação do próprio Google Play — sem chave
  de app.
- **iOS:** App Attest, com retorno a DeviceCheck em versões anteriores ao iOS 14
  — sem chave de app.

**O que o repositório garante é só a atestação do lado do cliente.** Se um
pedido sem token válido é recusado depende da imposição (*enforcement*) do App
Check, ligada por serviço no console do Firebase — configuração que não fica no
repositório e não é verificável por ele. As regras não checam `request.app` em
coleção nenhuma: em `usuarios`, `planos`, `config` e `convidados` a proteção é o
login Google e o dono do documento; em `lembretes` o próprio `firestore.rules`
registra o App Check como opcional de propósito, porque aparelhos sem Play
Integrity certificado não conseguiam registrar o lembrete. Por isso o App Check
deve ser lido como camada adicional, não como barreira garantida: a barreira que
o repositório garante são as regras (2.3).

A falha em ativar o App Check (site key ausente, domínio ainda não registrado no
console, atestação recusada no aparelho) não impede o app de abrir: o erro vai
só para o registro local e a sincronização e o login seguem sem token. Se a
imposição estiver ligada no console para o serviço, esses pedidos são recusados
até a configuração ser concluída. Na retomada do app (`main.dart`) o token só é
consultado, com `Nuvem.revalidarAppCheck(forcar: false)` (o SDK renova sob
demanda se expirou, sem pagar uma atestação nova a cada volta à aba). A
atestação nova é forçada só num caso: quando a busca dos planos da conta
(`PlanosNaNuvem._puxarOsMeus`) recebe PERMISSION_DENIED, cenário típico de token
expirado com o app suspenso; ela revalida e tenta uma única vez de novo. As
demais sincronias não forçam atestação nova.

### 3.4 Lembrete Diário — Push com Reserva Local no Android

O lembrete diário é híbrido: uma Cloud Function agendada
(`functions/src/index.ts`, `enviarLembretes`) lê a coleção `lembretes` do
Firestore a cada minuto e envia push via FCM em Android e web; o documento é
identificado pelo FID da instalação (o token FCM só permanece nos documentos
gravados antes da migração) e é gravado sem login (regras em 2.3). No Android,
`flutter_local_notifications` ainda arma uma reserva local em T+5 min, para o
caso de o push não chegar. O manifesto Android declara três permissões:
`POST_NOTIFICATIONS`, a única pedida em runtime (Android 13+);
`RECEIVE_BOOT_COMPLETED`, para rearmar a reserva local depois de reiniciar o
aparelho; e `INTERNET` (chat, sincronia, áudio e push), concedida na instalação.
Não há pedido da permissão especial de alarme exato: o agendamento local é
sempre inexato de propósito (ver `lib/dados/lembretes.dart` e
`android/app/src/main/AndroidManifest.xml`).

---

## 4. Segurança do Pipeline de Integração e Implantação (CI/CD)

- **Cabeçalhos de Segurança no Hosting:** O `firebase.json` define
  `X-Content-Type-Options: nosniff`,
  `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy`
  negando geolocalização, câmera, microfone, pagamento e USB, e
  `Content-Security-Policy: frame-ancestors 'none'` (proteção contra
  *clickjacking*). O HTTPS e o `Strict-Transport-Security` são reforçados sobre
  o padrão do Firebase Hosting.
- **Fixação de Commit SHA no GitHub Actions:** Todas as ações do GitHub Actions
  utilizadas no fluxo de *deploy* automatizado
  (`.github/workflows/deploy-web.yml`) estão fixadas pelo SHA completo do
  *commit*, prevenindo riscos associados a *tags* mutáveis.
- **Versão do SDK:** O projeto acompanha o canal `stable` do Flutter (`.fvmrc` e
  os workflows com `channel: stable` no `subosito/flutter-action`), não uma
  patch travada.
- **Segredos do Repositório:** As chaves de compilação de produção são
  gerenciadas através dos *GitHub Secrets* e disponibilizadas exclusivamente
  durante o processo de compilação automatizada.
- **Job agendado do lembrete diário:** não é um workflow do GitHub Actions — é a
  Cloud Function `enviarLembretes` (`functions/src/index.ts`), publicada por
  `deploy-web.yml` junto com o site e as regras
  (`firebase deploy --only hosting,firestore:rules,storage,functions`; `storage`
  publica o `storage.rules`). O deploy só começa depois que o job
  `regras-e-functions` passa: testes das regras no emulador (`test_regras`) e
  build e testes das Functions, além de `flutter analyze` e `flutter test` no
  próprio job de deploy. A Function sai com a mesma credencial
  `FIREBASE_SERVICE_ACCOUNT` do resto do deploy — nenhum segredo novo para esse
  fluxo.

---

## 5. Reportando uma Vulnerabilidade

Caso você identifique uma falha de segurança, vulnerabilidade de exposição de
dados ou comportamento inadequado no aplicativo, pedimos que faça o reporte de
maneira responsável.

### Como Reportar

**Não abra uma issue pública no GitHub para reportar vulnerabilidades de
segurança.**

Em vez disso, utilize o recurso de **Security Advisories** na guia de segurança
do repositório no GitHub ou entre em contato diretamente com o mantenedor do
projeto.

Ao enviar o relatório, inclua:

1. Descrição clara da vulnerabilidade ou falha encontrada.
2. Passos detalhados para reprodução do problema.
3. Cenário e impacto potencial de exploração.
4. Sugestões de correção, caso possua.

### Prazos de Resposta

- **Confirmação do Recebimento:** Até 48 horas úteis.
- **Análise e Validação:** Até 5 dias úteis.
- **Aplicação da Correção:** As correções validadas serão aplicadas
  prioritariamente no pipeline e publicadas em produção assim que homologadas.
