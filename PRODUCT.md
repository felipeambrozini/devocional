# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Felipe Ambrozini, o criador, é o usuário primário: usa o app todo dia no
celular para a leitura devocional pessoal. A partir de 09/08/2026 o app passou
a ser compartilhado com dezenas de pessoas, que o usam principalmente na web
(link do GitHub Pages, distribuído boca a boca). O público é cristão,
falante de português brasileiro, que lê a Bíblia e devocionais diariamente.

## Product Purpose

App devocional diário em português brasileiro com a Bíblia completa (tradução
autoral BKJ 1611, 31.102 versículos, exatamente o canon), devocionais de
Charles Spurgeon (Manhã e Noite, e Promessas de Deus), cronograma anual de
leitura e planos personalizados/compartilhados, introduções aos 66 livros na
voz de Spurgeon, favoritos, notas, busca, leitura em voz alta e chat com IA
(Spurgeon e Felipe). Sucesso é a leitura devocional diária fiel: o texto
certo, no ritmo certo, sem fricção.

## Positioning

A tradução BKJ 1611: uma tradução interna e autoral da linhagem da King James
para o português, com contagem de versículos idêntica ao canon (31.102) e os
66 livros completos — coisa que nenhum app vizinho pode copiar de verdade. A
isso se somam os devocionais de Spurgeon integralmente traduzidos na voz
vitoriana dele, tratando o leitor por "tu".

## Operating Context

- Ritmo diário: leitura de Manhã (0h–17h59) e Noite (18h–23h59), virada pelo
  horário fixo do aparelho, não pelo sol do lugar. Calendário permite ver o
  devocional de qualquer data.
- Cronograma anual: 365 dias (366 em bissexto), 449 faixas, agrupado por mês,
  com marcação de lido e progresso do ano.
- Tema claro ou escuro (padrão segue o aparelho, dá para fixar) e escala do
  texto de leitura, pelas barras do leitor e do devocional.
- Lembrete diário opcional (Android e web), com horários ajustáveis e o
  versículo do dia no corpo da notificação.
- Cópia de segurança de favoritos, notas e progresso por exportar/importar
  (área de transferência); conta Google só na web, para espelhar na nuvem.
- Navegação: abas Hoje, Bíblia, Devocional, Plano, Notas e Conversas; Sobre
  (créditos, canais e ajuda), Perguntas frequentes, Política de privacidade e
  Termos de serviço moram na folha de ajustes. Na web cada aba tem URL própria;
  `/sobre`, `/faq`, `/privacidade`, `/termos` e cada conversa também, e links diretos no formato
  `?ler=joao.3.16` abrem um versículo (`?plano=<id>` abre um plano
  compartilhado).
- Conversas com IA (Gemini): duas personas, Charles Spurgeon e Felipe
  Ambrozini, com histórico salvo por conversa; aba no celular, balão flutuante
  em telas largas.
- Leitura em voz alta (Google Cloud Text-to-Speech): narra capítulos da
  Bíblia, os dois devocionais, Promessas de Deus e as introduções.
- Planos personalizados: escolher livros e a duração; compartilháveis por
  link, com progresso de cada participante (exige conta Google). Quem criou
  pode excluir o plano para todos; quem só participa pode sair, afetando só
  o próprio progresso.
- Avatar da conta (foto do Google ou inicial do nome) na saudação da aba
  Hoje, com foto trocável pela câmera ou galeria.
- Só em pt_BR; conteúdo vem de JSON locais em `assets/`, carregado sob demanda.

## Capabilities and Constraints

- Bíblia BKJ 1611 completa.
- Favoritos, notas, copiar e compartilhar por versículo; busca em duas abas
  (Bíblia e devocionais); a busca das marcações filtra referência e nota, não
  o corpo do versículo (deliberado).
- Texto selecionável e copiável na Bíblia, no Devocional e na Introdução. No
  Devocional e na Introdução, o menu de seleção (o clique forte que já abre a
  seleção) ganha um botão de Compartilhar para o trecho escolhido; na
  Bíblia, Compartilhar continua só pelo toque no versículo (a mesma folha de
  Favoritar, Copiar, Anotar).
- Layout responsivo: barra inferior no celular, trilho lateral a partir de
  720px; gesto de deslizar troca capítulo no celular, setas na web.
