# Onde o trabalho parou

Documento de passagem de bastão. Escrito para que uma sessão nova continue sem
precisar reconstruir nenhuma decisão.

## Estado

| Item | Situação |
|---|---|
| App Flutter (mobile + web) | Completo. `flutter analyze` limpo, 556 testes passando |
| BKJ 1611 | 66 livros, 1189 capítulos, **31.102 versículos, bate exatamente com o canon** |
| NVT | 31.104 versículos; os 2 desvios são `3 João 1:15` e `Ap 12:18`, versificação da NLT |
| Manhã e Noite | 366 dias, todos com manhã e noite |
| Cronograma anual | 365 dias, 449 faixas |
| 66 introduções | Completas, com as frases aplicadas |
| **Promessas de Deus** | **366 de 366 traduzidos. Concluído.** |

## Não há tarefa de conteúdo pendente

Todo o conteúdo está carregado e verificado. O que segue é referência para
quem precisar regenerar ou revisar algo.

## Como regenerar Promessas de Deus

A fonte em inglês (`tools/promessas_en.json`) está no `.gitignore`: é insumo já
consumido, e o app lê apenas `assets/devotional/promises.json`. Para trazê-la
de volta:

```bash
curl -sL -o checkbook.txt https://www.ccel.org/ccel/s/spurgeon/checkbook/cache/checkbook.txt
python tools/promessas.py --extrair checkbook.txt
```

Conferir o que está montado e remontar o asset:

```bash
python tools/promessas.py --validar
```

```bash
python tools/promessas.py --montar
```

`--montar` deve dizer `366 de 366`. A tradução em português vive dentro do
próprio `promises.json`; os arquivos mensais intermediários de
`tools/promessas_pt/` foram removidos depois da montagem final.

## Decisões que não devem ser refeitas

- **Só se traduziu `title` e `body`.** O versículo em português **não é traduzido**: o
  script lê da BKJ já extraída em `assets/bible/bkj/`, pela referência inglesa, e
  monta `reference` em português. Isso garante que a promessa seja idêntica ao texto
  que o usuário lê no leitor da Bíblia. As 366 referências resolvem
  (`python tools/promessas.py --referencias`).
- **A fonte em inglês é a edição digital do CCEL**, não o Internet Archive. As duas
  digitalizações do Archive foram testadas e descartadas: o OCR corrompeu os
  cabeçalhos de dia (`Feb. iz` em vez de `Feb. 12`) e setembro inteiro desaparecia.
  *Faith's Checkbook* (1888) é domínio público.
- **Sem travessões** em nenhum texto do app, por pedido do usuário. Vírgula, ponto e
  vírgula ou ponto.
- **Voz vitoriana de Spurgeon**, em português, tratando o leitor por tu.
- **29 de fevereiro** não precisa de tratamento especial: `DateTime` do Dart já o
  impede em ano comum. Provado em `test/bissexto_test.dart`.
- **As 66 frases das introduções** vieram de uma lista do usuário e estão registradas
  com a referência de cada uma em `tools/frases_verificadas.json`. Só a de Salmos foi
  conferida por mim na fonte primária; isso está anotado no arquivo. Decisão do
  usuário, já discutida, não reabrir.
- **A virada manhã/noite é por horário fixo do aparelho, não pelo sol do lugar.**
  0h-17h59 é devocional da manhã, 18h-23h59 é da noite (`Periodo.pelaHora` em
  `lib/data/modelos.dart`, `test/periodo_test.dart`). A versão anterior calculava
  nascer e pôr do sol por geolocalização (`lib/data/sol.dart`,
  `lib/data/localizacao.dart`, pacote `geolocator`); tudo isso foi removido, junto
  das permissões de localização em Android, iOS e macOS.
- **Os chevrons de capítulo só existem onde não há gesto de toque.** No celular
  deslizar já passa a página, e a barra custava uma faixa do fim de toda tela,
  logo acima da barra de navegação, para repetir o que o dedo faz. No Windows, no
  macOS, no Linux e na web ela fica: arrastar com o botão do mouse apertado
  dispara o mesmo reconhecedor, mas ninguém descobre isso sem um dedo na tela, e
  as setas do teclado também não se anunciam.

  É a **única ramificação por plataforma do app**, e existe porque a forma de
  apontar muda de verdade entre elas, ao contrário do armazenamento. A web entra
  pelo pior caso: pode estar num desktop sem toque.

  O `_semGestoDeToque` de `lib/telas/biblia.dart` é getter e não `static final`:
  guardado numa constante, o valor seria fixado na primeira leitura e o teste que
  troca a plataforma passaria a medir a anterior. E no teste, desfazer
  `debugDefaultTargetPlatformOverride` tem que ser dentro do corpo, num
  `finally`, porque o framework confere as variáveis de depuração **antes** de
  rodar os `addTearDown`.
