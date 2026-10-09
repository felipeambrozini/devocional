"""Uso: python checar_intro.py <slug>   (ex.: genesis)
Confere assets/introducoes/<slug>.json: citações bíblicas byte a byte na BKJ,
pontuação, hífen, vocabulário, primeira pessoa na seção 4 e formato da fonte da frase.
Imprime cada problema como  [TIPO] detalhe  e sai com 1 se houver algum."""
import json, re, sys
from pathlib import Path
RAIZ = Path(__file__).resolve().parent.parent.parent
sys.stdout.reconfigure(encoding='utf-8')
slug = sys.argv[1]
intro = json.load(open(RAIZ / 'assets' / 'introducoes' / f'{slug}.json', encoding='utf-8'))
canon = re.findall(r"Livro\(\s*'([a-z0-9]+)',\s*'([^']+)'", (RAIZ / 'lib' / 'dados' / 'canon.dart').read_text(encoding='utf-8'))
slug_por_nome = {nome: s for s, nome in canon}
slug_por_nome.update({'Salmo': 'salmos', 'Cantares de Salomão': 'cantares', 'Cânticos': 'cantares'})
biblias = {}

def versiculos(nome, cap, ini, fim):
    s = slug_por_nome.get(nome)
    if not s: return None
    if s not in biblias: biblias[s] = json.load(open(RAIZ / 'assets' / 'biblia' / f'{s}.json', encoding='utf-8'))
    vs = biblias[s]['capitulos'].get(cap, {}).get('versiculos', {})
    return ' '.join(vs.get(str(v), '') for v in range(int(ini), int(fim or ini) + 1))

erros = []
secoes = intro['sections']
for i, sec in enumerate(secoes):
    t, nome_sec = sec['body'], sec['heading']
    for q, livro, cap, ini, fim in re.findall(
            r'["“]([^"”]+)["”]\s*\(([1-3]?\s?[A-ZÀ-Ú][^\d()]*?) (\d+):(\d+)(?:-(\d+))?\)', t):
        texto = versiculos(livro.strip(), cap, ini, fim)
        if texto is None:
            erros.append(f'[REFERENCIA] {nome_sec}: livro "{livro}" não reconhecido')
        elif q.strip(' .,;:!?') not in texto:
            erros.append(f'[CITACAO] {nome_sec}: "{q[:60]}" não é byte a byte {livro} {cap}:{ini}')
    if re.search(r'—|―|–|--| -|- ', t): erros.append(f'[TRAVESSAO] {nome_sec}')
    for m in re.finditer(r'\b\w+ (lo|la|los|las)\b|\brecém [a-zà-ú]+|\b(note|veja|dá|diga|lembra) (se|me|te|nos)\b', t):
        erros.append(f'[HIFEN] {nome_sec}: "{m.group(0)}"')
    m = re.search(r'\b(rez(a|am|ar|ava|ou|e)|voc[êe]s?|regista\w*|marketing|equipe|agenda|vitrine|investiment\w*|'
                  r'holofotes?|curr[íi]culo|log[ií]stica|dieta|laborat[óo]rio|vira o jogo|paga a conta)\b', t, re.I)
    if m: erros.append(f'[PALAVRA] {nome_sec}: "{m.group(0)}" é moderna ou alheia à voz de Spurgeon')
    if i == 3 and re.search(r'\bSpurgeon (cria|achava|pregou|dizia|escreveu|amava|viu|leu)|\bo pregador (achava|cria)', t):
        erros.append('[PESSOA] a seção 4 fala de Spurgeon na terceira pessoa')
fonte = intro.get('quoteSource', '').strip()
if intro.get('quoteAttributed'):
    if not fonte: erros.append('[FRASE] quoteAttributed sem quoteSource')
    if not intro.get('quoteOriginal', '').strip() or not intro.get('quoteUrl', '').strip():
        erros.append('[FRASE] frase atribuída sem quoteOriginal (texto em inglês) e quoteUrl (onde foi conferida)')
    if re.search(r'\b(The|the|of|and|Sermon|Morning and Evening)\b', fonte):
        erros.append(f'[FONTE] "{fonte}" tem título em inglês; traduza (sermão: "Sermão N: Título traduzido"; obra: "O Tesouro de Davi, Salmo 4")')
    if 'Sermão' in fonte and not re.match(r'Sermão \d+: \S', fonte):
        erros.append(f'[FONTE] "{fonte}" fora do formato "Sermão N: Título traduzido"')
for i, sec in enumerate(secoes):
    for m in re.finditer(r'\bSermão (?!\d+: |do Monte)', sec['body']):
        erros.append(f'[FONTE] {sec["heading"]}: sermão citado fora do formato "Sermão N: Título traduzido"')
        break
print('\n'.join(erros) if erros else f'OK {slug}')
sys.exit(1 if erros else 0)