- Lembretes por push do servidor (não agendamento local), em Android e web;
  horário decidido a cada 5 min por um job do GitHub Actions, com o
  versículo do dia no corpo — ver README.md.
- Regras de texto do produto: sem travessões em nenhum texto do app e sem
  aspas curvas (só aspas retas); voz vitoriana de Spurgeon tratando o leitor
  por "tu"; citações bíblicas no registro BKJ do app.
- Decisões recusadas de propósito (não reabrir sem motivo novo): streak de
  dias, cores de marcação, widget na tela inicial, lembretes em iOS (falta
  chave APNs), offline de verdade na web, sincronização fora da conta Google
  web. Áudio foi recusado no início e revisto depois (ver Operating
  Context).
- Flutter fixo na versão 3.44.9 (`.fvmrc` e `deploy-web.yml`).

## Brand Commitments

- Nome do produto: "Devocional". Identidade neutra em todas as plataformas
  (rebrand de 20/08/2026, antes só a web pública era neutra): título,
  manifest e Open Graph da web, ícone do app e `android:label` são
  "Devocional", sem foto nem nome do Felipe.
- Ícone do app: marca-texto "Devocional" (fonte Cinzel, mesma composição do
  `web/og.png`), sobre marrom `#2E1B10` (fundo claro `#F7F1E3` para as
  variantes que seguem o tema); montada por `tools/icones.py` e gerada nas
  plataformas por `flutter_launcher_icons`, nunca editada à mão.
- Tela de abertura (splash): a mesma marca-texto "Devocional", sem foto,
  dourada no escuro e em bronze no claro (rebrand de 21/08/2026); montada por
  `tools/icones.py --splash` e gerada nas plataformas por
  `flutter_native_splash`.
- Fontes empacotadas localmente: Cinzel (títulos) e Montserrat (corpo),
  variáveis, pesadas via `fontVariations` em `lib/theme.dart`.
- Duas paletas fixas: marrom e dourado no escuro, pergaminho e bronze no
  claro; o destaque do claro é o metal escurecido (bronze) porque o dourado
  sobre pergaminho dá 2,1:1. As telas leem tudo do `ColorScheme`, nunca de
  `Cores` direto.
- Assinatura de Spurgeon em dourado chapado `#E3C567`, tingida pelo tema.
- A voz vitoriana de Spurgeon em todo conteúdo devocional é compromisso de
  marca (calibrada em 56,3 "!" por 10 mil palavras).

## Evidence on Hand

- Conteúdo todo carregado e verificado (README): BKJ 1611 com 31.102
  versículos, batendo exatamente com o canon; Manhã e Noite com 366 dias completos;
  Promessas de Deus 366/366; cronograma 365/366 dias; 66 introduções completas.
- Suíte de testes em `test/` cobre canon, bissexto, tema (contrastes WCAG),
  fontes, lembretes e comportamento de plataforma.
- Links de canais do Felipe (YouTube e Instagram) na tela Sobre.
- Ausências que não devem ser fabricadas: sem depoimentos de usuários, sem
  listagem em lojas (distribuição é o link do Pages), sem dados de uso ou
  público mensurado.

## Product Principles

1. O hábito diário vale mais que a métrica: nada de streak, perda visível ou
   cobrança por dia perdido; o app incentiva sem punir.
2. O texto é o produto: fidelidade de tradução, voz, tipografia, escala e
   contraste de leitura têm prioridade sobre qualquer recurso novo.
3. Um app só, fiel em todas as plataformas: a mesma experiência e o mesmo
   design em celular, web e desktop; a web serve o público, o celular serve o
   dono, sem bifurcações de produto.
4. Conteúdo verificável: números de versículos, canon e textos devocionais
   são checados contra as fontes; nada de conteúdo inventado ou atribuído.
5. Os dados são do leitor: favoritos, notas e progresso podem sempre ser
   exportados e importados; sincronização em nuvem só onde o armazenamento
   local é frágil (navegador).

## Accessibility & Inclusion

- Contraste WCAG garantido por teste (`test/tema_test.dart` falha se
  clarearem o bronze ou piorarem os pares anotados).
- Escala do texto de leitura ajustável pelo usuário, multiplicando só o corpo
  do texto.
- Tema claro e escuro completos, seguindo o aparelho por padrão.
- Suporte à navegação por teclado no desktop (setas trocam capítulo, Ctrl+F
  abre a busca).