- **Tela de abertura e ícone do lançador são coisas diferentes, e só uma delas
  acompanha o tema em todo lugar.** É fácil confundir: no Android 12+ o sistema
  desenha o **ícone do lançador no meio da splash**, então um ícone escuro sobre
  uma splash branca parece "o ícone errado para o tema", quando o que está errado
  é a splash.

  A **splash** troca por tema em todas as plataformas, porque é desenhada com os
  recursos do próprio app. Vem do `flutter_native_splash`, configurado no
  `pubspec.yaml`: uma arte só, sem fundo, e duas cores. Regerar com:

```bash
dart run flutter_native_splash:create
```

  Antes disso o projeto tinha o modelo padrão do Flutter, que abre em **branco**
  no tema claro e em preto no escuro; nenhum dos dois é cor deste app.

  `web: false` de propósito: a abertura da web já está resolvida à mão em
  `web/index.html`, com a cor por `prefers-color-scheme` e o marcador retirado no
  `flutter-first-frame`. Deixar o gerador mexer ali sobrescreveria isso.

  O que ele gera, para conferir se algum dia parar de funcionar: `values-v31/` e
  `values-night-v31/` com `windowSplashScreenBackground` (Android 12+),
  `drawable/` e `drawable-night/` com `background.png` de 1x1 na cor, e
  `LaunchBackground.imageset` com as aparências `any` e `dark` no iOS.
- **O ícone do lançador acompanha o tema no Android, no iOS 18 e no favicon da
  web.** A foto vai sobre pergaminho no claro e sobre marrom no escuro, e as
  artes saem todas do mesmo recorte. Onde não dá, não dá por limitação do
  sistema, não da arte:

  | Plataforma | Troca por tema? |
  |---|---|
  | Android 8+ | Sim, `-night` no fundo do ícone adaptativo. Ver ressalvas |
  | iOS 18+ | Sim, três aparências: clara, escura e tingida |
  | Web, favicon | Sim, por `prefers-color-scheme` no `index.html` |
  | Web, ícone do PWA | Não, o manifesto não tem variante |
  | Windows, macOS, Linux | Não, um `.ico`/`.icns` só |

  No **Android** funciona porque o `mipmap-anydpi-v26/ic_launcher.xml` aponta o
  fundo para `@color/ic_launcher_background`, e recurso de cor aceita o
  qualificador `-night`. O lançador resolve o ícone com a configuração dele, que
  segue o modo escuro do sistema, e por isso a cor troca. **Verificado num
  Galaxy, One UI.** Duas ressalvas: não é mecanismo documentado pelo Android, e
  pode variar por fabricante; e lançadores **guardam o ícone em cache**, então
  instalar por cima não basta para ver a mudança. Para testar, desinstalar antes.

  O que muda é o **fundo**; a camada de frente, o rosto recortado, é a mesma nos
  dois temas.

  Não confundir com a **camada monocromática** (`adaptive_icon_monochrome`), que
  é outra coisa: uma silhueta de uma cor chapada, tingida pelo lançador. Uma foto
  de rosto vira a forma do avatar de "sem foto". Foi testada e descartada; não
  reabrir sem trocar a marca por um monograma ou símbolo.

  Nas plataformas de um arquivo só, o ícone é o de **fundo escuro**, porque ele é
  autossuficiente e se lê nos dois temas.

  No iOS as artes clara e escura vão **opacas** de propósito. O gerador grava a
  imagem como ela é, e o sistema só desenha fundo próprio quando a arte é
  transparente, que não é o que se quer aqui. A tingida é a exceção: cinza e sem
  fundo, porque nela quem pinta é o sistema.
