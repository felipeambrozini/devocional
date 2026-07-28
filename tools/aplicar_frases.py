"""Injeta as frases verificadas nas introducoes.

    python tools/aplicar_frases.py

Le tools/frases_verificadas.json e grava frase, marcacao de comprovada e fonte em
assets/intro/<slug>.json. Livro sem frase verificada permanece com o campo vazio, e a
tela omite o bloco. Reexecutavel: sempre reflete o estado do arquivo de frases.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import canon

ROOT = Path(__file__).resolve().parent.parent
INTRO = ROOT / "assets" / "intro"
FRASES = Path(__file__).parent / "frases_verificadas.json"


def main() -> int:
    frases = json.loads(FRASES.read_text(encoding="utf-8"))
    frases = {k: v for k, v in frases.items() if not k.startswith("_")}

    desconhecidos = [k for k in frases if k not in canon.SLUGS]
    if desconhecidos:
        print(f"ERRO: slugs fora do canon em frases_verificadas.json: {desconhecidos}")
        return 1

    incompletas = [k for k, v in frases.items()
                   if not (v.get("frase") and v.get("fonte") and v.get("url"))]
    if incompletas:
        print(f"ERRO: frase sem fonte ou sem url: {incompletas}")
        return 1

    com, sem = [], []
    for slug in canon.SLUGS:
        caminho = INTRO / f"{slug}.json"
        if not caminho.is_file():
            continue
        dados = json.loads(caminho.read_text(encoding="utf-8"))
        entrada = frases.get(slug)
        if entrada:
            dados["quote"] = entrada["frase"]
            dados["quoteAttributed"] = True
            dados["quoteSource"] = entrada["fonte"]
            # Guardados para auditoria; o app nao os usa.
            dados["quoteOriginal"] = entrada.get("original", "")
            dados["quoteUrl"] = entrada["url"]
            com.append(slug)
        else:
            dados["quote"] = ""
            dados["quoteAttributed"] = False
            dados["quoteSource"] = ""
            dados.pop("quoteOriginal", None)
            dados.pop("quoteUrl", None)
            sem.append(slug)
        caminho.write_text(
            json.dumps(dados, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    escritas = len(com) + len(sem)
    print(f"{escritas} introducoes escritas | {len(com)} com frase verificada")
    print(f"  com frase: {', '.join(canon.NAMES[s] for s in com) or 'nenhuma'}")
    if sem:
        print(f"  sem frase ({len(sem)}): {', '.join(canon.NAMES[s] for s in sem)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
