"""Extrai The Golden Alphabet (Spurgeon, 1883, exposicao do Salmo 119) para JSON em ingles.

    python tools/biblioteca/alfabeto_de_ouro.py CAMINHO/golden_alphabet.htm

A fonte e a pagina do GraceGems (HTML, windows-1252, um <p> por paragrafo). Gera
tools/biblioteca/alfabeto_de_ouro_en.json com um capitulo para o prefacio e um por
letra hebraica (22), no mesmo formato de livro.py --extrair.

Os versiculos do Salmo 119 NAO entram como texto: viram marcadores `[[salmos 119:17]]`
(um versiculo, com numero) e `[[salmos 119:17-24]]` (o trecho da secao), que o
`livro.py --montar` troca pelo texto da BKJ do app. O tradutor so copia o marcador.
"""

from __future__ import annotations

import html
import json
import re
import sys
from pathlib import Path

DESTINO = Path(__file__).parent / "alfabeto_de_ouro_en.json"
LETRAS = [
    "Aleph", "Beth", "Gimel", "Daleth", "He", "Vav", "Zayin", "Cheth", "Teth", "Yod",
    "Kaph", "Lamed", "Mem", "Nun", "Samech", "Ayin", "Pe", "Tzaddi", "Koph", "Resh",
    "Shin", "Tau",
]
SECAO = re.compile(r"^Exposition of Verses (\d+) to (\d+)$")
VERSICULO = re.compile(r"^(\d{1,3})\.\s")


def paragrafos_do_html(caminho: str) -> list[str]:
    bruto = Path(caminho).read_bytes().decode("cp1252", errors="replace")
    textos = [
        " ".join(html.unescape(re.sub(r"<[^>]+>", "", p)).split())
        for p in re.findall(r"<p\b[^>]*>(.*?)</p>", bruto, flags=re.S | re.I)
    ]
    return [t for t in textos if t]


def montar_capitulos(paragrafos: list[str]) -> list[dict]:
    # O titulo do prefacio vem colado ao primeiro paragrafo no HTML.
    inicio = next(i for i, t in enumerate(paragrafos) if t.startswith("PREFATORY WORD"))
    corpo = [paragrafos[inicio].removeprefix("PREFATORY WORD").strip(), *paragrafos[inicio + 1 :]]
    capitulos = [{"titulo": "Prefatory Word", "paragrafos": []}]
    esperado = fim = pulando = 0
    for texto in corpo:
        secao = SECAO.match(texto)
        if secao:
            primeiro, ultimo = int(secao[1]), int(secao[2])
            letra = LETRAS[len(capitulos) - 1]
            capitulos.append({
                "titulo": f"{letra} (Verses {primeiro} to {ultimo})",
                "paragrafos": [f"[[salmos 119:{primeiro}-{ultimo}]]"],
            })
            esperado, fim, pulando = primeiro, ultimo, ultimo - primeiro + 1
            continue
        corrente = capitulos[-1]["paragrafos"]
        if len(capitulos) > 1 and pulando > 0:
            pulando -= 1  # as linhas do salmo da secao: ja estao no marcador do trecho
            continue
        if len(capitulos) > 1 and esperado <= fim and texto.startswith(f"{esperado}. "):
            corrente.append(f"[[salmos 119:{esperado}]]")
            esperado += 1
            continue
        corrente.append(texto)
    return capitulos


def conferir(capitulos: list[dict]) -> list[str]:
    avisos = []
    if len(capitulos) != 23:
        avisos.append(f"esperava 23 capitulos, saiu {len(capitulos)}")
    versiculos = [
        p for c in capitulos for p in c["paragrafos"] if re.fullmatch(r"\[\[salmos 119:\d+\]\]", p)
    ]
    if len(versiculos) != 176:
        avisos.append(f"esperava 176 versiculos comentados, saiu {len(versiculos)}")
    return avisos


if __name__ == "__main__":
    capitulos = montar_capitulos(paragrafos_do_html(sys.argv[1]))
    DESTINO.write_text(
        json.dumps({"slug": "alfabeto_de_ouro", "capitulos": capitulos}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    palavras = sum(len(p.split()) for c in capitulos for p in c["paragrafos"])
    print(f"{len(capitulos)} capitulos, {palavras} palavras -> {DESTINO}")
    for i, c in enumerate(capitulos):
        print(f"{i:2} {c['titulo']} ({len(c['paragrafos'])} paragrafos)")
    for aviso in conferir(capitulos):
        print("AVISO:", aviso)