- **O ícone sai da foto, recortado no rosto.** As fontes ficam em `assets/icone/`
  e os arquivos por plataforma são gerados por `dart run flutter_launcher_icons`,
  nunca editados à mão. Cinco fontes, e cada uma existe por um motivo:
  `icone.png` (rosto ocupando 88%, fundo `#2E1B10`) para Android, macOS, Windows,
  iOS antigo e o modo escuro do iOS 18; `icone_claro.png` (88%, fundo `#F7F1E3`)
  para a aparência "Any" do iOS 18, que é a do tema claro; `icone_tingido.png`
  (88%, cinza, sem fundo) para a aparência tingida; `icone_adaptativo.png` (60%,
  fundo transparente) para a camada de frente do ícone adaptativo do Android, que
  o sistema recorta em círculo, folha ou pílula; `icone_mascaravel.png` (60%,
  fundo chapado) para os `Icon-maskable-*` da web, porque o Chrome recorta em
  círculo e descarta os 20% de fora. O gerador copia o ícone normal nos maskable,
  o que cortaria o topo da cabeça, e gera o favicon em 16, embaçado em tela de
  retina; por isso `tools/icones.py --corrigir` reescreve os maskable e os três
  favicons depois dele. A ordem completa, se precisar refazer:

```bash
python tools/icones.py --fontes
```

```bash
dart run flutter_launcher_icons
```

```bash
python tools/icones.py --corrigir
```
- **O alternador das três leituras usa chips, não `SegmentedButton`.** O
  `SegmentedButton` iguala a largura de todos os segmentos à do maior, então três
  vezes "Promessas de Deus" nunca cabe num celular e o rótulo aparecia cortado.
  Cada chip se dimensiona pelo próprio texto.
- **O peso das fontes vem de `fontVariations`, não do `weight` do pubspec.**
  Cinzel e Montserrat são fontes variáveis, com instância padrão em 400 e em
  **100 (Thin)**. Declarar o mesmo arquivo com `weight: 600` e `weight: 700` no
  pubspec **não move o eixo `wght`**: só rotula o arquivo, e o peso final fica por
  conta do casamento e da síntese de fonte do motor, que variam por plataforma.
  Hoje há uma entrada por família no pubspec, sem `weight`, e `lib/theme.dart` põe
  `FontVariation('wght', N)` em todo estilo, o que torna o resultado igual em
  Android, iOS, web e Windows.

  Dois testes guardam isso, porque a análise estática não vê nada de errado nas
  duas formas: `test/tema_test.dart` confere que todo estilo declara o eixo, e
  `test/fontes_test.dart` carrega os arquivos de verdade e **mede** o texto, já
  que numa fonte variável pesos diferentes têm larguras diferentes. Se um dia
  corpo e destaque medirem igual, o eixo parou de ser aplicado.
- **Há dois temas, e nenhuma tela lê a paleta direto.** `Cores` tem as duas
  paletas e só `theme.dart` a importa; as telas leem tudo de
  `Theme.of(context).colorScheme`. Isso não é preciosismo: enquanto as telas
  chamavam `Cores.dourado` na mão, em 55 pontos, metade da interface continuaria
  marrom sobre pergaminho. Se aparecer um `Cores.` em `lib/telas/`, é um vazamento.

  O mapa dos papéis, um por um: `surface` fundo da página, `surfaceContainer`
  cartão, `surfaceContainerHighest` citação e chip, `primary` título e ícone,
  `secondary` destaque, `outline` borda e filete, `onSurface` corpo,
  `onSurfaceVariant` apoio.

  **O claro não é o escuro invertido.** O dourado `#C9A227` sobre pergaminho dá
  2,1:1 e é ilegível, então o par de destaques vira bronze (`#7A5C12` e
  `#5E4409`). O que se mantém é a relação entre os tons: o destaque é sempre o
  mais distante do fundo, que no escuro quer dizer mais claro e no claro mais
  escuro. `test/tema_test.dart` calcula os contrastes da WCAG e falha se alguém
  clarear o bronze "só um pouco".

  A **assinatura de Spurgeon** é tinta chapada num tom só (`#E3C567`), e sumiria
  no claro; ela é tingida pelo tema com `BlendMode.srcIn`, em vez de existirem
  dois arquivos para manter em sincronia.

  `web/index.html` também tem as duas cores, por `prefers-color-scheme`: com uma
  cor fixa, metade das pessoas via um flash do tema contrário antes do primeiro
  frame.

  Nos testes, trocar de tema precisa de **dois** `pump`: no primeiro o `setState`
  entra e o `AnimatedTheme` começa a transição de 200 ms ainda na cor antiga.
  `pumpAndSettle` não serve, porque sem aquecer os assets o spinner da tela Hoje
  gira para sempre.
