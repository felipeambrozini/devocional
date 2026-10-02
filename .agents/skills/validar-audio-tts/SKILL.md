---
name: validar-audio-tts
description: Valida mp3 gerados por TTS (Bíblia ou comentários de Spurgeon) contra o texto esperado, transcrevendo de volta com Whisper e comparando a semelhança — antes de subir pro Storage. Use depois de rodar gerar_biblia_at.py/gerar_biblia_nt.py/gerar_comentarios.py, ou quando o usuário perguntar se um áudio gerado está bom/bateu com o texto.
---

# Validar áudio gerado por TTS

`tools/validar_audio.py` transcreve de volta (Whisper, sempre em CPU — nunca
disputa VRAM com o XTTS-v2) cada mp3 já gerado e compara com o texto que foi
mandado pro TTS. O que não bater vira candidato a regeneração.

## Quando usar

Depois de uma leva de geração em `audio_gen_at/`, `audio_gen_nt/` ou
`audio_gen_comentarios/` (Kaggle/Colab), antes do upload pro Storage
(`gcloud storage rsync ... --predefined-acl=publicRead`). Roda local, na CPU
do usuário — não precisa de GPU nem de reabrir Kaggle/Colab só pra validar.

## Como rodar

```
python tools/validar_audio.py biblia --pasta "C:\Users\USER\audio_gen_at\biblia"
python tools/validar_audio.py comentarios --pasta "C:\Users\USER\audio_gen_comentarios\comentarios" --apagar
python tools/validar_audio.py biblia joao --pasta "C:\...\biblia"          # só um livro
python tools/validar_audio.py biblia --pasta "C:\...\biblia" --limiar 0.8  # mais rigoroso (padrão: 0.75)
```

Requer `pip install faster-whisper` (não é dependência do projeto Flutter —
só do ambiente Python onde o `audio_gen_*` roda).

- **Sem `--apagar`**: só reporta (`RUIM <arquivo> (semelhança N%)` com o texto
  esperado e o transcrito lado a lado) — nada é tocado no disco.
- **Com `--apagar`**: os mp3 abaixo do limiar são apagados. Depois, rode de
  novo o `gerar_biblia_at.py` / `gerar_biblia_nt.py` / `gerar_comentarios.py`
  correspondente **sem** `--limpar` — o mecanismo resumível (skip-if-exists)
  já existente regenera só os arquivos que faltam, ou seja, só os que foram
  apagados por serem ruins.

## O que a comparação considera "ruim"

Semelhança (`difflib.SequenceMatcher`, texto normalizado — minúsculo, sem
acento, sem pontuação) entre o texto esperado e a transcrição abaixo do
limiar (padrão 75%). Isso pega bem: fala embolada, corte no meio, trecho
errado, silêncio quase total (Whisper transcreve pouco ou nada). Não é uma
garantia de qualidade auditiva perfeita — um áudio com artefato mas que ainda
soa parecido ao texto pode passar.

## Não confundir com `validar_comentarios.py`

`tools/validar_comentarios.py` valida a **qualidade do texto** do comentário
de Spurgeon (molde/repetição/tamanho) antes de gerar áudio. `validar_audio.py`
valida o **áudio já gerado** contra esse texto, depois. São etapas diferentes
do mesmo pipeline: primeiro o texto passa limpo no validador de texto, só
depois o áudio gerado passa por este.
