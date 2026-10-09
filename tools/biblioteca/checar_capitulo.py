"""Confere a traducao de um capitulo contra o original e contra a BKJ do app.

    python tools/biblioteca/checar_capitulo.py somente_pela_graca 1

O segundo argumento e o indice do capitulo em <slug>_en.json, contado a partir de 0;
a traducao e lida de <slug>_pt/NN.json, com NN = indice + 1 em dois digitos.

Cada item de "citacoes" ({"ref": "isaias 1:18", "trecho": "..."}) precisa ser um
trecho literal do versiculo da BKJ e aparecer literalmente no texto traduzido.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PASTA = Path(__file__).parent
BIBLIA = PASTA.parent.parent / "assets" / "biblia"
# Paragrafo que so o --montar preenche com a BKJ: "[[salmos 119:17]]" (um versiculo,
# com numero) ou "[[salmos 119:17-24]]" (um trecho). O tradutor copia sem mexer.
MARCADOR = re.compile(r"^\[\[(\w+ \d+):(\d+)(?:-(\d+))?\]\]$")
PROIBIDOS = re.compile("[—–‘’“”]|--")


def versiculo_bkj(ref: str) -> str:
    livro, _, resto = ref.rpartition(" ")
    capitulo, versiculo = resto.split(":")
    dados = json.loads((BIBLIA / f"{livro}.json").read_text(encoding="utf-8"))
    return dados["capitulos"][capitulo]["versiculos"][versiculo]


def problemas(slug: str, indice: int) -> list[str]:
    original = json.loads((PASTA / f"{slug}_en.json").read_text(encoding="utf-8"))
    original = original["capitulos"][indice]
    caminho = PASTA / f"{slug}_pt" / f"{indice + 1:02d}.json"
    traducao = json.loads(caminho.read_text(encoding="utf-8"))
    texto = " ".join(traducao["paragrafos"])
    achados = []

    if len(traducao["paragrafos"]) != len(original["paragrafos"]):
        achados.append(
            f"paragrafos: {len(traducao['paragrafos'])} no pt, "
            f"{len(original['paragrafos'])} no original"
        )
    for n, (em_ingles, em_portugues) in enumerate(
        zip(original["paragrafos"], traducao["paragrafos"])
    ):
        if MARCADOR.match(em_ingles) and em_portugues != em_ingles:
            achados.append(f"paragrafo {n}: o marcador {em_ingles} foi alterado")
    if PROIBIDOS.search(texto + traducao["titulo"]):
        achados.append("travessao ou aspa curva no texto")
    for citacao in traducao.get("citacoes", []):
        try:
            verso = versiculo_bkj(citacao["ref"])
        except (OSError, KeyError, ValueError):
            achados.append(f"referencia nao resolve na BKJ: {citacao['ref']}")
            continue
        if citacao["trecho"].casefold() not in verso.casefold():
            achados.append(f"trecho nao e da BKJ ({citacao['ref']}): {citacao['trecho']}")
        if citacao["trecho"].casefold() not in texto.casefold():
            achados.append(f"trecho ausente do texto: {citacao['trecho']}")
    return achados


if __name__ == "__main__":
    achados = problemas(sys.argv[1], int(sys.argv[2]))
    print("\n".join(achados) if achados else "OK")
    sys.exit(1 if achados else 0)