- **A `LarguraDeLeitura` fica no corpo de cada tela, nunca em volta do Scaffold
  nem em volta do `IndexedStack`.** Em volta do stack ela prendia a AppBar e a
  régua de meses do Plano numa faixa de 720 px no meio da janela, e deixava de
  fora as telas abertas por `MaterialPageRoute`, que nascem no Navigator raiz: o
  mesmo leitor ficava com 720 px pela aba e com a janela inteira quando aberto
  pelo "Continuar leitura".
- **O alternador de versão é um botão na AppBar que mostra a sigla em uso.** Era
  um `SegmentedButton` ocupando uma linha inteira no leitor e outra no Devocional,
  empilhado sob os chips das três leituras. São duas versões e a escolha é
  persistida; o tooltip nomeia o destino.
- **O tamanho do texto de leitura multiplica só `bodyLarge` e `bodyMedium`.**
  Rótulo de navegação, título e legenda ficam parados, senão aumentar a fonte
  empurra a barra de baixo e quebra o cabeçalho. O `Estado` recusa qualquer valor
  fora de `escalasDeLeitura`, para não haver como travar o app num tamanho
  ilegível. `AppDevocional` compara a escala antes de chamar `setState`, porque o
  `Estado` avisa a árvore a cada favorito e refazer o `ThemeData` nessas horas
  reconstruiria toda tela que depende do tema.
- **Toda tela distingue carregando, erro e vazio.** O padrão antigo
  (`if (!snap.hasData)` ou `snap.data == null`) confundia os três, e um asset que
  falhasse deixava o spinner girando para sempre. Existe `AvisoDeErro` em
  `comuns.dart` para isso.
- **A cópia de segurança das notas vai pela área de transferência**, não por
  arquivo, porque salvar arquivo exigiria ramificar por plataforma, que é o que o
  app evitou desde o começo. Importar **funde**, nunca substitui, e em conflito
  vence quem tem nota, pela mesma razão de `alternarFavorito`. `share_plus` já é
  dependência do app desde que o versículo ganhou "Compartilhar", mas a cópia
  continua pela área de transferência de propósito: exportar por arquivo trocaria
  o "importar" por escolher um arquivo em vez de colar, e colar é o caminho
  simétrico, a mesma caixa de texto serve para os dois lados.
- **A busca das Marcações filtra referência e nota, não o corpo do versículo.**
  O texto do versículo é carregado sob demanda, um por cartão
  (`Conteudo.instancia.versiculo`), e trazer todos para caber numa busca em
  memória derrubaria exatamente o carregamento tardio que o app inteiro foi
  desenhado para ter. Limitação deliberada, documentada em
  `lib/telas/notas.dart`, não um esquecimento.
- **Compartilhar e Copiar usam o mesmo texto formatado**, uma função só
  (`_textoDoVersiculo` em `lib/telas/biblia.dart`) para não duplicar o formato
  entre as duas ações. Em teste, `Clipboard.getData` **trava para sempre** no
  ambiente de widget test (responde `setData`, nunca responde `getData`); a
  forma de verificar o texto copiado é um `setMockMethodCallHandler` próprio no
  canal `SystemChannels.platform`, capturando o argumento de `Clipboard.setData`
  em vez de tentar ler de volta.
