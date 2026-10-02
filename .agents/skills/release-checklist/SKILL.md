---
name: release-checklist
description: Roda a sequência de checagens antes de um push para main com funcionalidade nova (bump de versão, analyze, test, docs, teste web). Use quando o usuário disser que vai subir/publicar/dar push em main, ou pedir para preparar um release.
disable-model-invocation: true
---

# Checklist de release

Siga cada passo em ordem. Não pule etapa nem execute fora de ordem — a ordem
existe porque testes e análise precisam passar **antes** de decidir o bump de
versão, e o bump precisa acontecer **antes** do push.

## 1. Confirme o que está sendo entregue

Pergunte-se (ou confirme com o usuário) se este push contém **funcionalidade
nova**. Bug fix, refactor, ajuste de texto/documentação e iteração local não
contam — só funcionalidade nova perto do push justifica bump de versão.

## 2. Analyze + test

```
fvm flutter analyze && fvm flutter test
```

Não prossiga com erro ou warning novo do analyzer, nem com teste falhando.

## 3. Teste web via Playwright

Se a mudança afeta a versão web (qualquer alteração de UI, fluxo ou lógica
visível na web), abra a versão web com o plugin Playwright e teste o caminho
principal e casos de borda da funcionalidade antes de seguir.

## 4. Documentação

Se a mudança afeta o que está documentado em README.md, PRODUCT.md ou
DESIGN.md, atualize esses arquivos agora — não depois do push.

## 5. Bump de versão (só se houver funcionalidade nova)

Se, e só se, o passo 1 confirmou funcionalidade nova e o push é iminente:
incremente o `N` em `version: X.Y.Z+N` no `pubspec.yaml`. Sem funcionalidade
nova, pule este passo — bumpar sem build correspondente distribuída é o que
causou o bug de notificação que "não tinha fix" (era build velha instalada).

## 6. Commit e push

Só depois de 2-5 completos. Siga as instruções de commit já vigentes na
sessão (mensagem, atribuição etc.).
