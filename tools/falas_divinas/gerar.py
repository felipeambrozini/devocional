#!/usr/bin/env python3
"""Gera assets/falas_divinas/<slug>.json: os trechos de cada versiculo em que
fala Deus Pai, Jesus ou o Espirito Santo (letra vermelha).

Fonte: MACULA Quotation and Speaker Data (Clear Bible, CC BY 4.0,
github.com/Clear-Bible/speaker-quotations), que marca no hebraico/grego, palavra
por palavra, o inicio e o fim de cada fala e quem fala (dados de Faith Comes By
Hearing). A versificacao do original vira a da King James pelo eng.json da
Copenhagen Alliance (versification-specification).

Uso:
  python tools/falas_divinas/gerar.py <Clear-Aligned-Projections.tsv> \
      <alignment-quotations-clear.tsv> <eng.json>

Como o portugues nao traz aspas, o corte dentro do versiculo e aproximado pela
proporcao: uma fala que comeca na palavra k de n do original comeca no ":" do
portugues mais perto de k/n do versiculo; uma que termina antes do fim termina
na pontuacao mais perto de onde termina no original.

Saida por livro: {"<cap>": {"<vers>": [[inicio, fim], ...]}} em indices de
caractere (UTF-16, como String no Dart) do texto de assets/biblia/<slug>.json.
"""

import csv
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
FALANTES_DIVINOS = {'God', 'Jesus', 'Jesus (child)', 'Holy Spirit, the'}
# Citacao das Escrituras por um apostolo ("como diz o profeta...") e fala
# hipotetica nao sao Deus falando na cena, e nenhuma edicao de letra vermelha
# as pinta.
TIPOS_IGNORADOS = {'Quotation', 'Hypothetical'}
# Lacuna de narracao curta no meio de uma fala ("diz o SENHOR") continua em
# vermelho: cortar ali deixaria o versiculo picado em pedacos de 2 palavras.
LACUNA_MAXIMA = 3
FIM_DE_FRASE = re.compile(r'[.;?!:,](?=\s|$)')
# Hebraico/grego e portugues nao tem a mesma ordem de palavras; uma pontuacao
# mais longe que isto da proporcao do original nao e o corte certo.
TOLERANCIA = 0.25
PESO_DO_FIM = {'.': 0, '?': 0, '!': 0, ';': 0.04, ':': 0.04, ',': 0.08}
NOME_DIVINO = re.compile(
    r'((Jesus|Deus|SENHOR|Senhor|Espírito|voz)[^.;:?!]*[:;]'
    r'|(disse|diz|dizia|falou)[^.;:?!,]*(Jesus|Deus|SENHOR|Senhor),)$')
REF = re.compile(r'(\w+) (\d+):(\d+)')
ID_VALIDO = re.compile(r'[on]\d{11,12}')


def slugs_por_codigo(palavras):
    codigos = []
    for linha in palavras:
        codigo = linha[3].split(' ')[0]
        if not codigos or codigos[-1] != codigo:
            codigos.append(codigo)
    canon = re.findall(r"Livro\(\s*'([a-z0-9]+)'",
                       (RAIZ / 'lib/dados/canon.dart').read_text(encoding='utf-8'))
    assert len(codigos) == len(canon) == 66, (len(codigos), len(canon))
    return dict(zip(codigos, canon))


def original_para_kjv(caminho):
    """{(livro, cap, vers) original: (cap, vers) KJV} a partir do eng.json."""
    def expandir(ref):
        livro, resto = ref.split(' ')
        cap, versos = resto.split(':')
        ini, _, fim = versos.partition('-')
        return [(livro, int(cap), v) for v in range(int(ini), int(fim or ini) + 1)]

    mapa = {}
    for kjv, original in json.load(open(caminho, encoding='utf-8'))['mappedVerses'].items():
        if kjv.startswith('ESG'):
            continue  # Ester grega (apocrifo), com versiculos "1a", "1b"...
        for (_, c, v), (livro, oc, ov) in zip(expandir(kjv), expandir(original)):
            mapa[(livro, oc, ov)] = (c, v)
    return mapa


def palavras_divinas(projecoes, palavras):
    posicao = {linha[2]: i for i, linha in enumerate(palavras)}
    primeira, ultima = {}, {}
    for i, linha in enumerate(palavras):
        versiculo = linha[3].split('!')[0]
        primeira.setdefault(versiculo, i)
        ultima[versiculo] = i

    def indice(id_, versiculo, por_versiculo):
        # Algumas linhas trazem o id truncado ("n"); a fala vale entao do
        # comeco (ou ate o fim) do versiculo em que a fala toda comeca (ou
        # termina).
        if ID_VALIDO.fullmatch(id_):
            return posicao.get(id_)
        return por_versiculo.get(versiculo)

    divinas = set()
    for p in projecoes:
        if p['SPEAKER (FCBH)'] in FALANTES_DIVINOS and p['QUOTE TYPE'] not in TIPOS_IGNORADOS:
            ini = indice(p['CLEAR START'], p['START VS'], primeira)
            fim = indice(p['CLEAR END'], p['END VS'], ultima)
            if ini is not None and fim is not None:
                divinas.update(range(ini, fim + 1))
    return divinas