- **Os lembretes diários só existem em Android e iOS**
  (`lembretesSuportados` em `lib/data/lembretes.dart`). Não é falta de
  tentativa: notificação com o app fechado exige um agendador de sistema que o
  `flutter_local_notifications` de fato controla, e nem web nem desktop têm
  isso de forma confiável — o mesmo raciocínio que já tirou a camada
  monocromática do ícone do Android.

  **Notificação inexata (`AndroidScheduleMode.inexactAllowWhileIdle`), não
  exata.** Exata exige `SCHEDULE_EXACT_ALARM`, que no Android 14 o usuário
  precisa conceder à mão em Configurações — fluxo pesado para "leia seu
  devocional de manhã", onde uma janela de alguns minutos não importa. Só a
  permissão comum de notificação é pedida (`pedirPermissao`).

  **`data/` continua sem importar `telas/`.** `Leitura` vive em
  `lib/telas/devocional.dart`, não em `lib/data/`; `lembretes.dart` fala em
  `chave` (string: "manha", "promessas", "noite"), e é `main.dart` — que já
  importa os dois lados — quem faz `Leitura.values.byName(chave)`. Se um dia o
  nome do enum mudar, esse é o ponto de quebra.

  **`Lembretes` é interface, não classe** (`Lembretes.instancia`, mutável), com
  uma implementação real e uma falsa (`_LembretesFalsas` em
  `test/lembretes_test.dart`): testar horário e payload contra o plugin de
  verdade exigiria canal de plataforma que o ambiente de teste não tem.

  **`tz.local` é UTC por padrão** no pacote `timezone` — `initializeTimeZones()`
  só carrega o banco, não escolhe o fuso do aparelho. Sem
  `flutter_timezone` + `tz.setLocalLocation(...)`, 6h escolhido pelo usuário
  viraria 6h UTC, 3h no Brasil. Se a detecção falhar, cai em UTC em vez de
  travar o app: horário errado é recuperável no ajuste, app que não abre não é.

  **`android/app/build.gradle.kts` precisa de `isCoreLibraryDesugaringEnabled`
  e `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.** Sem
  isso o Gradle recusa o build com "requires core library desugaring", porque o
  plugin usa `java.time` por baixo.

  **A folha de ajustes ficou alta o bastante para rolar** com a seção
  Lembretes (interruptor mais dois horários) somada a Tamanho e Aparência —
  `ajustesDeLeitura` usa `isScrollControlled: true` e `SingleChildScrollView`
  desde então.

  **`ScheduledNotificationReceiver` faltava no manifesto — nenhum lembrete
  disparava.** Desde a v16 do `flutter_local_notifications` o plugin parou de
  declarar os próprios receptores no `AndroidManifest.xml` do app; o AAR só
  traz `VIBRATE` + `POST_NOTIFICATIONS`, o suficiente para o diálogo de
  permissão funcionar e esconder o problema. Sem o receptor declarado à mão,
  o `AlarmManager` guardava um `PendingIntent` para um componente inexistente
  e, na hora marcada, não havia nada para acordar — sem exceção, sem log.
  Descoberto só ao testar num aparelho de verdade; os testes de
  `test/lembretes_test.dart` não pegam isso porque rodam contra
  `_LembretesFalsas`, nunca contra `LembretesReais` nem contra o manifesto.
  Corrigido declarando `ScheduledNotificationReceiver` e
  `ScheduledNotificationBootReceiver` (mais `RECEIVE_BOOT_COMPLETED`) em
  `android/app/src/main/AndroidManifest.xml`. Com o receptor de boot presente,
  a notificação agendada sobrevive a um reboot — o reagendamento em `main()`
  ao abrir o app continua como rede de segurança, não como único caminho.

  **Canal `lembretes_diarios` com importância alta.** Ficava em
  `Importance.defaultImportance` (padrão), que só aparece na gaveta sem pop-up.
  Ajustado para `Importance.high`/`Priority.high` em
  `LembretesReais._agendarUm` (`lib/data/lembretes.dart`). A importância de um
  canal Android trava na primeira notificação exibida — se o canal já tiver
  sido criado num aparelho de teste antes deste ajuste, é preciso desinstalar
  o app para o valor novo valer.
- **A assinatura de Spurgeon é tinta dourada chapada (`#E3C567`).** Num tema
  claro ela sumiria; o caminho é tingir o mesmo asset pelo tema, não ter duas
  imagens.
- **O `index.html` tem fundo marrom e um marcador de carregamento**, retirado no
  evento `flutter-first-frame`. O Flutter **acrescenta** a `flutter-view` ao body
  em vez de limpá-lo, então sem essa remoção o marcador ficaria por cima do app.
