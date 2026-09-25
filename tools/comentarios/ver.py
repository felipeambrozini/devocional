"""Uso: python ver.py <lote>  -> cada versiculo do lote seguido do comentario atual e sua contagem de palavras."""
import json, sys
from pathlib import Path
S = Path(__file__).resolve().parent / 'trabalho'; nome = sys.argv[1]
lote = json.load(open(S / 'lotes' / f'{nome}.json', encoding='utf-8'))
try: saida = json.load(open(S / 'saida' / f'{nome}.json', encoding='utf-8'))
except FileNotFoundError: saida = {}
sys.stdout.reconfigure(encoding='utf-8')
for v in lote['versiculos']:
    c = saida.get(v['cap'], {}).get(v['ver'], '')
    print(f"{v['cap']}:{v['ver']} | {v['texto']}\n  >> ({len(c.split())}) {c}\n")
