#!/usr/bin/env python3
"""Acha, nos comentários de Spurgeon, trechos sem aspas que reproduzem um versículo da BKJ com
palavras trocadas.

Uso:
  python tools/quase_literal.py genesis exodo            # livros dados
  python tools/quase_literal.py --todos                  # os 66 livros
  python tools/quase_literal.py genesis --min 8          # limiar de palavras (padrão 12)

O comentário que repete o versículo com outras palavras só o parafraseia, e a skill
spurgeon-comentarios pede o contrário: expor o sentido, não refazer a frase. O que vai entre
aspas já é conferido byte a byte por validar_comentarios.py; aqui só entra o texto fora delas.

Um trecho é candidato quando ao menos --min palavras seguidas do comentário casam, em ordem,
com um versículo, com buracos curtos (até 2 palavras) de um lado ou do outro: o trecho
literal, sem buraco nenhum, não é problema. Sai uma linha por candidato:
  <livro> <cap>:<ver>  <casadas>/<extensão>  ~ <versículo parecido>  <trecho>
Os códigos de saída são sempre 0: é uma lista de trabalho, não uma barreira.
"""

import argparse
import collections
import difflib
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DIR_COMENTARIOS = RAIZ / "assets" / "comentarios"
DIR_BIBLIA = RAIZ / "assets" / "biblia"

PALAVRAS_MINIMAS_PADRAO = 12
BURACO_MAXIMO = 2  # palavras de diferença que ainda contam como o mesmo trecho
ENTRADAS_DO_INDICE = 4  # tamanho do n-grama que aponta versículos candidatos
VERSICULOS_POR_COMENTARIO = 4


def palavras(texto):
    return re.findall(r"[\wÀ-ÿ']+", texto.lower())


class Biblia:
    """Palavras de cada versículo e um índice de 4-gramas para achar os parecidos."""

    def __init__(self):
        self.versiculos = {}
        self.indice = collections.defaultdict(set)
        for caminho in sorted(DIR_BIBLIA.glob("*.json")):
            dados = json.loads(caminho.read_text(encoding="utf-8"))
            for capitulo, conteudo in dados["capitulos"].items():
                for versiculo, texto in conteudo["versiculos"].items():
                    chave = (caminho.stem, capitulo, versiculo)
                    ps = palavras(texto)
                    self.versiculos[chave] = ps
                    for i in range(len(ps) - ENTRADAS_DO_INDICE + 1):
                        self.indice[tuple(ps[i : i + ENTRADAS_DO_INDICE])].add(chave)

    def parecidos(self, ps):
        """Os versículos que mais dividem 4-gramas com a lista de palavras."""
        votos = collections.Counter()
        for i in range(len(ps) - ENTRADAS_DO_INDICE + 1):
            for chave in self.indice.get(tuple(ps[i : i + ENTRADAS_DO_INDICE]), ()):
                votos[chave] += 1
        return [c for c, n in votos.most_common(VERSICULOS_POR_COMENTARIO) if n >= 2]


def grupos_de_blocos(blocos):
    """Junta blocos casados separados por buracos curtos nos dois lados."""
    grupos, atual = [], []
    for bloco in blocos:
        if atual:
            ultimo = atual[-1]
            buraco_a = bloco.a - (ultimo.a + ultimo.size)
            buraco_b = bloco.b - (ultimo.b + ultimo.size)
            if buraco_a <= BURACO_MAXIMO and buraco_b <= BURACO_MAXIMO:
                atual.append(bloco)
                continue
            grupos.append(atual)
        atual = [bloco]
    if atual:
        grupos.append(atual)
    return grupos


def candidato_do_comentario(biblia, texto, minimo):
    """(versículo parecido, casadas, extensão, trecho) do primeiro trecho quase literal, ou None."""
    fora_das_aspas = re.sub(r'"[^"\n]*"', " ", texto)
    ps = palavras(fora_das_aspas)
    for chave in biblia.parecidos(ps):
        do_versiculo = biblia.versiculos[chave]
        if len(do_versiculo) < minimo:
            continue
        casador = difflib.SequenceMatcher(None, ps, do_versiculo, autojunk=False)
        blocos = [b for b in casador.get_matching_blocks() if b.size >= 2]
        for grupo in grupos_de_blocos(blocos):
            casadas = sum(b.size for b in grupo)
            extensao = grupo[-1].a + grupo[-1].size - grupo[0].a
            if casadas >= minimo and extensao > casadas:
                trecho = " ".join(ps[grupo[0].a : grupo[-1].a + grupo[-1].size])
                return chave, casadas, extensao, trecho
    return None


def candidatos_do_livro(biblia, slug, minimo):
    dados = json.loads((DIR_COMENTARIOS / f"{slug}.json").read_text(encoding="utf-8"))
    for capitulo, versiculos in dados["capitulos"].items():
        for versiculo, texto in versiculos.items():
            achado = candidato_do_comentario(biblia, texto, minimo)
            if achado:
                yield capitulo, versiculo, *achado


def slugs_do_canon():
    canon = (RAIZ / "lib" / "dados" / "canon.dart").read_text(encoding="utf-8")
    return re.findall(r"Livro\(\s*'([a-z0-9]+)'", canon)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("livros", nargs="*")
    parser.add_argument("--todos", action="store_true")
    parser.add_argument("--min", type=int, default=PALAVRAS_MINIMAS_PADRAO)
    args = parser.parse_args()
    livros = slugs_do_canon() if args.todos else args.livros
    if not livros:
        parser.error("diga os livros ou use --todos")

    biblia = Biblia()
    total = 0
    for slug in livros:
        achados = list(candidatos_do_livro(biblia, slug, args.min))
        total += len(achados)
        for capitulo, versiculo, chave, casadas, extensao, trecho in achados:
            parecido = f"{chave[0]} {chave[1]}:{chave[2]}"
            print(f"{slug} {capitulo}:{versiculo}  {casadas}/{extensao}  ~ {parecido}  {trecho}")
    print(f"TOTAL: {total} candidato(s) em {len(livros)} livro(s), mínimo {args.min} palavras")


if __name__ == "__main__":
    main()
