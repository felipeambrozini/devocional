# Onde o trabalho parou

Documento de passagem de bastão. Escrito para que uma sessão nova continue sem
precisar reconstruir nenhuma decisão.

## Estado

| Item | Situação |
|---|---|
| App Flutter (mobile + web) | Completo. `flutter analyze` limpo, 458 testes passando |
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
- **O ícone sai da foto, recortado no rosto.** As fontes ficam em `assets/icone/`
  e os arquivos por plataforma são gerados por `dart run flutter_launcher_icons`,
  nunca editados à mão. Três fontes, e cada uma existe por um motivo:
  `icone.png` (rosto ocupando 88%, fundo `#2E1B10`) para iOS, macOS, Windows,
  Android legado e favicon; `icone_adaptativo.png` (60%, fundo transparente)
  para a camada de frente do ícone adaptativo do Android, que o sistema recorta
  em círculo, folha ou pílula; `icone_mascaravel.png` (60%, fundo chapado) para
  os `Icon-maskable-*` da web, porque o Chrome recorta em círculo e descarta os
  20% de fora. O gerador copia o ícone normal nos maskable, o que cortaria o
  topo da cabeça, e gera o favicon em 16, embaçado em tela de retina; por isso
  `tools/icones.py --corrigir` reescreve esses três depois dele. A ordem
  completa, se precisar refazer:

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
  vence quem tem nota, pela mesma razão de `alternarFavorito`.
- **A assinatura de Spurgeon é tinta dourada chapada (`#E3C567`).** Num tema
  claro ela sumiria; o caminho é tingir o mesmo asset pelo tema, não ter duas
  imagens.
- **O `index.html` tem fundo marrom e um marcador de carregamento**, retirado no
  evento `flutter-first-frame`. O Flutter **acrescenta** a `flutter-view` ao body
  em vez de limpá-lo, então sem essa remoção o marcador ficaria por cima do app.

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
