---
name: feature-flag-gate
description: Use sempre que for implementar, esconder ou liberar uma funcionalidade condicionada a um usuário/conta específica (allowlist, gating, "só para alguns e-mails", feature em teste). Nunca reimplemente esse controle na mão.
user-invocable: false
---

# Gating de funcionalidade via `lib/dados/recursos.dart`

Este projeto tem um único mecanismo de feature flag: `Recursos` em
`lib/dados/recursos.dart`. Antes de escrever qualquer `if` que libere ou
esconda algo por e-mail, conta ou "grupo de teste", **leia esse arquivo
primeiro** — o padrão já existente é:

1. Um `static const` booleano simples para recursos que são ligados/desligados
   por reimplantação (ex.: `planoPersonalizado`, `ouvirTextos`).
2. Para recursos restritos por conta: uma allowlist de e-mails vinda de
   `String.fromEnvironment('EMAILS_COM_ALGO')` (passada via `--dart-define`,
   nunca versionada), parseada por `allowlistDeEmails` e exposta como um
   getter estático (`static bool get conversas`) que compara com
   `Nuvem.instancia.email`.
3. Um campo `*Forcado` (`static bool? xForcado`) só para testes poderem
   sobrescrever o resultado sem precisar de login real — sempre `null` em
   produção.

## O que fazer

- **Recurso novo com allowlist de e-mail**: adicione um novo par
  `_emailsComX` / `_allowlistDeX` seguindo exatamente o padrão de
  `_emailsComConversas` / `_allowlistDeConversas`, e um getter `Recursos.x`.
- **Recurso novo ligado por reimplantação**: adicione um `static const bool`
  em `Recursos`, com um comentário curto do porquê (igual aos existentes).
- **Nunca**: comparar e-mail diretamente no widget/tela, hardcodar lista de
  e-mails fora de `recursos.dart`, ou usar `firebase_remote_config`/outro
  serviço externo para isso — o projeto decidiu deliberadamente não ter
  servidor de configuração (app de usuário único).
- Se o recurso precisar de teste, adicione o campo `*Forcado` correspondente
  e resete em `tearDown`, como em `recursos_test.dart`.
