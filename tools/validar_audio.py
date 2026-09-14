#!/usr/bin/env python3
"""Valida mp3 gerados por TTS (XTTS-v2) contra o texto esperado, transcrevendo
de volta com Whisper (sempre em CPU) e comparando a semelhanca.

Uso:
  python tools/validar_audio.py biblia --pasta "C:\\Users\\USER\\audio_gen_at\\biblia"
  python tools/validar_audio.py comentarios --pasta "C:\\Users\\USER\\audio_gen_comentarios\\comentarios" --apagar
  python tools/validar_audio.py biblia joao --pasta ...\\biblia          # so um livro
  python tools/validar_audio.py biblia --pasta ...\\biblia --limiar 0.8  # mais rigoroso

Sem --apagar, so reporta o que esta ruim (semelhanca abaixo do limiar) -- nada
e tocado no disco. Com --apagar, os mp3 ruins sao apagados: rode de novo o
gerar_biblia_at.py / gerar_biblia_nt.py / gerar_comentarios.py correspondente
(sem --limpar) para recriar so esses, aproveitando o mecanismo resumivel que
ja existe (skip-if-exists).

Nao mexe em nada no Storage -- roda sobre os mp3 ja gerados localmente, antes
do upload (gcloud storage rsync).

Requer: pip install faster-whisper

Codigos de saida: 0 = nada abaixo do limiar, 1 = ha mp3 ruim, 2 = erro de uso.
"""

import argparse
import json
import re
import sys
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DIR_BIBLIA = RAIZ / "assets" / "biblia"
DIR_COMENTARIOS = RAIZ / "assets" / "comentarios"

# Nome falado de cada livro -- a maioria vem do campo "nome"/"book" do JSON
# (ja acentuado certo); so os numerados precisam de forma por extenso, porque
# o TTS le "1" como "um", nao como "Primeiro"/"Primeira" (mesmo dicionario
# usado em audio_gen_*/_common.py -- ver nota no README de la).
NOME_FALADO = {
    "1samuel": "Primeiro Samuel",
    "2samuel": "Segundo Samuel",
    "1reis": "Primeiro Reis",
    "2reis": "Segundo Reis",
    "1cronicas": "Primeira Cronicas",
    "2cronicas": "Segunda Cronicas",
    "1corintios": "Primeira Corintios",
    "2corintios": "Segunda Corintios",
    "1tessalonicenses": "Primeira Tessalonicenses",
    "2tessalonicenses": "Segunda Tessalonicenses",
    "1timoteo": "Primeiro Timoteo",
    "2timoteo": "Segundo Timoteo",
    "1pedro": "Primeira Pedro",
    "2pedro": "Segunda Pedro",
    "1joao": "Primeira Joao",
    "2joao": "Segunda Joao",
    "3joao": "Terceira Joao",
}


def nome_falado_do_livro(slug: str, nome_do_json: str) -> str:
    return NOME_FALADO.get(slug, nome_do_json)


def _normalizar(texto: str) -> str:
    """Baixa caixa, remove acento e pontuacao -- compara palavras ditas, nao
    grafia exata (o Whisper nao pontua igual ao texto original)."""
    sem_acento = "".join(
        c
        for c in unicodedata.normalize("NFD", texto.lower())
        if unicodedata.category(c) != "Mn"
    )
    sem_pontuacao = re.sub(r"[^a-z0-9 ]", " ", sem_acento)
    return re.sub(r"\s+", " ", sem_pontuacao).strip()


def semelhanca(esperado: str, transcrito: str) -> float:
    return SequenceMatcher(None, _normalizar(esperado), _normalizar(transcrito)).ratio()


_MODELO = None


def transcrever(caminho_mp3: Path) -> str:
    global _MODELO
    if _MODELO is None:
        from faster_whisper import WhisperModel

        print("Carregando Whisper (CPU)...", file=sys.stderr)
        _MODELO = WhisperModel("small", device="cpu", compute_type="int8")
    segmentos, _ = _MODELO.transcribe(str(caminho_mp3), language="pt")
    return " ".join(s.text for s in segmentos)


