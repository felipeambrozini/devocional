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
  erro: "#E57373"
typography:
  display:
    fontFamily: "Cinzel"
    fontSize: 34
    fontWeight: 700
    fontVariation: "wght 700"
  headline:
    fontFamily: "Cinzel"
    fontSize: 26
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
  label:
    fontFamily: "Montserrat"
    fontSize: 12
    fontWeight: 600
    fontVariation: "wght 600"
rounded:
  sm: "10px"
  md: "12px"
  lg: "14px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  page: "32px"
components:
  card:
    backgroundColor: "{colors.pergaminho-alto}"
    textColor: "{colors.tinta-de-pregador}"
    rounded: "{rounded.lg}"
    padding: "16px"
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

**Creative North Star: "A Estante Devocional"**

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
discretos: cantos suaves, bordas em fio do metal, sem brilho, sem gradiente,
sem movimento decorativo. Cinzel fala os títulos, Montserrat fala todo o resto.

**Key Characteristics:**
- Solene e sóbria: o texto é o espetáculo, a interface recua.
- Dois temas completos na mesma relação de tons; o claro não é o escuro invertido.
- Chapada por princípio: zero sombras; profundidade por tom e pelo filete de metal.
- Um metal só como acento (ouro no escuro, bronze no claro), usado com parcimônia.
- Cinzel para títulos e cabeçalhos, Montserrat para corpo; escala de leitura do usuário toca só o corpo.
- Cantos suaves (10–14px), bordas em fio do metal a 35–50% de opacidade.

## Colors

A paleta é pergaminho, couro e um único metal que troca de temperatura com o
tema: dourado sobre o couro escuro, bronze sobre o pergaminho claro. Nada mais
carrega cor.

### Primary

