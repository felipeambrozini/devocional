"""Uso: python checar.py <nome_do_lote>   (ex.: 1reis_01)
Confere trabalho/saida/<nome>.json contra trabalho/lotes/<nome>.json.
Imprime cada problema como  cap:ver [TIPO] detalhe  e sai com 1 se houver algum."""
import collections, json, re, sys
from pathlib import Path
AQUI = Path(__file__).resolve().parent; S = AQUI / 'trabalho'; RAIZ = AQUI.parent.parent
sys.stdout.reconfigure(encoding="utf-8")
nome = sys.argv[1]
lote = json.load(open(S / 'lotes' / f'{nome}.json', encoding='utf-8'))
try:
    saida = json.load(open(S / 'saida' / f'{nome}.json', encoding='utf-8'))
except Exception as e:
    print('[JSON] saida ausente ou invalida:', e); sys.exit(1)
molde = set(json.load(open(AQUI / 'molde_chaves.json', encoding='utf-8')))
biblia = json.load(open(RAIZ / 'assets' / 'biblia' / f"{lote['slug']}.json", encoding='utf-8'))
todo_livro = ' '.join(v for c in biblia['capitulos'].values() for v in c['versiculos'].values())
def toks(s): return re.findall(r'\w+', s.lower())
def frases(t): return [f.split() for f in re.split(r'(?<=[.!?;:])\s+', t) if len(f.split()) >= 4]
erros = []
aberturas = collections.Counter(); fechos = collections.Counter()
for r in lote['versiculos']:
    ref = f"{r['cap']}:{r['ver']}"
    t = saida.get(r['cap'], {}).get(r['ver'])
    if not isinstance(t, str) or not t.strip():
        erros.append(f'{ref} [FALTA] comentario ausente'); continue
    n = len(t.split())
    if n < 40 or n > 130: erros.append(f'{ref} [TAMANHO] {n} palavras (40 a 120)')
    if re.search(r'\u2014|\u2015|\u2013|--| -|- ', t): erros.append(f'{ref} [TRAVESSAO] travessao, meia-risca ou hifen solto')
    if re.search(r'\b\w+ (lo|la|los|las)\b', t): erros.append(f'{ref} [HIFEN] enclise sem hifen (ex.: cumpri-la, recebe-las)')
    if '\n' in t or re.search(r'[*#_`]', t): erros.append(f'{ref} [FORMATO] quebra de linha ou markdown')
    if re.search(r'[\u0400-\u04ff\u3000-\u9fff]', t): erros.append(f'{ref} [CORRUPCAO] caractere estranho')
    for f in frases(t):
        for k in (('i', ' '.join(f[:4])), ('f', ' '.join(f[-5:]))):
            if '|'.join(k) in molde: erros.append(f"{ref} [MOLDE] frase do lote antigo: {' '.join(f)[:80]}")
        aberturas[' '.join(f[:3])] += 1; fechos[' '.join(f[-4:])] += 1
    vset = {w for w in toks(r['texto']) if len(w) > 3}; ct = [w for w in toks(t) if len(w) > 3]
    if sum(w in vset for w in ct) / max(1, len(ct)) > 0.40:
        erros.append(f'{ref} [PARAFRASE] repete demais as palavras do versiculo; comente, nao reescreva')
    primeira = [w for w in toks(re.split(r'(?<=[.!?])\s+', t)[0]) if len(w) > 3]
    if len(primeira) >= 8 and sum(w in vset for w in primeira) / len(primeira) > 0.75:
        erros.append(f'{ref} [RECITA] a primeira frase recita o versiculo; comece pelo que ele ensina')
    if toks(t)[:6] == toks(r['texto'])[:6]:
        erros.append(f'{ref} [PARAFRASE] comeca copiando o versiculo')
    for q in re.findall(r'"([^"]+)"|\u201c([^\u201d]+)\u201d', t):
        q = q[0] or q[1]
        if q.strip(' .,;:!?') not in todo_livro:
            erros.append(f'{ref} [CITACAO] "{q[:60]}" nao existe byte a byte em assets/biblia/{lote["slug"]}.json')
    if re.search(r'\b(autor|escritor) (de|aos|da carta aos) Hebreus', t):
        erros.append(f'{ref} [AUTORIA] Hebreus e de Paulo')
rotulos = [f"{r['cap']}:{r['ver']}" for r in lote['versiculos']
           if re.match(r'^[^.!?;:]{2,45}:\s', saida.get(r['cap'], {}).get(r['ver'], ''))]
if len(rotulos) > 0.35 * len(lote['versiculos']):
    erros.append(f'lote [MOLDE-ROTULO] {len(rotulos)} comentarios abrem com "rotulo: parafrase" '
                 f'(maximo 35%); reescreva a abertura destes, comecando pelo ensino: {" ".join(rotulos)}')
def fecho_com_tu(texto):
    ultima = re.split(r'(?<=[.!?])\s+', texto.strip())[-1]
    return bool(re.search(r'\b\w+ tu\b', ultima[:40]))
textos = {f"{r['cap']}:{r['ver']}": saida.get(r['cap'], {}).get(r['ver'], '') for r in lote['versiculos']}
fechos_tu = [ref for ref, t in textos.items() if t and fecho_com_tu(t)]
if len(fechos_tu) > 0.30 * len(textos):
    erros.append(f'lote [MOLDE-FECHO] {len(fechos_tu)} comentarios terminam em exortacao com "tu" (maximo 30%); '
                 f'feche estes com afirmacao, imagem ou pergunta: {" ".join(fechos_tu)}')
exclamativos = [ref for ref, t in textos.items() if t.startswith('Que ')]
if len(exclamativos) > 0.25 * len(textos):
    erros.append(f'lote [MOLDE-QUE] {len(exclamativos)} comentarios abrem com "Que ..." (maximo 25%); '
                 f'varie a abertura destes: {" ".join(exclamativos)}')
limite = max(4, len(lote["versiculos"]) // 12)
for k, n in aberturas.items():
    if n > limite: erros.append(f'lote [TIQUE] {n} frases comecam com "{k}" (maximo {limite})')
for k, n in fechos.items():
    if n > limite: erros.append(f'lote [TIQUE] {n} frases terminam com "{k}" (maximo {limite})')
extra = [f'{c}:{v}' for c, vs in saida.items() for v in vs if not any(r['cap'] == c and r['ver'] == v for r in lote['versiculos'])]
if extra: erros.append(f'lote [EXTRA] refs fora do lote: {extra[:5]}')
print('\n'.join(erros) if erros else f'OK {len(lote["versiculos"])} comentarios')
sys.exit(1 if erros else 0)
