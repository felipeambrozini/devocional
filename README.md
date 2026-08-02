# Devocional

Aplicativo devocional pessoal do Felipe, em Flutter (Android, iOS, web, macOS,
Windows e Linux a partir do mesmo código).

## O que o app faz

- **Bíblia completa**, em duas versões: **BKJ 1611** (King James em português,
  31.102 versículos) e **NVT** (31.104 versículos). Leitor por capítulo, com
  seletor dos 66 livros nos dois testamentos e alternância de versão sem perder
  o lugar.
- **Devocional diário**, três leituras por dia, na voz de Charles Spurgeon:
  - **Manhã** e **Noite** (*Morning and Evening*), uma virada automática entre
    as duas: 0h-17h59 mostra o devocional da manhã, 18h-23h59 o da noite,
    pelo horário do próprio aparelho.
  - **Promessas de Deus** (*Faith's Checkbook*), uma promessa bíblica por dia,
    com título, referência e comentário.
  - Calendário para ver o devocional de qualquer data, passada ou futura.
- **Cronograma de leitura anual**, 365 dias (366 em ano bissexto), agrupado por
  mês, com marcação de lido e barra de progresso do ano.
- **Introduções aos 66 livros**, na voz de Spurgeon, com título formal do livro
  vindo da BKJ 1611.
- **Favoritos e notas**: qualquer versículo pode ser marcado, anotado ou copiado;
  tela própria lista os favoritos e os que têm anotação, e exporta uma cópia de
  segurança de tudo (favoritos, notas e progresso) para reimportar em outro
  aparelho.
- **Busca** no texto da Bíblia.
- **Tamanho do texto** ajustável e **tema claro ou escuro**, pela barra do leitor
  ou do devocional. O padrão segue o aparelho, e dá para fixar um dos dois.
- Layout responsivo: barra de navegação embaixo no celular, trilho lateral em
  janela larga (a partir de 720px), coluna de leitura com largura confortável
  no desktop.
- Navegação por gesto e por teclado: deslizar troca de capítulo no celular; no
  Windows e na web as setas passam de capítulo e `Ctrl+F` abre a busca.

## Telas

| Aba | Conteúdo |
|---|---|
| Hoje | Saudação, prévia das três leituras do dia, leitura do cronograma, progresso do ano, atalho para continuar de onde parou |
| Bíblia | Leitor por capítulo, os 66 livros, introdução de cada um |
| Devocional | Manhã, Noite e Promessas de Deus, com calendário |
| Plano | Cronograma anual por mês, com marcação de lido |
| Notas | Favoritos e anotações |

## Stack

- Flutter (Dart), `flutter_localizations` para `pt_BR`.
- `shared_preferences` é o único armazenamento (progresso, favoritos, notas,
  versão preferida), igual em todas as plataformas, sem banco.
- Fontes empacotadas localmente (Cinzel e Montserrat), sem depender de rede na
  primeira execução.
- Conteúdo (Bíblia, devocionais, introduções, cronograma) vem de arquivos JSON
  em `assets/`, um arquivo por livro por versão, carregado sob demanda.

## Estrutura

```
lib/
  data/        modelos, canon (os 66 livros), leitura de conteúdo, estado persistido
  telas/       uma tela por arquivo (hoje, bíblia, devocional, plano, notas, busca...)
  theme.dart   as duas paletas: marrom e dourada, pergaminho e bronze
  main.dart    navegação (barra/trilho) e ponto de entrada
assets/        Bíblias (BKJ e NVT), devocionais, introduções, cronograma, imagens, fontes
tools/         scripts Python para gerar/validar o conteúdo a partir dos PDFs de origem
test/          testes de unidade e de widget
```

## Rodando

```bash
flutter pub get
flutter run
```

## Testes e análise

```bash
flutter test
flutter analyze
```

## Gerando o app

```bash
flutter build apk       # Android
flutter build ios       # iOS
flutter build web       # Web
flutter build windows   # Windows
flutter build macos     # macOS
```

Ícone do app, favicon e tela de abertura são gerados a partir das fontes em
`assets/icone/`; nunca editados à mão (ver `CONTINUAR.md`).

```bash
python tools/icones.py --fontes
dart run flutter_launcher_icons
dart run flutter_native_splash:create
python tools/icones.py --corrigir
```

A **tela de abertura** acompanha o tema do aparelho em todas as plataformas. O
**ícone do lançador** só no iOS 18 e no favicon da web: Android, Windows, macOS e
Linux leem um arquivo só e não têm variante por tema.

## Conteúdo

Todo o conteúdo (as duas Bíblias, os 366 dias de Manhã e Noite, as 366
Promessas de Deus, as 66 introduções e o cronograma anual) já está carregado e
verificado. `CONTINUAR.md` documenta como regenerar cada parte, as fontes
usadas e as decisões de conteúdo já tomadas, para quem for revisar ou
regenerar algo no futuro.