- **BKJ e NVT lado a lado é uma linha por versículo, não duas listas.** Um só
  `ListView` (`_LeitorDuplo` em `lib/telas/biblia.dart`); cada item da lista é
  a `Row` de um versículo, com as duas traduções dentro. Foi a alternativa
  descartada no próprio item do backlog: duas `ListView` com um
  `ScrollController` compartilhado desalinham assim que um lado tem um
  versículo mais longo, porque a altura de cada uma depende do próprio texto.
  Aqui não há como desalinhar, porque o alinhamento é geométrico, não de
  rolagem.

  A união dos números de versículo das duas traduções vem de
  `versiculosMesclados` (pública, para o teste não montar widget nenhum);
  onde só uma tradução tem o número — só acontece em 3 João 1:15 e Apocalipse
  12:18, versificação própria da NVT — o outro lado da linha fica em branco
  em vez de inventar texto.

  **Só entra em janela larga**: o corte é 1100 px, acima dos 720 px que já
  ligam o `NavigationRail`. Abaixo do corte o botão nem aparece, e a
  preferência (`Estado.colunaDuplaAtiva`) fica sem efeito mesmo que tenha
  ficado ligada numa janela larga antes — reabrir numa janela estreita volta
  a uma coluna sozinho, sem precisar desligar à mão.

  Com a coluna dupla ligada, o `BotaoDeVersao` (o alternador BKJ/NVT de uma
  coluna só) some da AppBar: não existe "versão atual" para trocar quando as
  duas já aparecem juntas. No lugar entra só o botão de voltar a uma coluna.

  A ação de tocar um versículo (favoritar, copiar, compartilhar, anotar)
  precisou de `versao` explícito em vez de `estado.versao`: nas duas colunas,
  cada lado grava favorito e nota na sua própria versão
  (`_abrirAcoesDoVersiculo`, extraída de dentro de `_Leitor` para ser
  compartilhada pelas duas).

  Verificado por `flutter analyze`, pela suíte de testes
  (`test/biblia_coluna_dupla_test.dart`) e a olho num Windows de verdade pelo
  usuário.
- **`TelaBiblia.versaoInicial` é sobreposição local, não preferência global.**
  Uma marcação salva na NVT abre na NVT sem mudar a versão preferida do resto
  do app: `_TelaBibliaState._versao` existe separado de `Estado.versao`
  justamente para isso, fixado uma vez em `didChangeDependencies` e só
  persistido globalmente se a pessoa trocar pelo próprio botão da AppBar
  depois de já estar na tela.

  `_Leitor` recebe `versao` explícito do pai (`required this.versao`), do
  mesmo jeito que `_LeitorDuplo` já fazia para as duas colunas — ler
  `estado.versao` direto de dentro de `_Leitor` continuaria mostrando o texto
  certo, mas favoritar ou anotar um versículo aberto por uma marcação
  gravaria na versão global errada, em silêncio.
- **A busca ganhou duas abas: Bíblia e Devocionais.** `TelaBusca`
  (`lib/telas/busca.dart`) virou `DefaultTabController`, mesmo padrão de abas
  que `TelaNotas` já usa para Favoritos/Anotações. Digitar uma referência
  ("João 3:16") mostra um cartão de ir direto no topo da aba Bíblia, via
  `faixaDeVersiculoDaReferencia` (`lib/data/canon.dart`) — a busca de texto
  nunca acharia isso, porque o versículo não contém a própria referência.

  A aba Devocionais busca em Manhã e Noite e Promessas de Deus
  (`Conteudo.buscarDevocionais`), síncrona e sem teto de resultados: os dois
  corpora somam 366+366 registros já cacheados por completo depois da
  primeira leitura, bem mais barato que a varredura de 66 arquivos por versão
  que a busca da Bíblia precisa. `AchadoDevocional.leitura` é uma string
  ("manha"/"noite"/"promessas"), não o enum `Leitura` de
  `lib/telas/devocional.dart` — mesma ponte que `Lembretes` já usa
  (`lib/data/lembretes.dart`), porque `data/` não importa `telas/`.

  A busca da Bíblia também parou de girar para sempre num erro de asset: o
  `.listen()` do stream ganhou `onError`, mostrando `AvisoDeErro` em vez de um
  spinner eterno com lista parcial.

## Próximas implementações

### 1. Confirmar os lembretes num aparelho Android de verdade, com o manifesto corrigido

O item anterior ("verificar num aparelho de verdade") foi fechado sem o teste ter
acontecido, e por isso a falta do `ScheduledNotificationReceiver` (ver seção de
lembretes acima) passou despercebida até o usuário relatar que nenhuma notificação
chegava. Desta vez o teste em aparelho físico precisa mesmo acontecer antes de
fechar o item:

- Desinstalar o app antes de instalar o novo build (o canal `lembretes_diarios`
  trava a importância na primeira notificação exibida).
- Conferir que o build mesclado tem os dois receptores
  (`build/app/intermediates/merged_manifest/debug/AndroidManifest.xml`).
- As notificações chegam no horário (janela de minutos é esperada,
  `inexactAllowWhileIdle`), com pop-up (`Importance.high`).
