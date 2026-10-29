---
name: auditar-comentarios
description: Audita os comentários de Spurgeon (assets/comentarios) rodando o validador do projeto e resumindo erros e avisos por livro.
disable-model-invocation: true
argument-hint: "[slug-do-livro]"
---

# Auditar comentários

1. Rode `python tools/validar_comentarios.py --resumo` para as contagens por livro.
2. Rode `python tools/validar_comentarios.py $ARGUMENTS` (sem argumento valida tudo).
3. Resuma: total de erros, total de avisos, e os livros/capítulos mais problemáticos, agrupando por tipo (`[TIPO]`).
4. Não edite comentários; para corrigir, sugira a skill `spurgeon-comentarios`.
