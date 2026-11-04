#!/usr/bin/env python3
"""Aplica as correcoes manuais da letra vermelha por cima de assets/falas_divinas.

O gerar.py corta a fala dentro do versiculo pela pontuacao e erra em dialogos
(a fala de um homem pintada de vermelho, a pergunta de Deus em preto). Cada
correcao mora em tools/falas_divinas/correcoes/<slug>.json:

    {"<cap>": {"<vers>": ["trecho divino 1", "trecho divino 2"]}}

Os trechos sao texto literal do versiculo de assets/biblia/<slug>.json, na ordem
em que aparecem; o que nao esta em nenhum trecho fica em preto. Lista vazia tira
o vermelho do versiculo inteiro. Cada trecho tem de aparecer uma so vez depois do
anterior (se repetir, alongue com palavras vizinhas), para a correcao nao pintar
o lugar errado.

Uso:  python tools/falas_divinas/aplicar_correcoes.py [slug ...]

Tambem roda no fim do gerar.py, para uma regeneracao nao desfazer a revisao.
test/falas_divinas_test.dart confere que os assets batem com as correcoes.
"""

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
CORRECOES = Path(__file__).resolve().parent / 'correcoes'
FALAS = RAIZ / 'assets/falas_divinas'
BIBLIA = RAIZ / 'assets/biblia'


def utf16(texto, i):
    return len(texto[:i].encode('utf-16-le')) // 2


def intervalos(texto, trechos, onde):
    """Indices UTF-16 [inicio, fim) de cada trecho, em ordem, sem ambiguidade."""
    saida, posicao = [], 0
    for trecho in trechos:
        if not trecho.strip():
            sys.exit(f'{onde}: trecho vazio')
        inicio = texto.find(trecho, posicao)
        if inicio < 0:
            sys.exit(f'{onde}: trecho fora do versiculo ou fora de ordem: {trecho!r}\n  {texto}')
        if texto.find(trecho, inicio + 1) >= 0:
            sys.exit(f'{onde}: trecho repetido no versiculo, alongue com palavras vizinhas: {trecho!r}')
        saida.append([utf16(texto, inicio), utf16(texto, inicio + len(trecho))])
        posicao = inicio + len(trecho)
    return saida


def aplicar(slugs=None):
    arquivos = sorted(CORRECOES.glob('*.json')) if CORRECOES.exists() else []
    for arquivo in arquivos:
        slug = arquivo.stem
        if slugs and slug not in slugs:
            continue
        correcoes = json.loads(arquivo.read_text(encoding='utf-8'))
        textos = json.loads((BIBLIA / f'{slug}.json').read_text(encoding='utf-8'))['capitulos']
        falas = json.loads((FALAS / f'{slug}.json').read_text(encoding='utf-8'))
        for cap, versiculos in correcoes.items():
            for vers, trechos in versiculos.items():
                onde = f'{slug} {cap}:{vers}'
                texto = textos.get(cap, {}).get('versiculos', {}).get(vers)
                if texto is None:
                    sys.exit(f'{onde}: versiculo inexistente')
                if trechos:
                    falas.setdefault(cap, {})[vers] = intervalos(texto, trechos, onde)
                else:
                    falas.get(cap, {}).pop(vers, None)
                    if cap in falas and not falas[cap]:
                        del falas[cap]
        ordenado = {c: dict(sorted(v.items(), key=lambda kv: int(kv[0])))
                    for c, v in sorted(falas.items(), key=lambda kv: int(kv[0]))}
        (FALAS / f'{slug}.json').write_text(
            json.dumps(ordenado, ensure_ascii=False, separators=(',', ':')) + '\n',
            encoding='utf-8')
        print(f'{slug}: {sum(len(v) for v in correcoes.values())} versiculo(s) corrigido(s)')


if __name__ == '__main__':
    aplicar(set(sys.argv[1:]) or None)
