"""Resumo de revisao de um livro traduzido, para ler de uma vez so.

    python tools/biblioteca/revisar_livro.py <slug>

Junta o que checar_en.py, checar_capitulo.py e auditar_livro.py conferem com
verificacoes de conteudo: tamanho (portugues costuma sair maior que o ingles),
citacao entre aspas que parece versiculo de QUALQUER livro da BKJ mas nao e
literal (o tradutor traduziu por conta propria), paragrafo muito encurtado,
palavras em ingles soltas e portugues de Portugal fora de aspas.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict

from auditar_livro import BIBLIA, PASTA, palavras, quantidade_de_frases
from checar_capitulo import MARCADOR, problemas

COBERTURA_MINIMA = 0.75  # fracao das palavras da citacao que estao no versiculo
INGLES = re.compile(r"\b(the|and|of|which|with|that|thou|thee|hath|unto|shall)\b")
PORTUGAL = re.compile(
    r"\b(?:a certeza de que|(?:estou|estamos|estás) a \w+ndo?|faze|vocês?)\b|\bapraz-te\b",
    re.I,
)


def versiculos_da_biblia() -> tuple[list[tuple[str, list[str]]], dict]:
    """Os versiculos (ref, palavras) e um indice de trigramas para achar candidatos."""
    versos, indice = [], defaultdict(set)
    for arquivo in sorted(BIBLIA.glob("*.json")):
        livro = json.loads(arquivo.read_text(encoding="utf-8"))
        for cap, conteudo in livro["capitulos"].items():
            for num, texto in conteudo["versiculos"].items():
                ws = palavras(texto)
                versos.append((f"{livro['slug']} {cap}:{num}", ws))
                for i in range(len(ws) - 2):
                    indice[tuple(ws[i : i + 3])].add(len(versos) - 1)
    return versos, indice


def parece_versiculo(trecho: str, versos, indice) -> tuple[str, float] | None:
    ws = palavras(trecho)
    if len(ws) < 6:
        return None
    votos = Counter()
    for i in range(len(ws) - 2):
        for v in indice.get(tuple(ws[i : i + 3]), ()):
            votos[v] += 1
    melhor = None
    for v, _ in votos.most_common(5):
        ref, vws = versos[v]
        cobertura = sum(w in set(vws) for w in ws) / len(ws)
        if cobertura >= COBERTURA_MINIMA and (melhor is None or cobertura > melhor[1]):
            melhor = (ref, cobertura)
    return melhor


def revisar(slug: str) -> None:
    original = json.loads((PASTA / f"{slug}_en.json").read_text(encoding="utf-8"))["capitulos"]
    versos, indice = versiculos_da_biblia()
    todo_biblia = " ".join(" ".join(ws) for _, ws in versos)
    total_en = total_pt = 0
    com_problema, sem_registro, suspeitas, encurtados = [], [], [], []
    frases_perdidas, ingles_solto, portugal, vocesx = [], [], [], 0

    for i, cap in enumerate(original):
        traducao = json.loads((PASTA / f"{slug}_pt" / f"{i + 1:02d}.json").read_text(encoding="utf-8"))
        if problemas(slug, i):
            com_problema.append(i)
        registrados = [" ".join(palavras(c["trecho"])) for c in traducao["citacoes"]]
        for n, (en, pt) in enumerate(zip(cap["paragrafos"], traducao["paragrafos"])):
            if MARCADOR.match(en):
                continue
            total_en += len(en.split())
            total_pt += len(pt.split())
            if len(en.split()) >= 40 and len(pt.split()) < 0.6 * len(en.split()):
                encurtados.append(f"cap {i} p{n}: {len(en.split())}->{len(pt.split())} palavras")
            if quantidade_de_frases(en) >= 4 and quantidade_de_frases(pt) <= quantidade_de_frases(en) - 2:
                frases_perdidas.append(f"cap {i} p{n}")
            if len(INGLES.findall(pt)) >= 3:
                ingles_solto.append(f"cap {i} p{n}")
            fora_das_aspas = re.sub(r'"[^"]*"', '""', pt)
            for achado in PORTUGAL.finditer(fora_das_aspas):
                if achado.group(0).lower().startswith("voc"):
                    vocesx += 1
                else:
                    portugal.append(f"cap {i} p{n}: {achado.group(0)}")
            for citado in re.findall(r'"([^"]+)"', pt):
                t = " ".join(palavras(citado))
                if len(t.split()) < 4:
                    continue
                if f" {t} " in f" {todo_biblia} ":
                    if not any(t in r or r in t for r in registrados):
                        sem_registro.append(f"cap {i} p{n}: {citado[:70]}")
                elif (achado := parece_versiculo(citado, versos, indice)):
                    suspeitas.append(f"cap {i} p{n} ~{achado[0]} ({achado[1]:.0%}): {citado[:90]}")

    print(f"{slug}: {len(original)} capitulos, palavras EN {total_en} -> PT {total_pt} "
          f"(razao {total_pt / max(total_en, 1):.2f})")
    print(f"estrutura: {len(original) - len(com_problema)}/{len(original)} OK"
          + (f"; com problema: {com_problema}" if com_problema else ""))
    print(f"citacoes entre aspas na BKJ sem registro: {len(sem_registro)}")
    for linha in sem_registro[:8]:
        print("  ", linha)
    print(f"parecem versiculo mas nao sao literais da BKJ: {len(suspeitas)}")
    for linha in suspeitas[:30]:
        print("  ", linha)
    print(f"paragrafos muito encurtados (<60%): {len(encurtados)}", encurtados[:8])
    print(f"frases perdidas: {len(frases_perdidas)}", frases_perdidas[:8])
    print(f"ingles solto: {len(ingles_solto)}", ingles_solto[:8])
    print(f"portugues de Portugal fora de aspas: {len(portugal)}", portugal[:8], f"| voce: {vocesx}")


if __name__ == "__main__":
    revisar(sys.argv[1])
