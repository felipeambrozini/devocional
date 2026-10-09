"""Audita a traducao de um livro inteiro, alem do que checar_capitulo.py confere.

    python tools/biblioteca/auditar_livro.py somente_pela_graca [--detalhe]

Relatorio por livro:
  - problemas estruturais de cada capitulo (checar_capitulo.py);
  - trechos entre aspas que estao na BKJ mas nao foram registrados em "citacoes";
  - trechos entre aspas de 6+ palavras que NAO estao na BKJ: ou sao fala inventada
    do pregador, ou versiculo que o tradutor traduziu por conta propria (revisar);
  - paragrafos que perderam 2+ frases em relacao ao original;
  - suspeitas de portugues de Portugal (so aviso: o texto da BKJ tem essas formas).
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata

from checar_capitulo import BIBLIA, PASTA, problemas

LUSITANISMOS = re.compile(
    r"\b\w+-(?:te|lhe|lhes|se|o|a)\b|\ba certeza\b|\bfaze\b|\bvocês?\b|\b(?:está|estamos|estou) a \w+"
)
FIM_DE_FRASE = re.compile(r'(?<=[.!?:;])["”]?\s+(?=[A-ZÁÉÍÓÚÂÊÔÃÕÀÇ"“])')


def palavras(texto: str) -> list[str]:
    texto = unicodedata.normalize("NFC", texto).casefold()
    return re.sub(r"[^\w\s]", "", texto).split()


def indice_da_biblia() -> str:
    versiculos = []
    for arquivo in BIBLIA.glob("*.json"):
        livro = json.loads(arquivo.read_text(encoding="utf-8"))
        for capitulo in livro["capitulos"].values():
            versiculos += [" ".join(palavras(v)) for v in capitulo["versiculos"].values()]
    return "|" + "|".join(versiculos) + "|"


def quantidade_de_frases(texto: str) -> int:
    return len([f for f in FIM_DE_FRASE.split(texto) if len(f.split()) >= 3])


def auditar(slug: str, detalhe: bool) -> None:
    original = json.loads((PASTA / f"{slug}_en.json").read_text(encoding="utf-8"))["capitulos"]
    biblia = indice_da_biblia()
    for indice, capitulo in enumerate(original):
        traducao = json.loads(
            (PASTA / f"{slug}_pt" / f"{indice + 1:02d}.json").read_text(encoding="utf-8")
        )
        titulo = traducao["titulo"]
        registrados = [" ".join(palavras(c["trecho"])) for c in traducao["citacoes"]]
        sem_registro, fora_da_biblia, frases_perdidas = [], [], []
        for n, (en, pt) in enumerate(zip(capitulo["paragrafos"], traducao["paragrafos"])):
            if quantidade_de_frases(en) >= 4 and quantidade_de_frases(pt) <= quantidade_de_frases(en) - 2:
                frases_perdidas.append(n)
            for citado in re.findall(r'"([^"]+)"', pt):
                trecho = " ".join(palavras(citado))
                if len(trecho.split()) < 4:
                    continue
                if f" {trecho} " in biblia:
                    if not any(trecho in r or r in trecho for r in registrados):
                        sem_registro.append(f"p{n}: {citado}")
                elif len(trecho.split()) >= 6:
                    fora_da_biblia.append(f"p{n}: {citado[:110]}")
        estrutura = problemas(slug, indice)
        suspeitas = LUSITANISMOS.findall(" ".join(traducao["paragrafos"]))
        print(
            f"{indice:2} {titulo[:34]:34} estrutura={'OK' if not estrutura else estrutura} "
            f"sem_registro={len(sem_registro)} fora_da_biblia={len(fora_da_biblia)} "
            f"frases_perdidas={frases_perdidas} luso={len(suspeitas)}"
        )
        if detalhe:
            for linha in sem_registro + fora_da_biblia:
                print("     ", linha)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("slug")
    parser.add_argument("--detalhe", action="store_true")
    argumentos = parser.parse_args()
    auditar(argumentos.slug, argumentos.detalhe)
