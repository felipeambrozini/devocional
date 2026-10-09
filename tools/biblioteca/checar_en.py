"""Confere o texto em ingles extraido de um livro, antes de traduzir.

    python tools/biblioteca/checar_en.py <slug>

Le tools/biblioteca/<slug>_en.json ({slug, capitulos: [{titulo, paragrafos}]}) e
acusa o que costuma sair errado numa extracao: capitulo sem texto, HTML ou entidade
sobrando, numero de pagina solto, titulo de secao colado como paragrafo,
paragrafo repetido, espaco duplo. Imprime "OK" so sem erro; "AVISO" pede olhar.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PASTA = Path(__file__).parent
MARCADOR = re.compile(r"^\[\[\w+ \d+:\d+(?:-\d+)?\]\]$")
HTML = re.compile(r"<[^>]+>|&[a-z]+;|&#\d+;")
NUMERO_DE_PAGINA = re.compile(r"^\[?\s*(?:page\s*)?\d{1,4}\s*\]?$", re.I)


def conferir(slug: str) -> tuple[list[str], list[str]]:
    dados = json.loads((PASTA / f"{slug}_en.json").read_text(encoding="utf-8"))
    erros, avisos = [], []
    if dados.get("slug") != slug:
        erros.append(f'"slug" do arquivo e {dados.get("slug")!r}, esperava {slug!r}')
    vistos: dict[str, tuple[int, int]] = {}
    for i, capitulo in enumerate(dados["capitulos"]):
        onde = f"capitulo {i} ({capitulo['titulo'][:40]})"
        if not capitulo["titulo"].strip():
            erros.append(f"{onde}: titulo vazio")
        if not capitulo["paragrafos"]:
            erros.append(f"{onde}: sem paragrafos")
        for n, p in enumerate(capitulo["paragrafos"]):
            local = f"{onde}, p{n}"
            if not p.strip():
                erros.append(f"{local}: paragrafo vazio")
            elif p != p.strip() or "  " in p:
                erros.append(f"{local}: espaco sobrando (junte as linhas com um espaco so)")
            if HTML.search(p):
                erros.append(f"{local}: sobrou HTML ou entidade: {HTML.search(p).group(0)}")
            if NUMERO_DE_PAGINA.match(p):
                erros.append(f"{local}: parece numero de pagina: {p!r}")
            if MARCADOR.match(p):
                continue
            if len(p.split()) <= 3 and p.isupper():
                avisos.append(f"{local}: titulo de secao virou paragrafo? {p!r}")
            if len(p.split()) >= 12 and p in vistos:
                avisos.append(f"{local}: repete {vistos[p]}")
            vistos.setdefault(p, (i, n))
    return erros, avisos


if __name__ == "__main__":
    slug = sys.argv[1]
    erros, avisos = conferir(slug)
    dados = json.loads((PASTA / f"{slug}_en.json").read_text(encoding="utf-8"))
    palavras = sum(len(p.split()) for c in dados["capitulos"] for p in c["paragrafos"])
    print(f"{len(dados['capitulos'])} capitulos, {palavras} palavras")
    for linha in avisos[:30]:
        print("AVISO:", linha)
    for linha in erros[:30]:
        print("ERRO:", linha)
    print("OK" if not erros else f"{len(erros)} erro(s)")
    sys.exit(1 if erros else 0)