def tarefas_biblia(slugs_filtro: set | None) -> list[tuple[str, str]]:
    """(caminho relativo dentro da pasta de saida, texto esperado)."""
    tarefas = []
    for caminho in sorted(DIR_BIBLIA.glob("*.json")):
        slug = caminho.stem
        if slugs_filtro and slug not in slugs_filtro:
            continue
        livro = json.loads(caminho.read_text(encoding="utf-8"))
        nome_falado = nome_falado_do_livro(slug, livro["nome"])
        for numero_str, capitulo in livro["capitulos"].items():
            versiculos = capitulo["versiculos"]
            unidades = [versiculos[v] for v in sorted(versiculos, key=int)]
            esperado = f"{nome_falado} Capitulo {numero_str}. " + " ".join(unidades)
            tarefas.append((f"{slug}/{numero_str}.mp3", esperado))
    return tarefas


def tarefas_comentarios(slugs_filtro: set | None) -> list[tuple[str, str]]:
    tarefas = []
    for caminho in sorted(DIR_COMENTARIOS.glob("*.json")):
        slug = caminho.stem
        if slugs_filtro and slug not in slugs_filtro:
            continue
        comentario = json.loads(caminho.read_text(encoding="utf-8"))
        nome_falado = nome_falado_do_livro(slug, comentario["book"])
        for capitulo_str, versiculos in comentario["capitulos"].items():
            for versiculo_str, texto in versiculos.items():
                esperado = (
                    f"Comentario de {nome_falado} Capitulo {capitulo_str} "
                    f"Versiculo {versiculo_str}. {texto}"
                )
                tarefas.append((f"{slug}/{capitulo_str}-{versiculo_str}.mp3", esperado))
    return tarefas


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("tipo", choices=["biblia", "comentarios"])
    parser.add_argument("slugs", nargs="*", help="Livros a validar (vazio = todos)")
    parser.add_argument(
        "--pasta", required=True, help="Pasta com os mp3 ja gerados (ex.: audio_gen_at/biblia)"
    )
    parser.add_argument("--limiar", type=float, default=0.75)
    parser.add_argument(
        "--apagar", action="store_true", help="Apaga os mp3 ruins (sem isso, so reporta)"
    )
    args = parser.parse_args()

    pasta = Path(args.pasta)
    if not pasta.is_dir():
        print(f"pasta nao encontrada: {pasta}")
        sys.exit(2)

    slugs_filtro = set(args.slugs) or None
    tarefas = (
        tarefas_biblia(slugs_filtro) if args.tipo == "biblia" else tarefas_comentarios(slugs_filtro)
    )
    existentes = [(rel, esperado) for rel, esperado in tarefas if (pasta / rel).exists()]
    print(f"{len(existentes)}/{len(tarefas)} mp3 ja gerados em {pasta}. Validando...")

    ruins = 0
    for relativo, esperado in existentes:
        caminho_mp3 = pasta / relativo
        transcrito = transcrever(caminho_mp3)
        pontuacao = semelhanca(esperado, transcrito)
        if pontuacao < args.limiar:
            ruins += 1
            print(f"RUIM  {relativo}  (semelhanca {pontuacao:.0%})")
            print(f"      esperado:   {esperado[:120]}")
            print(f"      transcrito: {transcrito[:120]}")
            if args.apagar:
                caminho_mp3.unlink()
        else:
            print(f"ok    {relativo}  (semelhanca {pontuacao:.0%})")

    print(f"\n{ruins}/{len(existentes)} arquivo(s) abaixo do limiar de {args.limiar:.0%}.")
    if ruins and args.apagar:
        print("Apagados -- rode o gerar_*.py correspondente de novo (sem --limpar) para recriar so esses.")
    elif ruins:
        print("Rode de novo com --apagar para apagar e poder regenerar.")
    sys.exit(1 if ruins else 0)


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    main()
