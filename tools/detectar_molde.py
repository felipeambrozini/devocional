#!/usr/bin/env python3
"""Detecta comentarios de molde em assets/comentarios/*.json.

Uma frase e de molde quando o seu inicio (4 palavras) ou o seu fim
(5 palavras) se repete em LIMIAR ou mais comentarios do corpus inteiro:
foi assim que o lote gerado por gabarito se revelou, frases fixas com uma
palavra solta encaixada ("Confia em X quando os numeros te assustarem").

Uso:
  python tools/detectar_molde.py            # contagem por livro
  python tools/detectar_molde.py --json     # {slug: [[cap, ver], ...]}
"""
import collections
import glob
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
LIMIAR = 25


def frases(texto):
    return [f.split() for f in re.split(r'(?<=[.!?;:])\s+', texto) if len(f.split()) >= 4]


def chaves(palavras):
    return ('i', ' '.join(palavras[:4])), ('f', ' '.join(palavras[-5:]))


def carregar():
    livros = {}
    for arq in sorted(glob.glob(str(RAIZ / 'assets' / 'comentarios' / '*.json'))):
        dados = json.load(open(arq, encoding='utf-8'))
        livros[dados['slug']] = dados['capitulos']
    return livros


def detectar(livros):
    contagem = collections.Counter()
    for caps in livros.values():
        for vs in caps.values():
            for texto in vs.values():
                contagem.update({k for f in frases(texto) for k in chaves(f)})
    alvo = {}
    for slug, caps in livros.items():
        refs = [[c, v] for c, vs in caps.items() for v, texto in vs.items()
                if any(contagem[k] >= LIMIAR for f in frases(texto) for k in chaves(f))]
        alvo[slug] = refs
    return alvo


if __name__ == '__main__':
    livros = carregar()
    alvo = detectar(livros)
    if '--json' in sys.argv:
        print(json.dumps(alvo, ensure_ascii=False))
    else:
        total = sum(len(vs) for caps in livros.values() for vs in caps.values())
        for slug, refs in alvo.items():
            n = sum(len(vs) for vs in livros[slug].values())
            print(f'{slug:18} {len(refs):5}/{n:5}')
        print('TOTAL', sum(map(len, alvo.values())), '/', total)
