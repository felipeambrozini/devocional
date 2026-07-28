"""Procura frases de Spurgeon sobre um livro biblico no corpus de Manha e Noite.

    python tools/frases_spurgeon.py Genesis Exodo ...
    python tools/frases_spurgeon.py --todos

A frase que vai na introducao precisa ser comprovada. Compor uma linha na voz dele e
rotular como citacao seria atribuir a uma pessoa real palavras que ela nao escreveu.
Entao a frase sai deste corpus, que e Spurgeon de fato, e a fonte fica registrada
como a data do devocional de onde veio.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

import canon

ROOT = Path(__file__).resolve().parent.parent
DEVOCIONAL = ROOT / "assets" / "devotional" / "morning_evening.json"
MESES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
         "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]

# Uma citacao boa fala do livro, nao apenas cita um versiculo dele.
# 'Jó 3:1' e referencia; 'o livro de Jó nos ensina' e citacao.
SO_REFERENCIA = re.compile(r"\d")


def carregar() -> list[tuple[str, str]]:
    """-> [(fonte legivel, sentenca)]"""
    dados = json.loads(DEVOCIONAL.read_text(encoding="utf-8"))
    saida = []
    for chave, dia in sorted(dados.items()):
        mes, num = int(chave[:2]), int(chave[3:])
        for periodo, nome in (("manha", "Manhã"), ("noite", "Noite")):
            entrada = dia.get(periodo)
            if not entrada:
                continue
            fonte = f"Manhã e Noite, {num} de {MESES[mes - 1]}, {nome}"
            texto = entrada["text"]
            for sentenca in re.split(r"(?<=[.!?])\s+", texto):
                sentenca = " ".join(sentenca.split())
                if sentenca:
                    saida.append((fonte, sentenca))
    return saida


def sem_acento(valor: str) -> str:
    decomposto = unicodedata.normalize("NFD", valor.lower())
    return "".join(c for c in decomposto if unicodedata.category(c) != "Mn")


def candidatas(sentencas: list[tuple[str, str]], nome: str) -> list[tuple[str, str]]:
    alvo = sem_acento(nome)
    # Com limite de palavra: sem isso, 'Numeros' casava dentro de 'numerosos' e
    # 'Jo' casava dentro de metade do dicionario.
    padrao = re.compile(rf"\b{re.escape(alvo)}\b")
    achados = []
    for fonte, sentenca in sentencas:
        if not padrao.search(sem_acento(sentenca)):
            continue
        # Comprimento util para uma epigrafe: nem fragmento, nem paragrafo.
        if not 60 <= len(sentenca) <= 260:
            continue
        # Descarta a sentenca que so cita capitulo e versiculo.
        janela = sem_acento(sentenca)
        pos = janela.find(alvo)
        depois = sentenca[pos + len(nome): pos + len(nome) + 6]
        if SO_REFERENCIA.search(depois):
            continue
        achados.append((fonte, sentenca))
    return achados


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    sentencas = carregar()
    alvos = canon.SLUGS if sys.argv[1] == "--todos" else sys.argv[1:]

    for alvo in alvos:
        slug = canon.resolve(alvo) or alvo
        nome = canon.NAMES.get(slug, alvo)
        achados = candidatas(sentencas, nome)
        print(f"\n{'=' * 72}\n{nome}  ({len(achados)} candidatas)")
        for fonte, sentenca in achados[:6]:
            print(f"  [{fonte}]")
            print(f"    {sentenca}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
