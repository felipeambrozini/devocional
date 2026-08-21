# Devocional

Aplicativo devocional pessoal do Felipe, em Flutter (Android e web a partir do
mesmo código).

## O que o app faz

- **Bíblia completa em tradução inédita:**
  - **BKJ 1611**, uma tradução interna autoral, com 31.102 versículos (bate exatamente com o canon).
- **Devocional diário**, três leituras por dia, na voz de Charles Spurgeon:
  - **Manhã** e **Noite** (*Morning and Evening*), uma virada automática entre
    as duas: 0h-17h59 mostra o devocional da manhã, 18h-23h59 o da noite,
    pelo horário do próprio aparelho.
  - **Promessas de Deus** (*Faith's Checkbook*), uma promessa bíblica por dia,
    com título, referência e comentário.
  - Calendário para ver o devocional de qualquer data, passada ou futura.
- **Cronograma de leitura anual**, 365 dias (366 em ano bissexto), agrupado por
  mês, com marcação de lido e barra de progresso do ano.
- **Planos personalizados**: escolher um ou mais livros e em quantos dias, com
  prévia antes de confirmar. Dá para compartilhar por link; cada participante
  entra com a própria conta Google e o progresso de todos aparece junto (Meus
  Planos). Quem criou pode excluir o plano (some para todos os participantes,
  com o progresso de cada um); quem só participa pode sair, e some só o
  próprio progresso.
- **Leitura em voz alta**: botão Ouvir narra capítulos da Bíblia, Manhã e
  Noite, Promessas de Deus e as introduções, numa só voz (barítono, Google
  Cloud Text-to-Speech).
- **Conversas com IA**: duas personas para conversar, Charles Spurgeon e
  Felipe Ambrozini, cada uma com o próprio jeito de falar (Gemini). Histórico
  salvo por conversa; aba própria no celular, balões flutuantes nas telas
  largas.
- **Introduções aos 66 livros**, na voz de Spurgeon, com título formal do livro
  vindo da BKJ 1611.
- **Favoritos e notas**: qualquer versículo pode ser marcado, anotado, copiado ou
  compartilhado; tela própria lista os favoritos e os que têm anotação, com
  busca por referência ou por texto da nota, e exporta uma cópia de segurança
  de tudo (favoritos, notas e progresso) para reimportar em outro aparelho.
- **Conta Google (Web, Android e iOS)**: opcional — favoritos, notas e progresso sobem
  sozinhos para a conta de quem entrar, para não perder nada se o navegador
  limpar o armazenamento. O Android e iOS também sincronizam; ver `nuvemSuportada` em `lib/data/nuvem.dart`.
  Quem entra vê o próprio avatar (foto da conta Google, ou a inicial do nome
  sem foto) na saudação da aba Hoje, e pode trocar a foto tocando nele
  (câmera ou galeria).
- **Busca** no texto da Bíblia e nos devocionais, em duas abas.
- **Tamanho do texto** ajustável e **tema claro ou escuro**, pela barra do leitor
  ou do devocional. O padrão segue o aparelho, e dá para fixar um dos dois.
- **Lembrete diário**, opcional, em Android: notificação de Manhã e
  Promessas de Deus e outra de Noite, cada uma num horário ajustável, abrindo a
  leitura certa ao ser tocada.
- Layout responsivo: barra de navegação embaixo no celular, trilho lateral em
  janela larga (a partir de 720px), coluna de leitura com largura confortável
  e centralizada no desktop.
- Navegação por gesto e por teclado: deslizar troca de capítulo no celular; na
  web as setas passam de capítulo e `Ctrl+F` abre a busca.

## Telas

| Aba | Conteúdo |
|---|---|
| Hoje | Saudação, prévia das três leituras do dia, leitura do cronograma, progresso do ano, atalho para continuar de onde parou |
| Bíblia | Leitor por capítulo, os 66 livros, introdução de cada um |
| Devocional | Manhã, Noite e Promessas de Deus, com calendário |
| Plano | Cronograma anual por mês, com marcação de lido; Meus Planos (personalizados e compartilhados) |
| Notas | Favoritos e anotações |
| Conversas | Chat com Spurgeon e Felipe (IA); em tela larga vira balão flutuante no lugar da aba |

Sobre (créditos, fonte da tradução, canais e ajuda), Perguntas frequentes e
Política de privacidade não são abas: moram no fim da folha de ajustes, com
URL própria cada uma.

Na web, cada aba tem a própria URL (`/hoje`, `/biblia`, `/devocional`,
`/plano`, `/notas`, `/conversas`) — dá para abrir, atualizar ou compartilhar
qualquer uma direto; `/sobre`, `/faq`, `/privacidade` e cada conversa
(`/charles-spurgeon`, `/felipe-ambrozini`) também têm URL própria. `?ler=joao.3.16`
na URL abre esse versículo por cima da aba, e `?plano=<id>` (ou
`?plano=<slug>-<id>`, com o título do plano na frente só por estética) abre um
plano compartilhado.

## Stack

- Flutter (Dart), `flutter_localizations` para `pt_BR`.
- `shared_preferences` é o armazenamento local (progresso, favoritos e notas),
  igual em todas as plataformas, sem banco. Na web, quem
  entra com a conta Google também espelha favoritos, notas e progresso num
  documento do Firestore — ver a conta na nuvem, acima.
- `share_plus` para compartilhar um versículo. `flutter_local_notifications` +
  `timezone` + `flutter_timezone` para o lembrete diário, só em Android
  (ver `lembretesSuportados` em `lib/data/lembretes.dart`).
- `go_router` para as rotas por aba, com `StatefulShellRoute.indexedStack` (a
  `Moldura` continua preservando a rolagem e o capítulo aberto de cada aba,
  como o `IndexedStack` antigo fazia).
- `firebase_core` + `firebase_auth` + `cloud_firestore` para a conta na
  nuvem, só chamados quando `nuvemSuportada` (`lib/data/nuvem.dart`).
  `firebase_storage` guarda a foto de perfil trocada pelo avatar da Hoje;
  `image_picker` escolhe a foto na câmera ou na galeria.
- `http` fala direto com a Gemini API (`gemini-3.5-flash-lite`, tier gratuito;
  nome fixo, não o alias `gemini-flash-latest`, que pode migrar para fora do
  grátis sem aviso) para o chat das duas personas (`lib/data/ia.dart`) e com a
  Google Cloud Text-to-Speech para a leitura em voz alta (`lib/data/voz.dart`);
  `just_audio` toca o áudio sintetizado. Chaves em `lib/data/google.dart`,
  vindas do `.env.json`.
- Fontes empacotadas localmente (Cinzel e Montserrat), sem depender de rede na
  primeira execução.
- Conteúdo (Bíblia, devocionais, introduções, cronograma) vem de arquivos JSON
  em `assets/`, um arquivo por livro, carregado sob demanda.

## Estrutura

```
lib/
  data/        modelos, canon (os 66 livros), leitura de conteúdo, estado persistido
  telas/       uma tela por arquivo (hoje, bíblia, devocional, plano, notas, busca, conversas, sobre...)
  theme.dart   as duas paletas: marrom e dourada, pergaminho e bronze
  main.dart    navegação (barra/trilho), rotas e ponto de entrada
assets/        Bíblia interna, devocionais, introduções, cronograma, imagens, fontes
test/          testes de unidade e de widget
```

## Conteúdo

Todo o conteúdo já está carregado e verificado. Não há tarefa de conteúdo
pendente, e a infraestrutura de tradução (pasta `tools/`) foi removida do
repositório: a BKJ e os devocionais não serão traduzidos de novo.

| Conteúdo | Situação |
|---|---|
| BKJ 1611 | 66 livros, 1189 capítulos, **31.102 versículos, bate exatamente com o canon** |
| Manhã e Noite | 366 dias, todos com manhã e noite (732 entradas) |
| Promessas de Deus | 366 de 366 traduzidos |
| Cronograma anual | 365 dias (366 em ano bissexto), 449 faixas |
| 66 introduções | Completas, com as frases aplicadas e o tom calibrado (56,3 "!" por 10 mil palavras) |

Regras que valem para os assets anuais (`assets/devotionals/*.json` e
`assets/reading_plan*.json`):

- **Chave de data é DD-MM**, dia primeiro, como se escreve a data em português.
- **O versículo dos devocionais não é traduzido**: vem da fonte do devocional
  (não da Bíblia do app), e em dias com 2+ epígrafes verdadeiras todos os
  versículos entram no campo `versiculo`.
- **Sem travessões** em nenhum texto do app (por pedido do usuário) e **sem
  aspas curvas**: vírgula, ponto e vírgula ou ponto, e aspas retas `"`.
- **Referências no JSON precisam resolver no canon do app** (`lib/data/canon.dart`
  usa `_livroEPrefixo`). Atenção às acentuações não óbvias: "Oseias" **sem**
  acento.
- **Voz vitoriana de Spurgeon**, tratando o leitor por "tu"; citações bíblicas
  no registro BKJ do app.

### Fidelidade da tradução do Manhã e Noite

Decisões por dia, com a fonte em inglês preservada verbatim onde o original
estava truncado/corrompido: 08-05 manhã usa ref "1 João 5:13" mas o corpo trata
do homem impotente de João 5 (assim na fonte EN); 11-06 noite preserva o trecho
corrompido "a e a batalha"; 18-05 e 24-11 começam com marcadores de versículo
("Colossenses 2:9,10" etc.); 29-08 manhã traz o epitáfio de William Carey.
Candidatos a revisão manual, se algum dia houver versão editorial.

### As 66 introduções

- As **frases** das introduções vieram de uma lista do usuário, cada uma com a
  referência registrada (só a de Salmos foi conferida na fonte primária).
- O **tom** foi calibrado em 07/08/2026 para soar como Spurgeon de verdade
  (355 pontos de exclamação em 63.042 palavras, 56,3 por 10 mil): ajustes
  pontuais de clímax, quase todos em "Contribuição para a Bíblia" e "Spurgeon
  em [Livro]"; "Estrutura" ficou sem nenhum toque.
- O endereçamento por **"tu"** foi corrigido (a "vós" predominava); texto
  bíblico citado com referência e plural histórico legítimo continuam "vós" de
  propósito, porque é a BKJ 1611 e precisa continuar byte a byte igual ao asset.
- Nenhuma construção retórica virou tique: "Aqui está" é o mais comum, com
  19/66, abaixo do teto de 22/66.

## Decisões que não devem ser refeitas

Registro das decisões de arquitetura e de produto, para não serem reabertas sem
motivo novo.

### Produto

- **Sequência de dias (streak)** — recusada de propósito: transformar um dia
  perdido em perda visível corta contra o espírito de um app devocional.
- **Áudio** — recusado inicialmente: voz sintética lendo Escritura mal é pior
  que não ter. Revisto em 17/08/2026 com a Google Cloud Text-to-Speech (voz de
  barítono, qualidade de narrador), ver "Leitura em voz alta" acima.
- **Cores de marcação** — mais taxonomia do que um leitor só precisa.
- **Widget na tela inicial** — código nativo nas duas plataformas para pouco
  retorno.
- **Lembretes em web e desktop** — falta infraestrutura confiável para o app
  fechado disparar algo (ver lembretes abaixo).
- **Offline de verdade na web** — investigado e recusado: o Flutter 3.44
  removeu o cache automático do service worker gerado e o CanvasKit carrega de
  CDN por padrão; fazer direito exigiria um service worker próprio contra um
  mecanismo que o próprio Flutter avisa que vai descontinuar. Não reabrir sem
  o Flutter trazer de volta um jeito suportado.
- **Sincronização entre aparelhos** — a cópia por exportar/importar cobria o
  risco real (perder as notas). Reaberta em 09/08/2026 quando o motivo mudou
  (o app passou a ser compartilhado com dezenas de pessoas): a conta Google
  na web é a forma atual de não perder nada (ver "Conta Google" acima);
  exportar/importar continua sendo o único caminho no Android.
- **Camada monocromática do ícone do Android** — a silhueta de rosto vira o
  avatar de "sem foto"; testada e descartada. Não reabrir sem trocar a marca
  por um monograma ou símbolo.

### Arquitetura e comportamento

- **A virada manhã/noite é por horário fixo do aparelho, não pelo sol do lugar.**
  0h-17h59 manhã, 18h-23h59 noite (`Periodo.pelaHora` em `lib/data/modelos.dart`).
  A versão por geolocalização (nascer/pôr do sol, pacote `geolocator`) foi
  removida junto das permissões de localização.
- **29 de fevereiro** não precisa de tratamento especial: `DateTime` do Dart já
  o impede em ano comum (provado em `test/bissexto_test.dart`).
- **Os chevrons de capítulo só existem onde não há gesto de toque**: no celular
  deslizar já passa a página; na web a barra fica. É a
  única ramificação por plataforma no app — a web entra pelo pior caso (desktop
  sem toque). `_semGestoDeToque` em `lib/telas/biblia.dart`.
- **O alternador das três leituras usa chips, não `SegmentedButton`** — o
  `SegmentedButton` iguala a largura dos segmentos à do maior, e três vezes
  "Promessas de Deus" nunca cabe num celular.
- **O peso das fontes vem de `fontVariations`, não do `weight` do pubspec**:
  Cinzel e Montserrat são variáveis, e declarar `weight:` só rotula o arquivo.
  `lib/theme.dart` põe `FontVariation('wght', N)` em todo estilo. Guardado por
  dois testes (`test/tema_test.dart` e `test/fontes_test.dart`, que mede o
  texto de verdade).
- **Há dois temas, e nenhuma tela lê a paleta direto**: `Cores` tem as duas
  paletas e só `theme.dart` a importa; as telas leem tudo de
  `Theme.of(context).colorScheme`. Se aparecer um `Cores.` em `lib/telas/`, é
  um vazamento. O mapa dos papéis: `surface` fundo, `surfaceContainer` cartão,
  `surfaceContainerHighest` citação e chip, `primary` título e ícone,
  `secondary` destaque, `outline` borda, `onSurface` corpo, `onSurfaceVariant`
  apoio. **O claro não é o escuro invertido**: o dourado sobre pergaminho dá
  2,1:1 e é ilegível, então o destaque vira bronze. `test/tema_test.dart`
  calcula os contrastes da WCAG e falha se clarearem o bronze.
- **A `LarguraDeLeitura` fica no corpo de cada tela**, nunca em volta do
  Scaffold nem do `IndexedStack` — em volta do stack ela prendia a AppBar e a
  régua de meses do Plano, e deixava de fora as telas abertas por
  `MaterialPageRoute`.
- **O tamanho do texto de leitura multiplica só `bodyLarge` e `bodyMedium`**,
  para não empurrar a barra de baixo nem quebrar o cabeçalho. O `Estado`
  recusa valores fora de `escalasDeLeitura`.
- **Toda tela distingue carregando, erro e vazio** (`AvisoDeErro` em
  `lib/telas/comuns.dart`); o padrão antigo confundia os três e deixava o
  spinner girando para sempre.
- **A cópia de segurança das notas vai pela área de transferência**, não por
  arquivo, para não ramificar por plataforma. Importar **funde**, nunca
  substitui; em conflito vence quem tem nota.
- **A busca das Marcações filtra referência e nota, não o corpo do versículo**
  — o texto é carregado sob demanda, e trazer todos para uma busca em memória
  derrubaria o carregamento tardio. Limitação deliberada, documentada em
  `lib/telas/notas.dart`.
- **Compartilhar e Copiar usam o mesmo texto formatado** (`_textoDoVersiculo`
  em `lib/telas/biblia.dart`). Em teste, `Clipboard.getData` trava para sempre;
  a forma de verificar é um `setMockMethodCallHandler` capturando o argumento
  de `Clipboard.setData`.
- **A assinatura de Spurgeon é tinta dourada chapada (`#E3C567`)**, tingida
  pelo tema com `BlendMode.srcIn`, em vez de dois arquivos para manter em
  sincronia.
- **O avatar da Hoje é a foto da conta Google de quem entrou, nunca uma
  imagem fixa do app** (20/08/2026) — antes era a foto do Felipe embutida no
  app, escondida na web. `Nuvem.fotoUrl` lê `FirebaseAuth.currentUser?.photoURL`;
  sem conta ou sem foto, cai na inicial do nome. Tocar no avatar sobe uma
  foto nova (câmera ou galeria, `image_picker`) para `fotos_de_perfil/{uid}.jpg`
  no Firebase Storage (`storage.rules`: um arquivo por conta, só o dono
  grava, leitura pública porque a URL vai direto num `NetworkImage`).
- **Excluir um plano e sair dele são ações diferentes** (20/08/2026):
  `excluirPlano` (`lib/telas/comuns.dart`) apaga o plano da nuvem para todos
  os participantes, e só quem criou pode chamar; `sairDoPlano` apaga apenas a
  própria participação, para quem só entrou no plano de outra pessoa. Os dois
  ficam disponíveis pela lixeira no cartão de "Meus Planos" e pelo menu
  dentro do plano.
- **Funcionalidades se ligam/desligam por uma constante, não por servidor de
  configuração** (20/08/2026): `lib/data/recursos.dart` reúne os
  interruptores — `planoPersonalizado` (aba "Meus planos"), `ouvirTextos`
  (`BotaoDeVoz`, único ponto de entrada da leitura em voz alta) e `conversas`
  (aba Conversas, os balões flutuantes e as rotas `/conversas`,
  `/charles-spurgeon`, `/felipe-ambrozini`). Os dois primeiros são `const`;
  `conversas` compara o e-mail da conta aberta (`Nuvem.email`) contra um
  e-mail fixo, porque o chat chama a API paga do Gemini e abrir para todo
  mundo antes da hora custaria sem controle. Sem `firebase_remote_config`:
  editar um valor e reimplantar já é o "ligar/desligar" possível para um app
  de usuário único. `Recursos.conversasForcado` (mesmo padrão de
  `Lembretes.instancia`, mutável) existe só para teste — o login de verdade
  nunca roda no ambiente de teste, e sem o override os testes de Conversas e
  dos balões não veriam o recurso.
- **`web/index.html` tem fundo marrom e um marcador de carregamento**, retirado
  no evento `flutter-first-frame` (o Flutter acrescenta a `flutter-view` ao
  body em vez de limpar). As duas cores do fundo são por
  `prefers-color-scheme`.
- **O `index.html` é editado à mão, e o `web: false` da splash é de propósito**:
  a abertura da web já está resolvida à mão; deixar o gerador mexer ali
  sobrescreveria isso.
- **A versão do Flutter é fixa (`3.44.9`), não `stable`** (desde 08/08/2026),
  porque uma release nova podia quebrar o deploy web sem nenhuma mudança no
  repositório. Fixado em `.fvmrc` e no `deploy-web.yml`
  (`subosito/flutter-action@v2`, `flutter-version: 3.44.9`). **Atualizar nos
  dois lugares ao mesmo tempo** e rodar a suíte local antes de comitar.
- **`AreaDeSelecaoComCompartilhar` (`lib/telas/comuns.dart`, 20/08/2026)
  envolve `SelectionArea` e acrescenta "Compartilhar" ao menu de seleção**,
  usada no Devocional e na Introdução: o texto vira selecionável e copiável
  de fábrica, e o mesmo clique forte que abre a seleção nativa ganha um botão
  a mais para compartilhar o trecho escolhido (via `share_plus`, sem
  formatação de referência — a seleção pode não bater com um parágrafo
  inteiro). `SelectableRegionState` não expõe o texto selecionado
  publicamente; o widget captura pelo `onSelectionChanged` do `SelectionArea`
  e lê o valor mais recente ao montar o menu. **A Bíblia não usa esse
  widget** — ali o `SelectionArea` continua puro (só seleção e cópia
  nativas), e Compartilhar continua exclusivo da folha de ações do versículo
  (Favoritar, Copiar, Compartilhar, Anotar; ver abaixo), aberta pelo toque na
  linha.

### Lembretes diários (Android)

- Só em Android (`lembretesSuportados` em `lib/data/lembretes.dart`).
- **Notificação inexata** (`AndroidScheduleMode.inexactAllowWhileIdle`), não
  exata: exata exigiria `SCHEDULE_EXACT_ALARM`, que no Android 14 o usuário
  precisa conceder à mão.
- **`Lembretes` é interface, não classe** (`Lembretes.instancia`, mutável), com
  implementação real e falsa (`_LembretesFalsas` em `test/lembretes_test.dart`).
- **`tz.local` é UTC por padrão** no pacote `timezone`; `flutter_timezone` +
  `tz.setLocalLocation(...)` escolhem o fuso. Se a detecção falhar, cai em UTC
  em vez de travar.
- **O build do Android precisa de `isCoreLibraryDesugaringEnabled` e
  `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`** — sem
  isso o Gradle recusa o build.
- **`ScheduledNotificationReceiver` é declarado à mão no manifesto** — desde a
  v16 do plugin ele não é mais declarado pelo AAR, e sem o receptor o
  `AlarmManager` agendava um `PendingIntent` para componente inexistente (sem
  exceção, sem log). O `ScheduledNotificationBootReceiver` +
  `RECEIVE_BOOT_COMPLETED` faz o lembrete sobreviver a reboot.
- **Reagendar só se não houver nada pendente**: `main()` chamava
  `reagendarLembretesSeNecessario` (`lib/telas/comuns.dart`, usa
  `pendingNotificationRequests()`) — abrir o app perto do horário cancelava o
  lembrete do dia, porque a entrega inexata pode levar minutos para disparar.
- **Canal `lembretes_diarios` com importância alta**; a importância de um canal
  trava na primeira notificação exibida — se o canal já tiver sido criado num
  aparelho de teste antes do ajuste, é preciso desinstalar o app.
- **`data/` não importa `telas/`**: `Lembretes` fala em `chave` (string), e é
  `main.dart` quem faz `Leitura.values.byName(chave)`.

### Web

- **Cada aba com a própria URL** (09/08/2026) via `go_router` com
  `StatefulShellRoute.indexedStack`. O Firebase Hosting devolve o index.html
  para qualquer caminho sob `/devocional/` (rewrite em `firebase.json`), então
  abrir `/devocional/biblia` direto ou dar F5 funciona sem truque de 404.
- **Chat com URL própria** (16/08/2026): as conversas (`/charles-spurgeon`,
  `/felipe-ambrozini`) são empurradas por `push` por cima das abas, e a barra
  de endereço acompanha porque `main.dart` liga
  `GoRouter.optionURLReflectsImperativeAPIs` (opção estática do go_router, que
  por padrão não reflete na URL as navegações imperativas — o motivo de a
  tela Sobre ter virado aba em 09/08/2026).
- **Sobre volta para a folha de ajustes** (17/08/2026): com a opção acima
  ligada, o `push` para `/sobre` também atualiza a URL; Sobre deixou de ser
  aba (a navegação inferior ficou com seis destinos) e voltou para o fim da
  folha de ajustes, como os créditos de um aplicativo costumam ficar.
- **Aba Conversas** (19/08/2026): as conversas ganharam a própria aba
  (`/conversas`), com uma carta por persona abrindo o histórico por `push`
  (`/charles-spurgeon`, `/felipe-ambrozini`). A seção Conversas da folha de
  ajustes perdeu as duas entradas e ficou só com o interruptor dos balões e a
  dica, que valem para as telas largas.
- **`usePathUrlStrategy()`** vem de `package:flutter_web_plugins/url_strategy.dart`,
  não do barril `flutter_web_plugins.dart` (o barril puxa `dart:ui_web` sem
  condicional e quebra a compilação para a VM, que é o que o `flutter test`
  usa).
- **Prévia de link (Open Graph)**: `og:image` absoluta (o WhatsApp não resolve
  caminho relativo). A imagem é gerada por script, nunca editada à mão.
  **Teto conhecido**: é uma prévia só para o site inteiro; link direto para um
  versículo mostra a mesma imagem genérica (prévia por rota exigiria render no
  servidor).
- **Link direto**, formato `?ler=joao.3.16` (capítulo sem versículo: `?ler=joao.3`).
  Parâmetro de consulta, não caminho, porque o
  Pages devolveria 404. `alvoDoLink` e `linkDoVersiculo` em `lib/data/canon.dart`
  fazem a ida e volta.
- **Link do plano compartilhado leva o título como slug** (20/08/2026),
  `?plano=<slug-do-titulo>-<id>` (`linkDoPlano` em `lib/data/planos_nuvem.dart`).
  O slug é só estética: quem abre busca pelo plano sempre pelo `id`, o último
  trecho depois do último hífen (`idDoParametroDePlano`), que nunca tem hífen
  dentro e por isso continua único mesmo com dois planos de mesmo título.
- **Identidade neutra**: `<title>`, `apple-mobile-web-app-title` e
  `name`/`short_name` são "Devocional" (a foto e o nome do usuário saíram da
  web pública). `orientation` do manifesto é `any` (a trava em retrato
  contradizia o trilho lateral e a coluna dupla).
  **Cuidado ao regenerar ícones**: `dart run flutter_launcher_icons` reescreve
  `manifest.json` por completo; conferir se `name` e `orientation` sobreviveram.
- **Modo apresentação**: `TelaApresentacao` em `lib/telas/biblia.dart`, tela
  cheia, o versículo num `FittedBox(BoxFit.scaleDown)` (de propósito não usa
  `Estado.escalaDeLeitura`). Fecha ao tocar em qualquer lugar. Entra pela folha
  de ações do versículo, entre Compartilhar e Anotar.
- **Aviso de perda de notas na web**: faixa fixa no topo de `TelaNotas`, só
  quando `kIsWeb`, chamando a mesma `_exportar` do menu (sem `Dismissible` de
  propósito: o risco do `localStorage` ser limpo não desaparece porque a
  pessoa fechou o aviso).
- **Tela Sobre completa**: `lib/telas/sobre.dart`, com dois links (YouTube e
  Instagram) abertos com `launchUrl` do `url_launcher`.
- **`biblia.dart` e `busca.dart` se importam um ao outro** — import circular
  entre dois arquivos é permitido em Dart, não é um erro: a busca abre o leitor
  num versículo e o leitor abre a busca com `Ctrl+F`.
- **Conta Google e cópia na nuvem (Web, Android e iOS)** (19/08/2026): `Sincronia` em
  `lib/data/nuvem.dart` é um ouvinte de fora sobre o `ChangeNotifier` do
  `Estado` (que **não mudou nenhuma linha**), reaproveitando `exportar()`/
  `importar()`. O filtro contra ruído e contra loop é comparar a string de
  `exportar()` com a última enviada. Documento único por usuário no Firestore
  (`usuarios/{uid}`); **remoção não sincroniza** (importar funde e nunca apaga).
  Login por `signInWithPopup` na web; no Android/iOS usa `google_sign_in` nativo.
- **`lib/firebase_options.dart` lê do `.env.json` via `flutter_dotenv`** (19/08/2026):
  não é mais gerado pelo `flutterfire configure`. As chaves ficam no `.env.json`
  (gitignored) e entram via `dotenv.env['CHAVE']` no `firebase_options.dart`.
  O CI usa `--dart-define-from-file=.env.json` ou secrets do GitHub.
  As chaves são públicas por desenho: quem protege os dados são as regras do
  Firestore (`firestore.rules`, publicado à mão) e a lista de domínios autorizados.
- **Nome do pacote** trocado para `com.felipeambrozini.devocional` (09/08/2026),
  refletido no `android/app/build.gradle.kts`.
- **FAQ e Política de privacidade** (20/08/2026): `lib/telas/faq.dart` e
  `lib/telas/privacidade.dart`, com rotas próprias (`/faq`, `/privacidade`) e
  entradas na folha de ajustes, ao lado de Sobre. A política é a versão
  completa e é a fonte da verdade sobre o que sobe para a nuvem; o resumo em
  Sobre (seção Conta e privacidade) só linka para ela. Escrita para corrigir
  uma lacuna real: o resumo antigo dizia que só favoritos, anotações e dias
  lidos subiam, mas `Nuvem._empurrarConversas` (`lib/data/nuvem.dart`) também
  sincroniza o histórico do chat com IA para quem tem conta.
- **`web/robots.txt` e `web/llms.txt`** (20/08/2026): liberação de rastreamento
  padrão e um resumo do produto no formato `llms.txt` (llmstxt.org), com links
  para o app, Sobre, FAQ e privacidade. Nenhum dos dois existia antes; nenhuma
  `sitemap.xml` foi criada porque o site não tem uma. O domínio
  `felipeambrozini.com.br` é hoje dedicado só a este app, então o passo de
  deploy que já copiava `404.html` para a raiz do `public` (ver acima) também
  copia estes dois: rastreador e ferramenta de IA olham a raiz do domínio, não
  o subcaminho `/devocional/` onde o app mora.

### Ícone, splash e fontes

- **O ícone é a marca-texto "Devocional"** (fonte Cinzel, mesma composição do
  `web/og.png`), não mais a foto do Felipe recortada no rosto (rebrand de
  20/08/2026, junto com o nome do app no Android: `android:label` também
  virou "Devocional"). As fontes ficam em `assets/icone/`, montadas por
  `tools/icones.py --fontes`; os arquivos por plataforma saem de
  `dart run flutter_launcher_icons` e depois de `tools/icones.py --corrigir`
  (obrigatório: o gerador copia o ícone normal nos `Icon-maskable-*` sem
  saber que o Chrome recorta o maskable em círculo, e não conhece o favicon
  claro). Cinco fontes: `icone.png` (fundo `#2E1B10`) para o Android anterior
  ao ícone adaptativo; `icone_adaptativo.png` (fundo opaco, a marca já carrega
  o próprio fundo) para o ícone adaptativo do Android; `icone_mascaravel.png`
  (fundo chapado) para os `Icon-maskable-*` da web; `icone_claro.png`, pronta
  para quando Android/iOS 18 tiverem variante clara configurada (ainda manual,
  o `flutter_launcher_icons` 0.14.4 não gera isso); `icone_tingido.png`
  (silhueta transparente) para o ícone tingido do iOS 18.
- **A splash também é a marca-texto "Devocional"** (mesma fonte, dourada no
  tema escuro e em bronze no claro — dourado sobre pergaminho é ilegível,
  mesmo motivo do favicon claro acima), não mais a foto do Felipe (rebrand de
  21/08/2026). As artes ficam em `assets/icone/` (`splash.png`/
  `splash_escuro.png` e as variantes `_android12`, recuadas para caber no
  círculo que o Android 12+ recorta), montadas por `tools/icones.py --splash`.
- **Tela de abertura e ícone do lançador são coisas diferentes, e só uma delas
  acompanha o tema em todo lugar.** A **splash** troca por tema nas duas
  plataformas (`image`/`image_dark` do `flutter_native_splash`, configurado no
  `pubspec.yaml`). O **ícone** acompanha o tema no Android (qualificador
  `-night` no fundo do ícone adaptativo; verificado num Galaxy; lançadores
  guardam o ícone em cache, desinstalar para ver a mudança) e no favicon da web
  (por `prefers-color-scheme`); no PWA não, porque lê um arquivo só.
- **O alternador das três leituras usa chips, não `SegmentedButton`** (ver
   decisões de arquitetura).

## Rodando

```bash
flutter pub get
flutter run
```

Para o app ter acesso à nuvem (conta Google) e à IA, crie um `.env.json` com
as chaves (baseado no `.env.json` do repositório). O VS Code carrega no F5 via
`--dart-define-from-file=.env.json` (`.vscode/launch.json`). Sem ele, o app
abre normal e degrada só nesses recursos. O SDK é gerido pelo FVM (ver
`.fvmrc`), na versão fixa 3.44.9.

## Testes e análise

```bash
flutter test
flutter analyze
```

## Gerando o app

```bash
# Android
flutter build apk --dart-define-from-file=.env.json
# Web
flutter build web --dart-define-from-file=.env.json
```
(O `.env.json` deve conter todas as chaves: `FIREBASE_API_KEY_WEB`,
`FIREBASE_API_KEY_ANDROID`, `FIREBASE_API_KEY_IOS`, `GEMINI_API_KEY_WEB`,
`GEMINI_API_KEY_ANDROID`, `TTS_API_KEY_WEB`, `TTS_API_KEY_ANDROID`, etc.)

Ícone do app, favicon e tela de abertura são gerados a partir das fontes em
`assets/icone/`; nunca editados à mão:

```bash
python tools/icones.py --fontes
dart run flutter_launcher_icons
python tools/icones.py --corrigir
python tools/icones.py --splash
dart run flutter_native_splash:create
```

O passo `--corrigir` é obrigatório (ver "Ícone, splash e fontes" acima).
Depois de rodar `flutter_launcher_icons`, conferir se o `manifest.json` da web
manteve `name` e `orientation` (o gerador reescreve o arquivo por completo).

A **tela de abertura** acompanha o tema do aparelho em Android e na web. O
**ícone do lançador** acompanha no Android e no favicon da web; no PWA não,
porque lê um arquivo só e não tem variante.
No Android, lançadores guardam o ícone em cache: para ver a mudança é preciso
desinstalar antes de instalar de novo.

## Publicação na web

O deploy é pelo GitHub Actions (`.github/workflows/deploy-web.yml`), com o
Flutter fixo em 3.44.9, para o Firebase Hosting. O site mora em
`www.felipeambrozini.com.br/devocional/` (um nível abaixo da raiz do domínio; o
build vai para `public/devocional` e o rewrite em `firebase.json` cuida do
SPA). O build usa `--base-href /devocional/` e as chaves de API vêm dos
Secrets do repositório: `FIREBASE_API_KEY_WEB`, `GEMINI_API_KEY_WEB` e
`TTS_API_KEY_WEB` (precisam estar cadastrados em Settings → Secrets and
variables, no environment `github-pages`). O deploy usa
`FIREBASE_SERVICE_ACCOUNT` (JSON da conta de serviço do Firebase). As actions
estão fixadas em commit SHA completo, não em tag mutável.

Além do build em `public/devocional`, o mesmo passo copia `404.html`,
`robots.txt` e `llms.txt` para a raiz do `public` — o Hosting só olha esses
arquivos na raiz do domínio, nunca num subcaminho.

