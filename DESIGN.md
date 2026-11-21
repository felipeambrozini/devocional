---
name: Devocional
description: Bíblia de estudo e devocionais de Spurgeon: pergaminho, couro e metal.
colors:
  ouro-de-missal: "#C9A227"
  ouro-claro: "#E3C567"
  ouro-escuro: "#8C6D1F"
  bronze-de-encadernacao: "#7A5C12"
  bronze-escuro: "#5E4409"
  bronze-suave: "#C2AE86"
  pergaminho: "#F7F1E3"
  pergaminho-alto: "#FFFBF2"
  pergaminho-fundo: "#EFE4CE"
  couro-de-biblia: "#2E1B10"
  couro-claro: "#3D2417"
  couro-alto: "#4A2E1D"
  bege-de-leitura: "#EDE0C8"
  bege-suave: "#C9B99A"
  tinta-de-pregador: "#3D2417"
  tinta-suave: "#6B5842"
  erro-sobre-couro: "#E57373"
  erro-sobre-pergaminho: "#9B2C2C"
  carmim: "#A01C1C"
  carmim-claro: "#F2998E"
typography:
  display:
    fontFamily: "Cinzel"
    fontSize: 28
    fontWeight: 700
    fontVariation: "wght 700"
  headline-large:
    fontFamily: "Cinzel"
    fontSize: 26
    fontWeight: 600
    fontVariation: "wght 600"
  headline:
    fontFamily: "Cinzel"
    fontSize: 22
    fontWeight: 600
    fontVariation: "wght 600"
  headline-small:
    fontFamily: "Cinzel"
    fontSize: 19
    fontWeight: 600
    fontVariation: "wght 600"
  title-appbar:
    fontFamily: "Cinzel"
    fontSize: 20
    fontWeight: 600
    fontVariation: "wght 600"
  title:
    fontFamily: "Cinzel"
    fontSize: 18
    fontWeight: 600
    fontVariation: "wght 600"
  body:
    fontFamily: "Montserrat"
    fontSize: 17
    fontWeight: 400
    fontVariation: "wght 400"
    lineHeight: 1.7
  body-medium:
    fontFamily: "Montserrat"
    fontSize: 15
    fontWeight: 400
    fontVariation: "wght 400"
  label:
    fontFamily: "Montserrat"
    fontSize: 14
    fontWeight: 600
    fontVariation: "wght 600"
  label-medium:
    fontFamily: "Montserrat"
    fontSize: 12
    fontWeight: 400
    fontVariation: "wght 400"
  label-small:
    fontFamily: "Montserrat"
    fontSize: 11
    fontWeight: 600
    fontVariation: "wght 600"
rounded:
  xs: "4px"
  sm: "10px"
  md: "12px"
  lg: "14px"
  pill: "30px"
spacing:
  sp2: "2px"
  sp4: "4px"
  sp6: "6px"
  sp8: "8px"
  sp10: "10px"
  sp12: "12px"
  sp14: "14px"
  sp16: "16px"
  sp18: "18px"
  sp20: "20px"
  sp24: "24px"
  sp32: "32px"
  sp40: "40px"
  sp48: "48px"
  sp56: "56px"
  sp64: "64px"
  sp80: "80px"
  sp120: "120px"
  sp160: "160px"
  sp200: "200px"
  toque: "48px"
components:
  card:
    backgroundColor: "{colors.pergaminho-alto}"
    textColor: "{colors.tinta-de-pregador}"
    rounded: "{rounded.lg}"
    padding: "{spacing.sp16}"
  chip:
    backgroundColor: "{colors.pergaminho-fundo}"
    textColor: "{colors.tinta-de-pregador}"
    rounded: "{rounded.lg}"
  chip-selected:
    backgroundColor: "{colors.bronze-de-encadernacao}"
    textColor: "{colors.pergaminho-alto}"
    rounded: "{rounded.lg}"
  button-primary:
    backgroundColor: "{colors.bronze-de-encadernacao}"
    textColor: "{colors.pergaminho-alto}"
    rounded: "{rounded.md}"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.bronze-escuro}"
    rounded: "{rounded.md}"
  button-text:
    backgroundColor: "transparent"
    textColor: "{colors.bronze-escuro}"
  input:
    backgroundColor: "{colors.pergaminho-alto}"
    textColor: "{colors.tinta-de-pregador}"
    rounded: "{rounded.md}"
  nav:
    backgroundColor: "{colors.pergaminho-alto}"
    textColor: "{colors.tinta-suave}"
