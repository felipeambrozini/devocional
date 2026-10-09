"""Extrai um livro de Spurgeon (dominio publico) do texto do CCEL para JSON em ingles.

    python tools/biblioteca/livro.py --extrair somente_pela_graca CAMINHO/somente_pela_graca.txt --capa 2
    python tools/biblioteca/livro.py --montar somente_pela_graca

Produz tools/biblioteca/<slug>_en.json com capitulos[{titulo, paragrafos[]}]. A
traducao fica em tools/biblioteca/<slug>_pt/NN.json (um arquivo por capitulo, mesma
quantidade de paragrafos que o ingles) e e feita fora deste script.
--montar confere cada capitulo (checar_capitulo.py) e junta os arquivos em
assets/livros/<slug>.json, o que o app le. As citacoes servem so a conferencia e
nao vao para o asset.

O texto do CCEL separa capitulos por uma linha de sublinhados, traz o titulo em
maiusculas na linha seguinte e separa paragrafos por linha em branco.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from checar_capitulo import MARCADOR, problemas, versiculo_bkj

PASTA = Path(__file__).parent
DESTINO = PASTA.parent.parent / "assets" / "livros"
SEPARADOR = re.compile(r"^\s*_{20,}\s*$", re.M)
RODAPE_CCEL = "This document is from the Christian Classics Ethereal"


def extrair_capitulos(texto: str, blocos_de_capa: int) -> list[dict]:
    blocos = SEPARADOR.split(texto)[1 + blocos_de_capa :]  # [0] e o cabecalho de catalogo
    capitulos = []
    for bloco in blocos:
        bloco = bloco.split(RODAPE_CCEL)[0].strip()
        if not bloco:
            continue
        titulo, _, corpo = bloco.partition("\n")
        paragrafos = [
            " ".join(p.split()) for p in re.split(r"\n\s*\n", corpo) if p.strip()
        ]
        capitulos.append({"titulo": titulo.strip(), "paragrafos": paragrafos})
    return capitulos


# A BKJ do Salmo 119 traz, no fim do ultimo versiculo de cada oitava, o nome da
# proxima letra hebraica ("... de todo. BETH."). Dentro de um livro isso aparece
# no meio do texto, entao sai na expansao.
LETRAS_HEBRAICAS = {
    "BETH", "GIMEL", "DALETH", "HE", "VAU", "ZAIN", "CHETH", "TETH", "JOD", "CAPH",
    "LAMED", "MEM", "NUN", "SAMECH", "AIN", "PE", "TZADDI", "KOPH", "RESH", "SCHIN", "TAU",
}


def versiculo_sem_letra(ref: str) -> str:
    texto = versiculo_bkj(ref)
    corpo, _, ultima = texto.rpartition(" ")
    return corpo if ultima.removesuffix(".") in LETRAS_HEBRAICAS else texto


def expandir(paragrafo: str) -> str:
    """Troca um marcador de versiculo pelo texto da BKJ; outro paragrafo passa direto."""
    achado = MARCADOR.match(paragrafo)
    if not achado:
        return paragrafo
    livro_e_capitulo, primeiro, ultimo = achado[1], int(achado[2]), achado[3]
    if ultimo is None:
        return f"{primeiro}. {versiculo_sem_letra(f'{livro_e_capitulo}:{primeiro}')}"
    return " ".join(
        f"{n} {versiculo_sem_letra(f'{livro_e_capitulo}:{n}')}"
        for n in range(primeiro, int(ultimo) + 1)
    )


def montar(slug: str) -> None:
    original = json.loads((PASTA / f"{slug}_en.json").read_text(encoding="utf-8"))
    capitulos, falhas = [], []
    for indice in range(len(original["capitulos"])):
        arquivo = PASTA / f"{slug}_pt" / f"{indice + 1:02d}.json"
        if not arquivo.exists():
            falhas.append(f"capitulo {indice}: falta {arquivo.name}")
            continue
        falhas += [f"capitulo {indice}: {p}" for p in problemas(slug, indice)]
        traducao = json.loads(arquivo.read_text(encoding="utf-8"))
        capitulos.append({
            "titulo": traducao["titulo"],
            "paragrafos": [expandir(p) for p in traducao["paragrafos"]],
        })
    if falhas:
        raise SystemExit(chr(10).join(falhas))
    DESTINO.mkdir(parents=True, exist_ok=True)
    destino = DESTINO / f"{slug}.json"
    destino.write_text(
        json.dumps({"slug": slug, "capitulos": capitulos}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"{len(capitulos)} capitulos -> {destino}")


def main() -> None:
    parser = argparse.ArgumentParser()
    grupo = parser.add_mutually_exclusive_group(required=True)
    grupo.add_argument("--extrair", nargs=2, metavar=("SLUG", "TXT"))
    grupo.add_argument("--montar", metavar="SLUG")
    parser.add_argument("--capa", type=int, default=2, help="blocos de capa a pular")
    args = parser.parse_args()
    if args.montar:
        return montar(args.montar)
    slug, caminho = args.extrair
    capitulos = extrair_capitulos(Path(caminho).read_text(encoding="utf-8"), args.capa)
    destino = PASTA / f"{slug}_en.json"
    destino.write_text(
        json.dumps({"slug": slug, "capitulos": capitulos}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    palavras = sum(len(p.split()) for c in capitulos for p in c["paragrafos"])
    print(f"{len(capitulos)} capitulos, {palavras} palavras -> {destino}")
    for i, c in enumerate(capitulos, 1):
        print(f"{i:2} {c['titulo']} ({len(c['paragrafos'])} paragrafos)")


if __name__ == "__main__":
    main()