- **Ouro de Missal** (#C9A227): no tema escuro, o metal principal — títulos, ícones, chip selecionado, borda de foco, filete do progresso. Sobre o couro dá 6,8:1.
- **Bronze de Encadernação** (#7A5C12): no tema claro, o mesmo papel de metal — títulos, ícones, chip selecionado, borda de foco. Sobre o pergaminho dá 5,5:1.

### Secondary

- **Ouro Claro** (#E3C567): destaque no escuro — citação e referência de devocional, aba ativa, assinatura de Spurgeon (ver Components).
- **Bronze Escuro** (#5E4409): destaque no claro — citação e referência de devocional, aba ativa. É o tom mais distante do pergaminho, que é o que "destaque" quer dizer num fundo claro (8,1:1).

### Tertiary

Não há terceiro acento. O metal tem dois graus (principal e destaque) e um grau de traço/borda: **Ouro Escuro** (#8C6D1F) no escuro, **Bronze Suave** (#C2AE86) no claro.

### Neutral

- **Pergaminho** (#F7F1E3): fundo da página no claro.
- **Pergaminho Alto** (#FFFBF2): cartão e campo no claro.
- **Pergaminho Fundo** (#EFE4CE): cartão dentro de cartão, citação e chip no claro.
- **Couro de Bíblia** (#2E1B10): fundo da página no escuro.
- **Couro Claro** (#3D2417): cartão e campo no escuro.
- **Couro Alto** (#4A2E1D): cartão dentro de cartão, citação e chip no escuro.
- **Bege de Leitura** (#EDE0C8): corpo do texto no escuro (11:1 sobre o couro).
- **Bege Suave** (#C9B99A): texto de apoio no escuro (8,5:1).
- **Tinta de Pregador** (#3D2417): corpo do texto no claro (12,8:1 sobre o pergaminho).
- **Tinta Suave** (#6B5842): texto de apoio no claro (6,0:1).
- **Erro** (#E57373 no escuro, #9B2C2C no claro).

### Named Rules

**A Regra do Metal.** O metal é o único acento do sistema. Ele pinta títulos, ícones, o estado selecionado e o filete — e nada além disso. Nunca é usado como fundo de área grande nem como cor de corpo: correr o ouro pelo texto inteiro é quebrar a sobriedade e a legibilidade (o corpo, nos dois temas, é o bege ou a tinta, nunca o metal).

**A Regra da Não-Inversão.** O claro não é o escuro invertido; o que se mantém entre temas é a relação entre os tons, não os valores. Dourado sobre pergaminho dá 2,1:1 e é proibido — quem precisa do metal num fundo claro usa o bronze. Clarear o bronze "só um pouco" também é proibido: `test/tema_test.dart` mede os contrastes da WCAG e falha se os pares anotados piorarem.

**A Regra dos Papéis.** Nenhuma tela lê a paleta direto: tudo sai de `Theme.of(context).colorScheme` (surface fundo, surfaceContainer cartão, surfaceContainerHighest citação e chip, primary título e ícone, secondary destaque, outline borda, onSurface corpo, onSurfaceVariant apoio). Um `Cores.` solto numa tela é um vazamento.

## Typography

**Display Font:** Cinzel (variável, empacotada localmente)
**Body Font:** Montserrat (variável, empacotada localmente)

**Character:** Cinzel é uma serifa lapidar romana — gravitas de inscrição em
pedra, o peso de um frontispício de Bíblia. Montserrat é uma humanista sem
serifa sóbria que não compete: corpo calmo, legível, que deixa a leitura
acontecer. O par é o da capa e do texto: ornamento nos títulos, clareza no
corpo. As duas são fontes variáveis, e o peso vem de `fontVariations` (nunca de
arquivos por peso), em `lib/theme.dart`.

### Hierarchy

- **Display** (Cinzel, w700, 34px): a referência do capítulo no leitor (`João 3`) e o número grande do progresso. Só na abertura de leitura.
- **Headline** (Cinzel, w600, 26–28px): títulos de tela e de seção dentro de cartões (saudação da Hoje, seções da folha de ajustes, título do devocional).
- **Title** (Cinzel, w600, 18px): título de cartão (`Cartao.titulo`) e da AppBar.
- **Body** (Montserrat, w400, 15–17px): o texto corrido — versículos, devocionais, introduções. A leitura usa `height: 1.6–1.7` e é o único texto que a escala do usuário multiplica.
- **Label** (Montserrat, w600, 11–14px): navegação, referências de citação em caixa alta, legendas, apoio.

### Named Rules

**A Regra das Duas Vozes.** Cinzel fala só títulos e cabeçalhos; Montserrat fala todo o resto — corpo, rótulos, botões, legendas. Uma terceira família, ou Cinzel em texto corrido, quebra a hierarquia da estante.

**A Regra da Escala.** A escala de leitura do usuário multiplica só `bodyLarge` e `bodyMedium` — nunca a navegação, o título, a legenda. Aumentar o texto não pode empurrar a barra de baixo nem quebrar o cabeçalho.

**A Regra do Peso Variável.** O peso das fontes vem de `fontVariations` (`wght`), porque Cinzel e Montserrat são variáveis e declarar peso no pubspec só rotula o arquivo. Um estilo novo que declare só `fontWeight` pode desenhar a instância errada.

## Layout

A coluna de leitura é a unidade do layout: tudo que se lê (versículos, devocional, introdução) vive dentro de `LarguraDeLeitura` com máximo de **720px**, centralizado — nunca mais larga, em qualquer janela. A página respira em ritmo de 8px: 8, 10, 12, 14, 16 (padding do cartão), 20 (padding do devocional e horizontal do leitor), 24, 32 (fundo da lista).

**A Regra da Coluna de Leitura.** Texto de leitura nunca ultrapassa 720px de largura, centralizado. No desktop, o leitor fica na coluna e o espaço em volta respira — o texto nunca vai de ponta a ponta.

## Elevation & Depth

O sistema é **chapado por princípio**: `elevation: 0` em toda superfície, nenhuma sombra em nenhum estado. Profundidade é construída com a escada tonal do Material (surface → surfaceContainer → surfaceContainerHighest) e com o **Filete**, o fio de metal de 2px (48–64px de largura, gradiente do metal principal para o traço) que abre cada leitura e separa seções. Um cartão dentro de um cartão é um tom mais alto, nunca uma sombra; uma seção nova começa com um filete, nunca com uma linha pesada.

**A Regra do Chapado.** Superfícies são planas em repouso e em estado. Sombra não existe neste sistema; se um componente "pedir" profundidade, a resposta é tom (surfaceContainer) ou fio (outline/Filete), não `BoxShadow`.

## Shapes

A linguagem de forma é a do papel impresso e da encadernação: cantos suaves e discretos, bordas em fio do metal. Cartões e chips usam **14px**; botões e campos, **12px**; caixas de citação, **10px**; elementos minúsculos e impressos (a capa do livro, a barra de progresso) usam cantos quase retos de **3–4px**, como se fossem recortados. Bordas são sempre fios do metal a 35–50% de opacidade, nunca uma linha preta cheia; a exceção é a caixa de citação, que ganha um fio de 3px do metal na borda esquerda para ancorar o versículo-base.

**A Regra do Fio.** Toda borda e todo divisor são um fio do metal (1–2px, 35–50% de opacidade). Linha cheia, preta ou cinza neutra não existe no sistema.

## Components

Contidos e discretos: os controles existem para o texto passar. Nenhum componente tem sombra, brilho ou cor de preenchimento chamativa; a presença vem do metal nos estados certos.

### Buttons
- **Shape:** cantos suaves (12px), sem sombra, texto Montserrat w600.
- **Filled** (FilledButton): fundo do metal (Ouro de Missal / Bronze de Encadernação), letra do contrário (couro no escuro, pergaminho-alto no claro). Só para a ação decisiva do diálogo ou da folha — Salvar, Remover.
- **Text** (TextButton): sem fundo, letra na cor de destaque. A ação quieta — Cancelar, Ler tudo, Sair, Exportar.
- **Outlined** (OutlinedButton, com ícone quando entra num contexto): fio do metal com letra de destaque — Continuar leitura, faixa do cronograma, Entrar com Google. É o botão de "abrir alguma coisa".
- **Hover / Focus:** hover escurece o metal no Filled (sem animação de elevação); focus usa o anel de foco padrão do Material 3.

### Chips
- **Style:** sem checkmark (`showCheckmark: false`); selecionado = metal cheio com a letra do contrário por cima; não selecionado = surfaceContainerHighest com fio a 50%.
- **State:** o chip selecionado é o metal chapado — é a maior mancha de cor que o sistema permite, e é só ela.
- **Uso:** o alternador das três leituras (Manhã, Noite, Promessas de Deus) e a escala de texto usam chips, nunca `SegmentedButton` — o segmentado iguala as larguras e "Promessas de Deus" não cabe três vezes num celular.

### Cards / Containers
- **Corner Style:** cantos suaves (14px).
- **Background:** surfaceContainer (Pergaminho Alto / Couro Claro).
- **Shadow Strategy:** nenhuma — ver Elevation & Depth.
- **Border:** fio do metal a 35%.
- **Internal Padding:** 16px; 20px no cartão do devocional.
- **Título:** Cinzel titleLarge (18px w600) na cor do metal, seguido de 12px de respiro antes do conteúdo.

### Inputs / Fields
- **Style:** preenchido (surfaceContainer), fio do metal a 50%, cantos suaves (12px), placeholder em tinta suave.
- **Focus:** o fio vira o metal principal cheio.
- **Uso:** o campo da busca (com lupa no suffix) e o editor de nota no diálogo.

### Navigation
- **Style:** barra embaixo no celular, trilho lateral a partir de 720px; fundo surfaceContainer, rótulos Montserrat w600 de 11–12px.
- **States:** indicador = fio do metal a 45%; ícone e rótulo selecionados na cor de destaque, não selecionados em tinta suave.
- **Mobile:** NavigationBar padrão do Material 3, seis destinos: Hoje, Bíblia, Devocional, Plano, Notas, Conversas.

### Signature Components
- **O Filete:** o fio de metal (2px, 48–64px, gradiente do metal para o traço) que abre capítulos, devocionais, introduções e separa seções dentro de cartões. É a assinatura visual do sistema — a "linha dourada" que diz que uma leitura começa ali.
- **A Assinatura de Spurgeon:** a assinatura do pregador em tinta dourada chapada (Ouro Claro #E3C567), tingida pelo tema com `BlendMode.srcIn` para o metal do tema — um só asset, sempre na cor certa. Fecha o cartão do devocional, centralizada, 40px de altura.
- **A Capa da Bíblia de Estudo Charles Haddon Spurgeon:** a capa do livro (duas variantes, clara e escura) em cantos quase retos (3–4px), abrindo o cartão de introdução e o cabeçalho do devocional. É a peça de ilustração do sistema — a única imagem além da foto do Felipe no app.
- **O Cabeçalho do Leitor:** referência do capítulo em Cinzel displayMedium (28px w700), o título formal do livro em itálico discreto acima, e o Filete separando do texto. O capítulo abre como uma página de livro.
- **A Caixa de Citação:** o versículo-base do devocional — citação em itálico na cor de destaque, referência em caixa alta (titleSmall), tudo num cartão surfaceContainerHighest com fio de metal de 3px à esquerda. É como o sistema mostra a Palavra dentro do comentário.

## Do's and Don'ts

### Do:
- **Do** usar o metal só como acento: títulos, ícones, selecionado, filete — nunca como fundo de área grande.
- **Do** usar o filete (2px, 48–64px, metal para traço) para abrir leituras e separar seções; ele é a identidade do sistema.
- **Do** construir profundidade com tom (surfaceContainer, surfaceContainerHighest) — sem sombra em nenhum estado.
- **Do** manter toda borda como fio do metal a 35–50% (a caixa de citação é a exceção: 3px à esquerda).
- **Do** usar Cinzel só em títulos e cabeçalhos; Montserrat em todo o resto.
- **Do** manter a coluna de leitura em no máximo 720px, centralizada.
- **Do** respeitar o ritmo de 8px (8, 10, 12, 14, 16, 20, 24, 32).
- **Do** desenhar sempre os dois temas com a mesma relação de tons — e conferir os contrastes anotados, que o teste da WCAG guarda.

### Don't:
- **Don't** usar dourado sobre pergaminho (2,1:1, ilegível) nem clarear o bronze — o claro tem o próprio metal, escurecido.
- **Don't** inventar um terceiro acento de cor ou uma terceira família de fonte.
- **Don't** usar `SegmentedButton` para as três leituras (chips).
- **Don't** deixar o texto de leitura passar de 720px, nem multiplicar títulos pela escala do usuário.
- **Don't** ler a paleta direto de `Cores` numa tela — só `Theme.of(context).colorScheme`.
- **Don't** usar sombra, gradiente de fundo, brilho ou movimento decorativo: a estante é chapada, sóbria e solene.