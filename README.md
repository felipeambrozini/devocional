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
- **Favoritos e notas**: qualquer versículo pode ser marcado, anotado, copiado ou
  compartilhado; tela própria lista os favoritos e os que têm anotação, com
  busca por referência ou por texto da nota, e exporta uma cópia de segurança
  de tudo (favoritos, notas e progresso) para reimportar em outro aparelho.
- **Conta Google, só na web**: opcional — favoritos, notas e progresso sobem
  sozinhos para a conta de quem entrar, para não perder nada se o navegador
  limpar o armazenamento. Android, iOS e desktop continuam só com o
  exportar/importar acima; ver `nuvemSuportada` em `lib/data/nuvem.dart`.
- **Busca** no texto da Bíblia.
- **Tamanho do texto** ajustável e **tema claro ou escuro**, pela barra do leitor
  ou do devocional. O padrão segue o aparelho, e dá para fixar um dos dois.
- **Lembrete diário**, opcional, em Android e iOS: notificação de Manhã e
  Promessas de Deus e outra de Noite, cada uma num horário ajustável, abrindo a
  leitura certa ao ser tocada.
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

Na web, cada aba tem a própria URL (`/hoje`, `/biblia`, `/devocional`, `/plano`,
`/notas`), mais `/sobre` — dá para abrir, atualizar ou compartilhar qualquer
uma direto. `?ler=joao.3.16` na URL abre esse versículo por cima da aba, para
links de um versículo específico.

## Stack

- Flutter (Dart), `flutter_localizations` para `pt_BR`.
- `shared_preferences` é o armazenamento local (progresso, favoritos, notas,
  versão preferida), igual em todas as plataformas, sem banco. Na web, quem
  entra com a conta Google também espelha favoritos, notas e progresso num
  documento do Firestore — ver a conta na nuvem, acima.
- `share_plus` para compartilhar um versículo. `flutter_local_notifications` +
  `timezone` + `flutter_timezone` para o lembrete diário, só em Android e iOS
  (ver `lembretesSuportados` em `lib/data/lembretes.dart` e a seção de
  lembretes em `CONTINUAR.md`).
- `go_router` para as rotas por aba, só na web de fato (ver acima); nas
  demais plataformas as mesmas rotas existem mas ninguém compartilha link.
- `firebase_core` + `firebase_auth` + `cloud_firestore` para a conta na
  nuvem, só chamados quando `nuvemSuportada` (`lib/data/nuvem.dart`).
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
python tools/icones.py --og
```

O último passo gera `web/og.png`, a imagem que aparece quando o link do site é
colado no WhatsApp, no Instagram ou numa descrição de live.

A **tela de abertura** acompanha o tema do aparelho em todas as plataformas. O
**ícone do lançador** acompanha no Android, no iOS 18 e no favicon da web; no
Windows, no macOS e no Linux não, porque leem um arquivo só e não têm variante.

No Android, lançadores guardam o ícone em cache: para ver a mudança é preciso
desinstalar antes de instalar de novo, não basta atualizar por cima.

## Conteúdo

Todo o conteúdo (as duas Bíblias, os 366 dias de Manhã e Noite, as 366
Promessas de Deus, as 66 introduções e o cronograma anual) já está carregado e
verificado. `CONTINUAR.md` documenta como regenerar cada parte, as fontes
usadas e as decisões de conteúdo já tomadas, para quem for revisar ou
regenerar algo no futuro.