---

# Design System: Devocional

## Overview

Creative North Star: **"A Estante Devocional"**

O sistema é uma estante de devocionais antigos: volumes em pergaminho e couro,
fechados com ferragens de metal. A interface se comporta como um livro bem
encadernado — sobriedade vitoriana, sem enfeite; o texto sempre no comando, e o
metal aparecendo pouco para valer muito. É o ambiente de quem lê a Escritura e
Spurgeon devagar, de manhã e de noite: calmo, solene, confiável.

Dois temas completos e igualmente cuidados compõem a mesma relação de tons. O
escuro é couro de Bíblia com ouro de missal: fundo marrom profundo, metal
dourado para títulos e destaques, corpo em bege de leitura. O claro é
pergaminho com bronze de encadernação: fundo de papel quente, o metal
escurecido como destaque, corpo em tinta de pregador. A clara **não é a escura
invertida**: o que se mantém entre os temas é a relação entre os tons, nunca os
valores — o dourado que funciona sobre couro (6,8:1) é ilegível sobre pergaminho
(2,1:1), e por isso o par de destaques vira bronze no claro.

Toda superfície é chapada, sem sombra. Profundidade vem da escada tonal do
Material (surface, surfaceContainer, surfaceContainerHighest) e do Filete — o
filete de metal de 2px que abre cada leitura. Os controles são contidos e
discretos: cantos suaves, bordas em fio do metal, sem brilho, sem gradiente de
fundo, sem movimento decorativo. Cinzel fala os títulos, Montserrat fala todo o
resto.

**Key Characteristics:**

- Solene e sóbria: o texto é o espetáculo, a interface recua.
- Dois temas completos na mesma relação de tons; o claro não é o escuro
  invertido.
- Chapada por princípio: zero sombras; profundidade por tom e pelo filete de
  metal.
- Um metal só como acento (ouro no escuro, bronze no claro), usado com
  parcimônia.
- Cinzel para títulos e cabeçalhos, Montserrat para corpo; a escala de leitura
  do usuário move o corpo inteiro e o resto do texto só 30%, com teto de 1,3×.
- Cantos suaves (10–14px; a pílula de voz é a exceção), bordas em fio do metal a
  35–50% de opacidade.

## Colors

A paleta é pergaminho, couro e um único metal que troca de temperatura com o
tema: dourado sobre o couro escuro, bronze sobre o pergaminho claro. Nada mais
carrega cor.

### Primary