- Tocar abre a leitura certa, com o app aberto e com o app fechado.
- Reboot sem abrir o app: os alarmes sobrevivem (`adb shell dumpsys alarm`),
  graças ao `ScheduledNotificationBootReceiver` novo.
- iOS continua sem verificação em aparelho físico — só Android foi testado até
  aqui.

## O que foi decidido NÃO fazer

Registrado para não ser reaberto sem motivo novo:

- **Sequência de dias (streak).** Recusada de propósito pelo usuário: transformar
  um dia perdido em perda visível corta contra o espírito de um app devocional.
- **Áudio.** Exige gravação ou síntese de voz; voz sintética lendo Escritura mal
  é pior que não ter.
- **Sincronização entre aparelhos.** Exige servidor e conta. O exportar/importar
  das Marcações já cobre o risco real, que era perder as notas.
- **Cores de marcação.** Mais taxonomia do que um leitor só precisa.
- **Widget na tela inicial.** Código nativo nas duas plataformas para pouco retorno.
- **Lembretes em web e desktop.** Ver a seção de lembretes acima: falta
  infraestrutura confiável para o app fechado disparar algo.
- **Offline de verdade na web.** Investigado e recusado pelo usuário, não só
  adiado. O Flutter 3.44 **removeu** o cache automático que o
  `flutter_service_worker.js` gerado costumava ter: hoje o arquivo só se
  autodesregistra, sem cachear nada (confirmado lendo o gerador do próprio
  SDK, `flutter_tools/lib/src/web/file_generators/js/flutter_service_worker.js`;
  o próprio `--pwa-strategy` está marcado como descontinuado). Segundo
  problema, independente do primeiro: por padrão o CanvasKit (o motor de
  desenho) carrega de `gstatic.com`, não do build local — `--no-web-resources-cdn`
  resolveria isso, mas embutindo o CanvasKit local no download de todo mundo
  (uns 2 a 8 MB a mais), mesmo em quem nunca fica sem rede.

  Fazer direito exigiria escrever um service worker próprio contra um
  mecanismo de registro que o próprio Flutter avisa que vai deixar de
  funcionar numa versão futura. Android e iOS já guardam tudo localmente por
  conta própria; a web é a única plataforma sem isso, e o app não foi pensado
  para "ler no avião" pelo navegador. Não reabrir sem o Flutter trazer de
  volta um jeito suportado de fazer isso.

## Dívida técnica menor, sem prioridade

Achados de uma auditoria, registrados para não precisar redescobrir; nenhum
bloqueia nada:

- `cupertino_icons` no `pubspec.yaml` nunca é referenciado em `lib/`; é
  dependência do template padrão do Flutter.
- `assets/images/felipe_alt.webp` está na lista de assets do `pubspec.yaml`
  mas não é lido por nada em `lib/`.
- `assets/bible/{bkj,nvt}/index.json` nunca são lidos em tempo de execução —
  `canon.dart` já documenta que a lista embutida no código é usada no lugar
  deles.
- `pubspec.yaml` declara `sdk: ^3.9.2` em `environment`, mas o `pubspec.lock`
  já resolveu para `dart: ">=3.12.0 <4.0.0"` — a declaração está defasada em
  relação ao que o projeto de fato usa.
- **Existe uma terceira ramificação por plataforma, não contada na frase "a
  única" acima.** `lib/telas/hoje.dart` (o cabeçalho da tela Hoje) também
  ramifica por `kIsWeb`, escondendo foto e nome na web ("Na web o app fica
  público; sem foto nem nome, só a saudação"). O comportamento é deliberado;
  só a contagem de "única ramificação" na seção dos chevrons está errada.
- `busca.dart` não tinha teste de verdade até a rodada de busca em duas abas,
  além de uma linha que confere que Ctrl+F abre a tela. `test/busca_test.dart`
  cobre o que foi adicionado; não fecha a lacuna mais ampla — por exemplo, o
  tokenizador de destaque de termo (`_destacar`) continua sem teste dedicado.

## Comandos de regeneração de conteúdo

```bash
python tools/extract.py --bibles --devotional --plan
```

```bash
python tools/extract.py --validate
```

```bash
python tools/aplicar_frases.py
```

Os PDFs de origem ficam em `~/Downloads` e fora do repositório.

## Testes

```bash
.fvm/flutter_sdk/bin/flutter test
```
