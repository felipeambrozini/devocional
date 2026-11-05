---
name: release-checklist
description: Roda a sequência de checagens antes de um push para main com funcionalidade nova ou bug fix (bump de versão, analyze, test, docs, teste web). Use quando o usuário disser que vai subir/publicar/dar push em main, ou pedir para preparar um release.
disable-model-invocation: true
---

# Checklist de release

Siga cada passo em ordem. Não pule etapa nem execute fora de ordem — a ordem
existe porque testes e análise precisam passar **antes** de decidir o bump de
versão, e o bump precisa acontecer **antes** do push.

## 1. Confirme o que está sendo entregue

Pergunte-se (ou confirme com o usuário) se este push contém **funcionalidade
nova**, **bug fix** ou só refactor, ajuste de texto/documentação e iteração
local — esse último caso não mexe na versão.

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

## 5. Bump de versão (funcionalidade nova ou bug fix)

Com o push iminente, ajuste `version: X.Y.Z+N` no `pubspec.yaml` conforme o
passo 1:

- Bug fix: soma 1 ao patch e ao `+N` (`1.15.0+34` → `1.15.1+35`).
- Funcionalidade nova: soma 1 à minor, zera o patch e soma 1 ao `+N`
  (`1.15.1+35` → `1.16.0+36`).
- Só refactor, texto ou documentação: pule este passo.

O `+N` nunca volta atrás nem zera: o Android só atualiza por cima de um build
com `+N` maior, sem precisar desinstalar, e sem bump o testador não consegue
saber se está numa build desatualizada.

## 6. Commit e push

Só depois de 2-5 completos. Siga as instruções de commit já vigentes na
sessão (mensagem, atribuição etc.).