- **Ouro de Missal** (#C9A227): no tema escuro, o metal principal — títulos,
  ícones, chip selecionado, borda de foco, filete do progresso. Sobre o couro dá
  6,8:1.
- **Bronze de Encadernação** (#7A5C12): no tema claro, o mesmo papel de metal —
  títulos, ícones, chip selecionado, borda de foco. Sobre o pergaminho dá 5,5:1.

### Secondary

- **Ouro Claro** (#E3C567): destaque no escuro — citação e referência de
  devocional, aba ativa, assinatura de Spurgeon (ver Components).
- **Bronze Escuro** (#5E4409): destaque no claro — citação e referência de
  devocional, aba ativa. É o tom mais distante do pergaminho, que é o que
  "destaque" quer dizer num fundo claro (8,1:1).

### Tertiary

Não há terceiro acento. O metal tem dois graus (principal e destaque) e um grau
de traço/borda: **Ouro Escuro** (#8C6D1F) no escuro, **Bronze Suave** (#C2AE86)
no claro.

A única exceção é a **letra vermelha** (papel `tertiary`), que não é acento de
interface: só pinta, no leitor da Bíblia, as falas de Deus Pai, Jesus e Espírito
Santo, como nas Bíblias impressas de letra vermelha. **Carmim** (#A01C1C) no
claro, **Carmim Claro** (#F2998E) no escuro; passam de 4,5:1 em todo fundo de
versículo, mesmo recuadas a 0.9 sobre o selecionado (o teste da WCAG guarda).
Nunca em botão, ícone ou título.

### Neutral

- **Pergaminho** (#F7F1E3): fundo da página no claro.
- **Pergaminho Alto** (#FFFBF2): cartão e campo no claro.
- **Pergaminho Fundo** (#EFE4CE): cartão dentro de cartão, citação e chip no
  claro.
- **Couro de Bíblia** (#2E1B10): fundo da página no escuro.
- **Couro Claro** (#3D2417): cartão e campo no escuro.
- **Couro Alto** (#4A2E1D): cartão dentro de cartão, citação e chip no escuro.
- **Bege de Leitura** (#EDE0C8): corpo do texto no escuro (11:1 sobre o couro).
- **Bege Suave** (#C9B99A): texto de apoio no escuro (8,5:1).
- **Tinta de Pregador** (#3D2417): corpo do texto no claro (12,8:1 sobre o
  pergaminho).
- **Tinta Suave** (#6B5842): texto de apoio no claro (6,0:1).
- **Erro** (#E57373 no escuro, sobre o couro; #9B2C2C no claro, sobre o
  pergaminho): o papel `error`. Os dois tons são definidos direto em
  `lib/estilo/tema.dart`, no `ColorScheme` de cada paleta, e não em
  `DevocionalCores`.

### Named Rules

**A Regra do Metal.** O metal é o único acento do sistema. Ele pinta títulos,
ícones, o estado selecionado e o filete — e nada além disso. Nunca é usado como
fundo de área grande nem como cor de corpo: correr o ouro pelo texto inteiro é
quebrar a sobriedade e a legibilidade (o corpo, nos dois temas, é o bege ou a
tinta, nunca o metal). A única exceção é o preenchimento do `FilledButton` (ver
Buttons em Components): a ação decisiva do sistema é, de propósito, a maior
mancha de metal que uma tela pode ter — é o que a torna reconhecível como *a*
ação, e não uma cor de corpo correndo solta.

**A Regra da Não-Inversão.** O claro não é o escuro invertido; o que se mantém
entre temas é a relação entre os tons, não os valores. Dourado sobre pergaminho
dá 2,1:1 e é proibido — quem precisa do metal num fundo claro usa o bronze.
Clarear o bronze "só um pouco" também é proibido: `test/tema_test.dart` mede os
contrastes da WCAG e falha se os pares anotados piorarem.

**A Regra dos Papéis.** Nenhuma tela lê a paleta direto: tudo sai de
`Theme.of(context).colorScheme` (surface fundo, surfaceContainer cartão,
surfaceContainerHighest citação e chip, primary título e ícone, secondary
destaque, outline borda, outlineVariant divisor (o outline a 40%), onSurface
corpo, onSurfaceVariant apoio). Um `DevocionalCores.` solto numa tela é um
vazamento. A única exceção é o cartão de compartilhar
(`lib/funcoes/cartao_imagem.dart`): é uma imagem exportada, pintada fora da
árvore de widgets e sempre na paleta escura (de propósito, para a imagem ser a
mesma em qualquer tema), então lê `DevocionalCores` direto — Cinzel na marca e
na assinatura, Montserrat no corpo.

## Typography

**Display Font:** Cinzel (variável, empacotada localmente)
**Body Font:** Montserrat (variável, empacotada localmente)

**Character:** Cinzel é uma serifa lapidar romana — gravitas de inscrição em
pedra, o peso de um frontispício de Bíblia. Montserrat é uma humanista sem
serifa sóbria que não compete: corpo calmo, legível, que deixa a leitura
acontecer. O par é o da capa e do texto: ornamento nos títulos, clareza no
corpo. As duas são fontes variáveis, e o peso vem de `fontVariations` (nunca de
arquivos por peso), em `lib/estilo/tema.dart`.

### Hierarchy

- **Display** (Cinzel, w700, 28px — `displayMedium`): a referência do capítulo
  no leitor (`João 3`) e o título das páginas de texto (Sobre, FAQ, Privacidade,
  Termos, Admin). `displayLarge` (34px) existe no tema, mas nenhuma tela usa.
- **Headline** (Cinzel, w600, 19–26px): `headlineMedium` (22px) é a saudação da
  Hoje, o título do devocional e o do capítulo aberto; `headlineSmall` (19px) é
  o título de seção — seções da folha de ajustes e de Sobre, diálogos, avisos
  vazios, seletores de livro; `headlineLarge` (26px) só aparece na inicial do
  retrato de persona quando falta a foto.
- **Title** (Cinzel, w600): 18px no título de cartão (`Cartao.titulo`,
  `titleLarge`); 20px no título da AppBar. `titleMedium` e `titleSmall` são
  Montserrat w600 (16 e 14px; o pequeno na cor de apoio) — subtítulos e a
  referência das citações.
- **Body** (Montserrat, w400, 15–17px): o texto corrido — versículos,
  devocionais, introduções (`bodyLarge` 17, `bodyMedium` 15). A leitura usa
  `height: 1.6–1.7` e é o único texto que acompanha a escala do usuário por
  inteiro. `bodySmall` (13px, cor de apoio) é texto secundário e não é leitura.
- **Label** (Montserrat): `labelLarge` 14px w600 (botões, abas), `labelMedium`
  12px w400 e `labelSmall` 11px w600, os dois na cor de apoio (atribuições,
  legendas, miudezas). Os rótulos da navegação são Montserrat w600 de 11–12px.

### Named Rules

**A Regra das Duas Vozes.** Cinzel fala só títulos e cabeçalhos; Montserrat fala
todo o resto — corpo, rótulos, botões, legendas. Uma terceira família, ou Cinzel
em texto corrido, quebra a hierarquia da estante.

**A Regra da Escala.** A escala de leitura do usuário vai de 0,7× a 2×
(`escalasDeLeitura`). O corpo de leitura (`bodyLarge`, `bodyMedium`) acompanha a
escala inteira; títulos, rótulos, botões, chips, snackbar, navegação e todo o
resto do texto do tema passam por `escalarTitulo` (`lib/estilo/tema.dart`), que
aplica só 30% do pedido e fica preso entre 1× e 1,3× — não encolhem no Mínimo
e, no 2×, crescem só 30%. O texto que se lê cresce de verdade; o que emoldura a
leitura cresce pouco, para não empurrar a barra de baixo nem quebrar o
cabeçalho.

**A Regra do Peso Variável.** O peso das fontes vem de `fontVariations`
(`wght`), porque Cinzel e Montserrat são variáveis e declarar peso no pubspec só
rotula o arquivo. Um estilo novo que declare só `fontWeight` pode desenhar a
instância errada: para mudar o peso de um estilo do tema numa tela, use
`.comPeso(FontWeight.wXXX)` (extensão em `lib/estilo/tema.dart`), nunca
`copyWith(fontWeight:)`.

## Layout

A coluna de leitura é a unidade do layout: tudo que se lê (versículos,
devocional, introdução) vive dentro de `LarguraDeLeitura` com máximo de
**720px**, centralizado — nunca mais larga, em qualquer janela.

O espaço sai de `DevocionalEspacamento` (`lib/estilo/espacamento.dart`), em que
cada token guarda o próprio valor em pixels: os miúdos `sp2`, `sp4`, `sp6`
(folgas de ícone, retrato e texto); o miolo do layout de 2 em 2,
`sp8` a `sp20` (8, 10, 12, 14, 16, 18, 20; 16 é o padding do cartão, 20 o do
devocional e o horizontal do leitor); depois `sp24`, `sp32` (fundo da lista),
`sp40`, `sp48`, `sp56`, `sp64`, e `sp80` a `sp200` para vãos estruturais e áreas
de respiro. Não é um ritmo de 8px: 4, 6 e 18 são degraus de uso corrente, e é a
escala, não o múltiplo, que mantém o espaço coerente. Áreas tocáveis desenhadas
à mão (fora dos controles do Material, que já trazem a própria área) têm no
mínimo `DevocionalToque.minimo`, 48dp (`lib/estilo/toque.dart`) — o mesmo alvo
do `materialTapTargetSize.padded`.

**A Regra da Coluna de Leitura.** Texto de leitura nunca ultrapassa 720px de
largura, centralizado. No desktop, o leitor fica na coluna e o espaço em volta
respira — o texto nunca vai de ponta a ponta.

## Elevation & Depth

O sistema é **chapado por princípio**: `elevation: 0` em toda superfície,
nenhuma sombra em nenhum estado. Profundidade é construída com a escada tonal do
Material (surface → surfaceContainer → surfaceContainerHighest) e com o
**Filete**, o fio de metal de 2px (48–64px de largura, gradiente do metal
principal para o traço) que abre cada leitura e separa seções. Um cartão dentro
de um cartão é um tom mais alto, nunca uma sombra; uma seção nova começa com um
filete, nunca com uma linha pesada.

Os únicos gradientes do sistema são o do Filete e o da alça de deslize do leitor
(`lib/widgets/alca_de_deslize.dart`): uma faixa de 24px na borda da tela, do
metal com pouca opacidade ao transparente, com o ícone de pegar, que avisa que
dá para arrastar e trocar de capítulo. Nenhum fundo, cartão ou botão ganha
gradiente. A máscara que apaga o fim da prévia de um texto
(`com_fade_ao_fim.dart`) usa um gradiente como transparência, não como cor:
não pinta nada, só some com as últimas linhas.

**A Regra do Chapado.** Superfícies são planas em repouso e em estado. Sombra
não existe neste sistema; se um componente "pedir" profundidade, a resposta é
tom (surfaceContainer) ou fio (outline/Filete), não `BoxShadow`. O que flutua
sobre a página sem sombra (menu de opções e aviso de rodapé, o SnackBar) usa o
tom mais alto, surfaceContainerHighest, com o fio do metal cheio em volta, senão
some contra o fundo no tema claro. A barra da seleção de versículos, presa ao
pé da tela, segue a mesma gramática com o fio só na borda de cima. O
`DropdownButton` não entra no app: o menu dele tem sombra fixa e um fio cinza
por baixo; filtros de poucas opções são chips.

## Shapes

A linguagem de forma é a do papel impresso e da encadernação: cantos suaves e
discretos, bordas em fio do metal. Cartões e chips usam **14px**; botões, campos
e menus, **12px**; caixas de citação, **10px**; elementos minúsculos e impressos
(as capas, a barra de progresso) usam cantos quase retos de **3–4px**, como se
fossem recortados. Duas formas fogem da escala: a **pílula de voz**
(`botao_de_voz.dart`), o único controle arredondado por inteiro (30px), porque é
um comprimido flutuante e não um botão de diálogo; e o realce de toque do cartão
de referência de versículo (`cartao_de_referencia.dart`), de **8px**, que só
aparece no toque. Bordas são sempre fios do metal a 35–50% de opacidade, nunca
uma linha preta cheia; a exceção é a caixa de citação, que ganha um fio de 3px
do metal na borda esquerda para ancorar a voz citada.

**A Regra do Fio.** Toda borda e todo divisor são um fio do metal (1–2px, 35–50%
de opacidade). Linha cheia, preta ou cinza neutra não existe no sistema. O fio
só vira o metal principal cheio para marcar estado ou presença: o campo em foco,
o cartão do dia destacado no cronograma (`cartao_de_dia.dart`, 1,6px), a pílula
de voz tocando ou pausada (1,5px), o anel em volta do retrato de quem fala
(1,5px) e a borda do que flutua sem sombra (menu e aviso, ver Elevation &
Depth). O campo com erro troca o fio pela cor de erro (2px em foco). Fora desses
casos, o metal cheio numa borda é um desvio. O versículo selecionado (modo de
seleção) também é estado: tom mais alto (surfaceContainerHighest) com o fio do
metal cheio de 1,5px, cerca de 5:1 contra a página nos dois temas. O fundo não
é o metal: a Regra do Metal não deixa o ouro pintar área.

## Components

Contidos e discretos: os controles existem para o texto passar. Nenhum
componente tem sombra, brilho ou cor de preenchimento chamativa; a presença vem
do metal nos estados certos.

### Buttons

- **Shape:** cantos suaves (12px), sem sombra, texto Montserrat w600.
- **Filled** (FilledButton): fundo do metal (Ouro de Missal / Bronze de
  Encadernação), letra do contrário (couro no escuro, pergaminho-alto no claro).
  Só para a ação decisiva do diálogo ou da folha — Salvar, Remover.
- **Text** (TextButton): sem fundo, letra na cor de destaque. A ação quieta —
  Cancelar, Ler tudo, Sair, Exportar.
- **Outlined** (OutlinedButton, com ícone quando entra num contexto): fio do
  metal a 50% com letra de destaque — Continuar leitura, faixa do cronograma,
  Entrar com Google. É o botão de "abrir alguma coisa".
- **Hover / Focus:** o hover do Filled é o overlay padrão do Material 3, a letra
  (`onPrimary`) a ~8% sobre o metal — no escuro escurece o ouro (a letra é o
  couro), no claro clareia o bronze (a letra é o pergaminho-alto); sem animação
  de elevação; focus usa o overlay padrão do Material 3, sem anel nem fundo
  reforçado (o anel de 2px foi testado e recusado: a troca de aba punha o foco
  no primeiro botão da tela, e o anel aparecia num botão que ninguém tinha
  tocado). A troca de aba hoje põe o foco numa âncora invisível
  (`DevocionalAncoraDeFoco`), então só um Tab de verdade chega aos botões. Alvos
  de toque sempre com 48dp (`materialTapTargetSize.padded`;
  `DevocionalToque.minimo` nas áreas tocáveis desenhadas à mão), inclusive no
  desktop web.

### Chips

- **Style:** sem checkmark (`showCheckmark: false` no `chipTheme`, valendo para
  todo chip); selecionado = metal cheio com a letra do contrário por cima; não
  selecionado = surfaceContainerHighest com fio a 50%.
- **State:** o chip selecionado é o metal chapado — é a maior mancha de cor que
  o sistema permite, e é só ela.
- **Uso:** o alternador das três leituras (Manhã, Noite, Promessas de Deus) e a
  escala de texto usam chips, nunca `SegmentedButton` — o segmentado iguala as
  larguras e "Promessas de Deus" não cabe três vezes num celular.

### Cards / Containers

- **Corner Style:** cantos suaves (14px).
- **Background:** surfaceContainer (Pergaminho Alto / Couro Claro).
- **Shadow Strategy:** nenhuma — ver Elevation & Depth.
- **Border:** fio do metal a 35%.
- **Internal Padding:** 16px; 20px no cartão do devocional.
- **Título:** Cinzel titleLarge (18px w600) na cor do metal, seguido de 12px de
  respiro antes do conteúdo. A exceção é o cartão de apoio em crise do chat,
  em Montserrat titleMedium: o Cinzel, mais largo, quebra em várias linhas com
  fonte grande e empurraria o botão do 188 para fora da tela.

### Inputs / Fields

- **Style:** preenchido (surfaceContainer), borda na cor de apoio do texto
  (onSurfaceVariant), cantos suaves (12px), placeholder em tinta suave. É a
  exceção à Regra do Fio: o traço do metal fica abaixo dos 3:1 que a borda de um
  campo precisa.
- **Focus:** o fio vira o metal principal cheio.
- **Uso:** o campo da busca (com lupa no suffix) e o editor de nota no diálogo.

### Bottom Sheets

- **Alça:** toda folha mostra a alça central (`showDragHandle` no tema) e fecha
  arrastando para baixo. A alça ocupa 48px no topo: folhas sem
  `isScrollControlled` (limite de 9/16 da tela) descontam essa altura ou rolam o
  conteúdo, para não cortar a última ação em paisagem.
- **Topo:** folhas com `isScrollControlled` usam `useSafeArea`, para a alça não
  ficar sob a barra de status.

### Navigation

- **Style:** barra embaixo no celular, trilho lateral a partir de 720px; fundo
  surfaceContainer, rótulos Montserrat w600 de 11–12px.
- **States:** indicador = fio do metal a 45%; ícone e rótulo selecionados na cor
  de destaque, não selecionados na cor de apoio (tinta suave no claro, bege
  suave no escuro). As abas (`tabBarTheme`) seguem a mesma regra: aba ativa na
  cor de destaque, inativa na de apoio, indicador no metal principal, rótulo
  Montserrat 14px w600.
- **Mobile:** NavigationBar padrão do Material 3, seis destinos: Hoje, Bíblia,
  Devocional, Biblioteca, Plano, Conversas. Os rótulos ficam sempre numa linha:
  em tela estreita (ou com fonte do sistema maior) o tamanho encolhe só o
  bastante para "Devocional" caber, nunca troca o nome.
- **Título da barra do Devocional:** a data ("Hoje, 21 de novembro") divide a
  barra com quatro ações e também encolhe só o bastante para caber numa linha,
  como os rótulos da navegação. A data completa se repete no título do cartão,
  que não encolhe.

### Signature Components

- **O Filete:** o fio de metal (2px, 48–64px, gradiente do metal para o traço)
  que abre capítulos, devocionais, introduções e separa seções dentro de
  cartões. É a assinatura visual do sistema — a "linha dourada" que diz que uma
  leitura começa ali.
- **A Assinatura de Spurgeon:** a assinatura do pregador em tinta dourada
  chapada (Ouro Claro #E3C567), tingida pelo tema com `BlendMode.srcIn` na cor
  de destaque (`secondary`) — um só asset, sempre na cor certa. Fecha o cartão
  do devocional, centralizada, 40px de altura.
- **As Capas:** a capa da Bíblia de Estudo Charles Haddon Spurgeon (duas
  variantes, clara e escura) abre o cartão de introdução do livro
  (`abertura_de_livro.dart`) em cantos quase retos (3px). O devocional tem capa
  própria — Manhã e Noite ou Promessas de Deus —, à esquerda do título, com
  cantos de 4px, e as obras da Biblioteca (22 capas) usam a mesma moldura
  (`capa_de_obra.dart`). Os renders formam três famílias, todas em dourado
  sobre o couro e com a mesma gravura de Spurgeon no púlpito, a marca da casa:
  a Bíblia de Estudo em couro liso, cantos arredondados e corte dourado, com
  uma cruz no alto e Spurgeon num arco gótico (a clara e a escura têm o mesmo
  desenho); os devocionais em meia-encadernação de couro e linho, com o título
  numa cartela e Spurgeon num oval sob o céu do livro (sol e lua em Manhã e
  Noite, estrelas em Promessas); os livros em couro granulado com nervuras,
  medalhão com o símbolo da obra e Spurgeon sem moldura. O título tem pelo
  menos 4,5:1 de contraste com o couro. As capas são a peça de ilustração do
  sistema; as outras
  imagens do app são os retratos de Spurgeon e do Felipe (no anel do metal, nas
  conversas e no botão de voz), a assinatura de Spurgeon e os ícones dos canais
  em Sobre. Nada de ilustração decorativa.
- **O Cabeçalho do Leitor:** referência do capítulo em Cinzel displayMedium
  (28px w700), o título formal do livro em itálico discreto acima, e o Filete
  separando do texto. O capítulo abre como uma página de livro. O título no
  corpo é só título: livro e capítulo se escolhem num lugar só, o título da
  barra de cima, que abre a grade de capítulos do livro aberto (com "Todos os
  livros" para trocar de livro). O capítulo termina com o botão "Próximo:
  Êxodo 1", em todas as plataformas, porque o deslize é invisível.
- **A Caixa de Citação:** um bloco surfaceContainerHighest com cantos de 10px e
  fio de metal de 3px à esquerda — é como o sistema destaca uma voz citada
  dentro da página. Abriga a frase de abertura da introdução do livro (citação
  em itálico na cor de destaque, atribuição em `labelMedium`) e empresta a mesma
  gramática à bolha e ao balcão das conversas, à marcação, ao comentário no
  capítulo e ao erro de resposta. A exceção é a bolha de quem escreve, que leva
  o fio a 40% em volta inteira e não o de 3px à esquerda: o fio lateral fica
  para a voz citada (a persona), e a diferença de moldura diz quem fala.
- **A Epígrafe do Devocional:** o versículo-base do devocional não usa a caixa:
  é uma epígrafe solta sob o título, ao lado da capa — citação em itálico na cor
  de destaque, seguida da referência (`titleSmall`, também na cor de destaque);
  tocar na referência abre o capítulo com os versículos citados marcados.
- **A Faixa de Progresso (`DevocionalProgressoFino`):** trilho do tema com o fio
  do metal por cima, cantos quase retos de 3px e 6px de altura. Um só desenho
  para o progresso do ano, dos planos, dos participantes de um plano
  compartilhado e do download de áudio por categoria na folha de ajustes; a
  pílula de voz tem trilho próprio porque precisa contrastar com o fundo do
  comprimido, não com a página.

## Do's and Don'ts

### Do

- **Do** usar o metal só como acento: títulos, ícones, selecionado, filete —
  nunca como fundo de área grande.
- **Do** usar o filete (2px, 48–64px, metal para traço) para abrir leituras e
  separar seções; ele é a identidade do sistema.
- **Do** construir profundidade com tom (surfaceContainer,
  surfaceContainerHighest) — sem sombra em nenhum estado.
- **Do** manter toda borda como fio do metal a 35–50% (a caixa de citação é a
  exceção: 3px à esquerda; o metal cheio só marca estado ou presença — foco, dia
  destacado, voz ativa, retrato de quem fala).
- **Do** usar Cinzel só em títulos e cabeçalhos; Montserrat em todo o resto.
- **Do** manter a coluna de leitura em no máximo 720px, centralizada.
- **Do** tirar todo espaço dos degraus de `DevocionalEspacamento`
  (`sp2`…`sp200`), nunca de um número solto, e dar 48dp
  (`DevocionalToque.minimo`) a toda área tocável desenhada à mão.
- **Do** desenhar sempre os dois temas com a mesma relação de tons — e conferir
  os contrastes anotados, que o teste da WCAG guarda.

### Don't

- **Don't** usar dourado sobre pergaminho (2,1:1, ilegível) nem clarear o bronze
  — o claro tem o próprio metal, escurecido.
- **Don't** inventar um terceiro acento de cor ou uma terceira família de fonte
  (a letra vermelha das falas de Deus é texto bíblico, não acento, e fica só no
  leitor).
- **Don't** usar `SegmentedButton` para as três leituras (chips).
- **Don't** deixar o texto de leitura passar de 720px, nem deixar títulos e
  rótulos passarem de 1,3× pela escala do usuário (só o corpo de leitura vai até
  2×).
- **Don't** ler a paleta direto de `DevocionalCores` numa tela — só
  `Theme.of(context).colorScheme` (o cartão de compartilhar, imagem sempre
  escura, é a exceção).
- **Don't** usar sombra, gradiente de fundo (fora o Filete e a alça de deslize),
  brilho ou movimento decorativo: a estante é chapada, sóbria e solene.
