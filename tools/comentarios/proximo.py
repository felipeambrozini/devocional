"""Acha a próxima unidade sem comentário completo e prepara os lotes dela.

Uso: python tools/comentarios/proximo.py

Percorre o canon (lib/dados/canon.dart) em ordem e compara cada versículo de
assets/biblia/<slug>.json com assets/comentarios/<slug>.json. A primeira
unidade com versículo faltando vira lotes de ~90 versículos em
trabalho/lotes/, e a linha impressa é o JSON com os argumentos do workflow
comentarios-livro. Salmos anda pelos cinco livros do saltério, um por vez.
Sem nada faltando, imprime FIM.
"""
import json
import re
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent.parent
LOTES = AQUI / 'trabalho' / 'lotes'
TAMANHO_LOTE = 90
LIVROS_DOS_SALMOS = [('I', 1, 41), ('II', 42, 72), ('III', 73, 89), ('IV', 90, 106), ('V', 107, 150)]


def canon():
    fonte = (RAIZ / 'lib' / 'dados' / 'canon.dart').read_text(encoding='utf-8')
    return re.findall(r"Livro\(\s*'([a-z0-9]+)'", fonte)


def carregar(caminho):
    return json.loads(caminho.read_text(encoding='utf-8')) if caminho.exists() else None


def unidades(slug):
    """(nome da unidade, faixa de capítulos) em que o livro é commitado."""
    if slug == 'salmos':
        return [(f'salmos-{n}', range(a, b + 1)) for n, a, b in LIVROS_DOS_SALMOS]
    return [(slug, None)]


def faltando(biblia, comentarios, faixa):
    feitos = (comentarios or {}).get('capitulos', {})
    return [
        {'cap': c, 'ver': v, 'texto': t}
        for c in sorted(biblia['capitulos'], key=int)
        if faixa is None or int(c) in faixa
        for v, t in sorted(biblia['capitulos'][c]['versiculos'].items(), key=lambda kv: int(kv[0]))
        if v not in feitos.get(c, {})
    ]


def gerar_lotes(unidade, slug, book, versiculos):
    LOTES.mkdir(parents=True, exist_ok=True)
    for antigo in LOTES.glob(f'{unidade}_*.json'):
        antigo.unlink()
    nomes = []
    for i in range(0, len(versiculos), TAMANHO_LOTE):
        nome = f'{unidade}_{i // TAMANHO_LOTE + 1:02d}'
        dados = {'slug': slug, 'book': book, 'versiculos': versiculos[i:i + TAMANHO_LOTE]}
        (LOTES / f'{nome}.json').write_text(json.dumps(dados, ensure_ascii=False, indent=1), encoding='utf-8')
        nomes.append(nome)
    return nomes


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    for slug in canon():
        biblia = carregar(RAIZ / 'assets' / 'biblia' / f'{slug}.json')
        comentarios = carregar(RAIZ / 'assets' / 'comentarios' / f'{slug}.json')
        book = (comentarios or {}).get('book') or biblia['nome']
        for unidade, faixa in unidades(slug):
            versiculos = faltando(biblia, comentarios, faixa)
            if not versiculos:
                continue
            titulo = f'Comentários {book}'
            if faixa is not None:
                titulo += f' (Livro {unidade.split("-")[1]})'
            nomes = gerar_lotes(unidade, slug, book, versiculos)
            print(json.dumps({'unidade': unidade, 'slug': slug, 'titulo_commit': titulo,
                              'versiculos': len(versiculos), 'escrever': nomes}, ensure_ascii=False))
            return
    print('FIM')


if __name__ == '__main__':
    main()
