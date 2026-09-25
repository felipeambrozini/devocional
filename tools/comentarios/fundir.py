"""Funde lotes validados em assets/comentarios/<slug>.json.

Uso: python tools/comentarios/fundir.py <lote> [<lote> ...]

Só funde o lote que passa no checar.py E tem o marcador
trabalho/validado/<lote>.ok, gravado pelo Opus ao fim da validação. Sem o
marcador, o lote pode ser texto do Sonnet que ninguém revisou (o validador
caiu no meio), e isso não pode chegar ao app. Sai com 1 se algum lote ficou
de fora.
"""
import json
import subprocess
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent.parent
TRABALHO = AQUI / 'trabalho'


def pronto(nome):
    if not (TRABALHO / 'validado' / f'{nome}.ok').exists():
        return False
    return subprocess.run([sys.executable, str(AQUI / 'checar.py'), nome], capture_output=True).returncode == 0


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    nomes = sys.argv[1:]
    pendentes = [n for n in nomes if not pronto(n)]
    por_livro, nomes_dos_livros = {}, {}
    for nome in nomes:
        if nome in pendentes:
            continue
        lote = json.loads((TRABALHO / 'lotes' / f'{nome}.json').read_text(encoding='utf-8'))
        slug = lote['slug']
        nomes_dos_livros[slug] = lote['book']
        saida = json.loads((TRABALHO / 'saida' / f'{nome}.json').read_text(encoding='utf-8'))
        for cap, versiculos in saida.items():
            por_livro.setdefault(slug, {}).setdefault(cap, {}).update(versiculos)
    for slug, capitulos in por_livro.items():
        arquivo = RAIZ / 'assets' / 'comentarios' / f'{slug}.json'
        dados = (json.loads(arquivo.read_text(encoding='utf-8')) if arquivo.exists()
                 else {'slug': slug, 'book': nomes_dos_livros[slug], 'capitulos': {}})
        for cap, versiculos in capitulos.items():
            dados['capitulos'].setdefault(cap, {}).update(versiculos)
        dados['capitulos'] = {
            c: dict(sorted(vs.items(), key=lambda kv: int(kv[0])))
            for c, vs in sorted(dados['capitulos'].items(), key=lambda kv: int(kv[0]))
        }
        with open(arquivo, 'w', encoding='utf-8', newline='\n') as f:
            f.write(json.dumps(dados, ensure_ascii=False, indent=2) + '\n')
    print(f'fundidos {len(nomes) - len(pendentes)} lotes; pendentes (sem .ok ou reprovados): {pendentes}')
    sys.exit(1 if pendentes else 0)


if __name__ == '__main__':
    main()
