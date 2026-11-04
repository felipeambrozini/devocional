#!/usr/bin/env python3
"""Mostra os versiculos de um livro com a letra vermelha entre <<  >>, para revisar.

    python tools/falas_divinas/mostrar.py <slug> [capitulo]   todos os versiculos com fala
    python tools/falas_divinas/mostrar.py <slug> --parciais   so os de vermelho parcial
    python tools/falas_divinas/mostrar.py <slug> --formulas   so os SEM vermelho que
                                                              trazem "diz o SENHOR", "Jesus disse" etc.
    python tools/falas_divinas/mostrar.py <slug> --lacunas    so os SEM vermelho entre dois COM vermelho
                                                              (fala de Deus que pode ter ficado sem marca)
"""

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
FORMULAS = re.compile(
    r'(diz|disse|dizia|falou|fala|responde|respondeu|clama|clamou)\s+(o\s+)?'
    r'(SENHOR|Senhor|Deus|Jesus|Espírito)|(SENHOR|Senhor|Deus|Jesus)\s+(diz|disse|falou|respondeu)',
)


def u16(texto, i):
    return len(texto[:i].encode('utf-16-le')) // 2


def marcado(texto, trechos):
    """Texto com << >> nos trechos, que vem em indices UTF-16."""
    pontos = {}
    for a, b in trechos:
        pontos[a], pontos[b] = pontos.get(a, '') + '<<', pontos.get(b, '') + '>>'
    saida, k = [], 0
    for i, ch in enumerate(texto):
        saida.append(pontos.get(k, '') + ch)
        k += 2 if ord(ch) > 0xFFFF else 1
    saida.append(pontos.get(k, ''))
    return ''.join(saida)


def main(slug, opcao=None):
    sys.stdout.reconfigure(encoding='utf-8')
    falas = json.loads((RAIZ / f'assets/falas_divinas/{slug}.json').read_text(encoding='utf-8'))
    caps = json.loads((RAIZ / f'assets/biblia/{slug}.json').read_text(encoding='utf-8'))['capitulos']
    for cap in sorted(caps, key=int):
        if opcao and opcao.isdigit() and cap != opcao:
            continue
        com_fala = {int(v) for v in falas.get(cap, {})}
        for vers in sorted(caps[cap]['versiculos'], key=int):
            texto = caps[cap]['versiculos'][vers]
            trechos = falas.get(cap, {}).get(vers)
            if opcao == '--lacunas':
                if trechos or not {int(vers) - 1, int(vers) + 1} <= com_fala:
                    continue
            elif opcao == '--formulas':
                if trechos or not FORMULAS.search(texto):
                    continue
            elif not trechos:
                continue
            elif opcao == '--parciais' and trechos == [[0, len(texto)]]:
                continue
            print(f'{slug} {cap}:{vers}  {marcado(texto, trechos or [])}')


if __name__ == '__main__':
    main(*sys.argv[1:3])