def segmentos(marcas):
    """[(inicio, fim)] em fracao do versiculo, dados os booleanos por palavra."""
    n = len(marcas)
    trechos, i = [], 0
    while i < n:
        if not marcas[i]:
            i += 1
            continue
        j = i
        while j < n and marcas[j]:
            j += 1
        trechos.append([i, j])
        i = j
    unidos = []
    for t in trechos:
        if unidos and t[0] - unidos[-1][1] <= LACUNA_MAXIMA:
            unidos[-1][1] = t[1]
        else:
            unidos.append(t)
    return [(a / n, b / n, a == 0, b == n) for a, b in unidos]


def mais_perto(candidatos, alvo, tamanho):
    return min(candidatos, key=lambda c: abs(c / tamanho - alvo), default=None)


def utf16(texto, i):
    return len(texto[:i].encode('utf-16-le')) // 2


def recortar(texto, inicio, fim, do_comeco, ate_o_fim):
    n = len(texto)
    if do_comeco:
        a = 0
    else:
        # A King James introduz a fala com ":" ("disse Deus: Haja luz"), ";" ("Assim
        # diz o SENHOR; ...") e as vezes "," ("disse o SENHOR, Que ves tu?").
        # Sem pontuacao perto, a fala vem do versiculo anterior e so foi
        # interrompida por narracao longa: pinta desde o comeco.
        # A fala comeca depois da pontuacao que fecha a introducao ("Disse-lhe
        # Jesus:", "Assim diz o SENHOR;", "disse o SENHOR, Que ves tu?"). Entre
        # as que cabem na tolerancia, ganha a que vem logo apos um nome divino,
        # depois ":"/";", depois qualquer uma; sem nenhuma, a fala vem do
        # versiculo anterior e so foi interrompida por narracao longa.
        perto = [m.end() for m in FIM_DE_FRASE.finditer(texto)
                 if abs(m.end() / n - inicio) <= TOLERANCIA]
        com_nome = [c for c in perto if NOME_DIVINO.search(texto[max(0, c - 40):c])]
        com_dois_pontos = [c for c in perto if texto[c - 1] in ':;']
        a = mais_perto(com_nome or com_dois_pontos or perto, inicio, n) or 0
    if ate_o_fim:
        b = n
    else:
        # Fim de frase ganha de virgula a distancia parecida: "...o que fazem.
        # E, repartindo" termina no ponto, nao na virgula depois do "E".
        fins = [m.end() for m in FIM_DE_FRASE.finditer(texto)
                if m.end() > a and abs(m.end() / n - fim) <= TOLERANCIA]
        b = min(fins, key=lambda c: abs(c / n - fim) + PESO_DO_FIM[texto[c - 1]], default=n)
    while a < b and texto[a].isspace():
        a += 1
    return (utf16(texto, a), utf16(texto, b)) if a < b else None


def main(caminho_projecoes, caminho_palavras, caminho_versificacao):
    projecoes = list(csv.DictReader(open(caminho_projecoes, encoding='utf-8'), delimiter='\t'))
    # As linhas "+++"/"---" (inicio/fim de citacao) tem uma coluna so.
    palavras = [l for l in csv.reader(open(caminho_palavras, encoding='utf-8'), delimiter='\t')
                if len(l) >= 5][1:]
    slugs = slugs_por_codigo(palavras)
    para_kjv = original_para_kjv(caminho_versificacao)
    divinas = palavras_divinas(projecoes, palavras)

    marcas_por_versiculo = {}
    for i, linha in enumerate(palavras):
        livro, cap, vers = REF.match(linha[3]).groups()
        chave = (livro, int(cap), int(vers))
        marcas_por_versiculo.setdefault(chave, []).append(i in divinas)

    saida = {slug: {} for slug in slugs.values()}
    textos = {}
    sem_corte = []
    for (livro, cap, vers), marcas in marcas_por_versiculo.items():
        if not any(marcas):
            continue
        cap_kjv, vers_kjv = para_kjv.get((livro, cap, vers), (cap, vers))
        if vers_kjv == 0:
            continue  # titulo de salmo, que o app guarda a parte
        slug = slugs[livro]
        if slug not in textos:
            textos[slug] = json.load(open(RAIZ / f'assets/biblia/{slug}.json', encoding='utf-8'))
        texto = textos[slug]['capitulos'].get(str(cap_kjv), {}).get('versiculos', {}).get(str(vers_kjv))
        if texto is None:
            sem_corte.append(f'{slug} {cap_kjv}:{vers_kjv} sem versiculo no portugues')
            continue
        trechos = []
        for seg in segmentos(marcas):
            corte = recortar(texto, *seg)
            if corte is None:
                sem_corte.append(f'{slug} {cap_kjv}:{vers_kjv} trecho vazio: {texto}')
            elif not trechos or corte[0] >= trechos[-1][1]:
                trechos.append(corte)
        if trechos:
            saida[slug].setdefault(str(cap_kjv), {})[str(vers_kjv)] = [list(t) for t in trechos]

    destino = RAIZ / 'assets/falas_divinas'
    destino.mkdir(exist_ok=True)
    for slug, caps in saida.items():
        ordenado = {c: dict(sorted(v.items(), key=lambda kv: int(kv[0])))
                    for c, v in sorted(caps.items(), key=lambda kv: int(kv[0]))}
        (destino / f'{slug}.json').write_text(
            json.dumps(ordenado, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    total = sum(len(v) for caps in saida.values() for v in caps.values())
    print(f'{total} versiculos com fala divina; {len(sem_corte)} sem corte:')
    print('\n'.join(sem_corte))

    # A revisao manual mora em correcoes/<slug>.json e vale por cima do MACULA.
    from aplicar_correcoes import aplicar
    aplicar()


if __name__ == '__main__':
    main(*sys.argv[1:4])
