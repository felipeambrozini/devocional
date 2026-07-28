"""Imprime versiculos da BKJ extraida, para citar nas introducoes sem errar o texto.

    python tools/versiculo.py "Exodo 3:14" "Levitico 17:11" "Josue 1:9"
"""

import json
import re
import sys
from pathlib import Path

import canon

ASSETS = Path(__file__).resolve().parent.parent / "assets" / "bible"
REF = re.compile(r"^(.+?)\s+(\d{1,3}):(\d{1,3})(?:-(\d{1,3}))?$")


def main() -> int:
    versao = "bkj"
    refs = sys.argv[1:]
    if not refs:
        print(__doc__)
        return 2
    for ref in refs:
        m = REF.match(ref.strip())
        if not m:
            print(f"  ?? {ref}")
            continue
        slug = canon.resolve(m.group(1))
        if not slug:
            print(f"  ?? livro desconhecido em {ref}")
            continue
        dados = json.loads((ASSETS / versao / f"{slug}.json").read_text(encoding="utf-8"))
        cap = dados["chapters"].get(m.group(2))
        if not cap:
            print(f"  ?? capitulo inexistente em {ref}")
            continue
        inicio, fim = int(m.group(3)), int(m.group(4) or m.group(3))
        partes = [cap["verses"].get(str(v), "") for v in range(inicio, fim + 1)]
        texto = " ".join(p for p in partes if p)
        nome = canon.NAMES[slug]
        alvo = f"{nome} {m.group(2)}:{m.group(3)}" + (f"-{fim}" if fim != inicio else "")
        print(f"{alvo}\n  {texto}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
