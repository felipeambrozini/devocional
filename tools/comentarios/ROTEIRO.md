# Roteiro: reescrita dos comentários de Spurgeon

Os comentários de `assets/comentarios/` estão sendo reescritos livro por livro,
de Gênesis a Apocalipse. O Sonnet 5 escreve cada lote e o Opus valida,
reescrevendo o que estiver fora do padrão da skill `spurgeon-comentarios`.
O próprio `assets/` é a fonte da verdade: tudo o que está lá foi validado, e o
que falta é todo versículo da Bíblia sem comentário.

## Laço (repita até aparecer FIM)

1. `python tools/comentarios/proximo.py`: imprime o JSON da próxima unidade
   (`unidade`, `titulo_commit`, `escrever`) e gera os lotes em
   `tools/comentarios/trabalho/lotes/`. Se imprimir `FIM`, vá para o encerramento.
2. `Workflow({name: "comentarios-livro", args: {escrever: [...]}})` com a lista
   `escrever`. Espere a notificação de término, sem ficar consultando.
3. Confira cada lote. Estado esperado: `trabalho/validado/<lote>.ok` existe e
   `python tools/comentarios/checar.py <lote>` sai OK.
   - Sem `.ok`, mas o `checar.py` passa: rode de novo com `{validar: [lotes]}`.
   - O `checar.py` falha ou a saída não existe: rode de novo com `{escrever: [lotes]}`.
4. Com todos os lotes `.ok`:
   - `python tools/comentarios/fundir.py <lotes>` (só funde o que tem `.ok`);
   - `fvm flutter test test/comentario_test.dart`;
   - `git add assets/comentarios/<slug>.json` (caminho explícito, nunca `-A`);
   - `git commit -m "<titulo_commit>"` com a linha Co-Authored-By;
   - **não dar push**.
5. Volte ao passo 1.

Limite de sessão: pare, avise o Felipe e, quando ele mandar continuar, volte ao
passo 1. O `proximo.py` recalcula o que falta, e os lotes já prontos continuam
em `trabalho/`. Atenção: rodar o `proximo.py` apaga e regenera os lotes da
unidade corrente. Numa retomada no meio de uma unidade, confira antes em
`trabalho/` quais lotes já têm `.ok` e dispare só o que falta, sem rodar o
`proximo.py`.

Salmos anda pelos cinco livros do saltério (I 1–41, II 42–72, III 73–89,
IV 90–106, V 107–150), cada um com o seu commit `Comentários Salmos (Livro N)`.

## Encerramento (quando `proximo.py` imprimir FIM)

1. `fvm flutter analyze && fvm flutter test`.
2. Atualizar `README.md` e `PRODUCT.md` onde falam dos comentários.
3. Bump do `+N` em `pubspec.yaml` (funcionalidade nova, push logo em seguida).
4. Commit e **push** para `main`.
5. Apagar `tools/comentarios/trabalho/` e atualizar a memória do projeto.

## Ferramentas

- `checar.py <lote>`: verificador mecânico (molde antigo, tique no lote,
  paráfrase, citação byte a byte, travessão e hífen solto, ênclise lo/la,
  autoria de Hebreus). Lê `molde_chaves.json`.
- `ver.py <lote>`: mostra cada versículo com o comentário atual.
- `proximo.py`: próxima unidade e seus lotes.
- `fundir.py <lotes>`: grava em `assets/` o que foi validado.
- `.claude/workflows/comentarios-livro.js`: o workflow Sonnet + Opus. Fica só nesta máquina, porque o `.gitignore` ignora `.claude/`.
