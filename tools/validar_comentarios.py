#!/usr/bin/env python3
"""Valida os comentarios de Spurgeon (assets/comentarios/*.json) contra a skill.

Uso:
  python tools/validar_comentarios.py              # valida tudo
  python tools/validar_comentarios.py genesis      # valida so um livro
  python tools/validar_comentarios.py --resumo     # so contagens por livro
  python tools/validar_comentarios.py --sem-avisos # so erros (sem WARN)

Codigos de saida: 0 = sem erros (avisos podem existir), 1 = ha erros.
Cada problema sai no formato:  <slug> <cap>:<ver>  [TIPO]  detalhe

Verificacoes (fonte: skill spurgeon-comentarios):
  - estrutura espelhada em assets/biblia/<slug>.json (capitulo/versiculo existem,
    slug e nome do livro casam com a Biblia interna)
  - sem travessao (em dash, en dash, duplo hifen)
  - sem caracteres CJK/cirilicos (corrupcao de geracao)
  - sem markdown, sem quebra de linha (paragrafo unico)
  - sem frases de molde genericas (lote "template")
  - sem "a salve" (alucinacao de traducao de "salvation")
  - comprimento 40-120 palavras (CURTO/LONGO avisam; MUITO LONGO e erro)
  - heuristica TELEGRAFICO (frases curtas de nota de rodape) e FORMULAICO
    (padrao "X com Y ... Que ... pois ...")
  - citacoes entre aspas devem existir byte a byte no texto da Biblia do livro
  - comentario duplicado em refs distintas
"""

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DIR_COM = RAIZ / "assets" / "comentarios"
DIR_BIB = RAIZ / "assets" / "biblia"

# Frases genericas de molde (lote template): qualquer uma ja desclassifica.
MOLDE = [
    "marca este vers\u00edculo na hist\u00f3ria",
    "abre janela para ver a m\u00e3o de Deus",
    "Que o leitor tome isto para o cora\u00e7\u00e3o",
    "Leva isto \u00e0 ora\u00e7\u00e3o e prova o Senhor",
    "Descansa nesta verdade quando a noite vier",
    "Ensina isto a teu filho",
    "Persevera at\u00e9 o fim, pois coroa",
    "Que a esperan\u00e7a ferva",
    "Volta a esta promessa quando o cora\u00e7\u00e3o esfriar",
    "Que a gratid\u00e3o cante hoje mais alto",
    "Que a mansid\u00e3o responda onde a ira queria gritar",
    "Toma coragem, pois o Senhor dos Ex\u00e9rcitos",
    "Serve hoje em oculto, que o Pai que v\u00ea em secreto",
    "Que a alma se humilhe, confie e obede\u00e7a",
    "Guarda esta palavra como l\u00e2mpada para o p\u00e9",
    "Que esta palavra seja martelo e fogo",
    "Medita nisto de dia e de noite",
    "Pesa isto na balan\u00e7a do c\u00e9u",
    "Que o temor santo guie a l\u00edngua",
    "Que a f\u00e9 responda com obedi\u00eancia pronta",
    "Deus escreve reto com linhas tortas",
    "A mem\u00f3ria das miseric\u00f3rdias passadas",
    "A Palavra lida com rever\u00eancia alimenta",
    "A provid\u00eancia governa cada detalhe",
    "A miseric\u00f3rdia triunfa sobre o ju\u00edzo",
    "A noite escura real\u00e7a as estrelas",
    "A ora\u00e7\u00e3o move o cora\u00e7\u00e3o antes de mover",
    "O Esp\u00edrito convence, consola e conduz",
    "A semente lan\u00e7ada com fidelidade germina",
    "A vigil\u00e2ncia guarda a porta que a ora\u00e7\u00e3o abriu",
    "O descanso do povo de Deus permanece firme",
    "Cristo \u00e9 o centro para onde toda promessa corre",
    "A soberania divina n\u00e3o anula o dever humano",
    "O arrependimento verdadeiro troca o amor ao pecado",
    "O temor do Senhor \u00e9 princ\u00edpio de toda sabedoria",
    "A verdade dita com amor edifica",
    "O cora\u00e7\u00e3o quebrantado Deus n\u00e3o despreza",
    "A paci\u00eancia espera o tempo do Senhor",
    "A afli\u00e7\u00e3o \u00e9 forno onde a f\u00e9 se purifica",
    "A f\u00e9 anda sobre a \u00e1gua quando olha para Cristo",
    "O contentamento floresce onde a cobi\u00e7a murcha",
    "A fidelidade nas coisas pequenas abre porta",
    "A generosidade reflete o Pai que d\u00e1 sol",
    "A justi\u00e7a do Senhor n\u00e3o tarda nem falha",
    "A santidade n\u00e3o \u00e9 ornamento",
    "O pecado endurece em sil\u00eancio e se dissolve",
    "A igreja cresce de joelhos",
    "Tudo coopera para o bem dos que amam a Deus",
    "A gratid\u00e3o transforma d\u00e1diva em altar",
]

# Tokens ingleses/estranhos que indicam texto corrompido (exige 2+ ocorrencias).
LIXO_TOKENS = {
    "the", "of", "and", "to", "is", "from", "not", "with", "that", "this",
    "write", "writes", "pvc", "dionys", "vero", "flower", "water",
    "unless", "register", "sheet", "concord", "it",
}

CJK = re.compile(r"[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]")
CIRILICO = re.compile(r"[\u0400-\u04ff]")
TRAVESSAO = re.compile(r"\u2014|\u2015|\u2013|--")
MARKDOWN = re.compile(r"\*\*|(^|\n)\s*#+")
SALVE_ERRO = re.compile(r"\ba? ?salve \u00e9", re.IGNORECASE)
SALVE_AVISO = re.compile(r"\bsalve\b", re.IGNORECASE)
PADRAO_FORMULAICO = re.compile(r"Que [^.\n]{4,70},? pois [^.]*(\b\w+ com \w+\b)", re.IGNORECASE)


def tokens(texto: str):
    return [t for t in re.split(r"[^a-z\u00e0-\u00fc]+", texto.lower()) if t]


def media_sentencas(texto: str) -> float:
    sentencas = [s for s in re.split(r"[.!?]+", texto) if s.strip()]
    palavras = len(texto.split())
    return palavras / max(len(sentencas), 1)


def cauda_do_texto(texto: str, n_sentencas: int = 2) -> str:
    """As ultimas `n_sentencas` frases do comentario, normalizadas (minusculas,
    espacos colapsados) -- usado para achar fechos que se repetem entre
    versiculos diferentes mesmo quando a abertura de cada um muda (o que
    escapa da lista MOLDE, literal, e do check DUPLICADO, que so pega texto
    integralmente identico). Retorna "" se o comentario tiver poucas frases
    para a cauda nao virar o texto inteiro."""
    sentencas = [s.strip() for s in re.split(r"(?<=[.!?])\s+", texto.strip()) if s.strip()]
    if len(sentencas) <= n_sentencas:
        return ""
    cauda = " ".join(sentencas[-n_sentencas:])
    return " ".join(cauda.split()).lower()


def valida_texto(texto: str):
    """Retorna (erros, avisos) para o corpo de um comentario."""
    erros, avisos = [], []
    limpo = texto.strip()
    palavras = len(limpo.split())

    if not limpo:
        erros.append("[VAZIO] corpo vazio")
        return erros, avisos
    if "\n" in limpo:
        erros.append("[QUEBRA-LINHA] mais de um paragrafo")
    if TRAVESSAO.search(texto):
        erros.append("[TRAVESSAO] em dash/en dash/duplo hifen proibido")
    if CJK.search(texto) or CIRILICO.search(texto):
        erros.append("[CARACTERES-ESTRANHOS] CJK/cirilico no meio do texto")
    if MARKDOWN.search(texto):
        erros.append("[MARKDOWN] markdown no corpo")
    for m in MOLDE:
        if m in texto:
            erros.append(f"[MOLDE] frase generica: {m[:48]}...")
            break
    if SALVE_ERRO.search(texto):
        erros.append("[SALVE] 'a salve e' (alucinacao de traducao; deveria ser salvacao)")
    elif SALVE_AVISO.search(texto):
        avisos.append("[SALVE?] 'salve' isolado (verificar se nao deveria ser salvacao)")

    if palavras < 40:
        avisos.append(f"[CURTO] {palavras} palavras (<40)")
    elif palavras > 120:
        if palavras > 160:
            erros.append(f"[MUITO-LONGO] {palavras} palavras (>160)")
        else:
            avisos.append(f"[LONGO] {palavras} palavras (>120)")

    achados = [t for t in tokens(texto) if t in LIXO_TOKENS]
    if len(achados) >= 2:
        avisos.append(f"[LIXO?] palavras uteis estrangeiras: {achados[:6]}")

    if palavras <= 50 and media_sentencas(limpo) <= 8:
        avisos.append("[TELEGRAFICO] estilo nota de rodape, fora da voz de Spurgeon")
    if PADRAO_FORMULAICO.search(limpo) or "am\u00e9m fiel" in limpo:
        avisos.append("[FORMULAICO] padrao 'X com Y ... Que ... pois'")
    return erros, avisos




def valida_citacoes(texto: str, corpus_biblia: str):
    """Citacoes entre aspas precisam existir na Biblia interna (aceita maiuscula
    inicial e reticencia final, porque a citacao pode iniciar a frase).
    O corpus deve chegar aqui ja em minusculas."""
    erros = []
    for citacao in re.findall(r'"([^"\n]{10,})"', texto):
        segmento = citacao.strip()
        segmento = re.sub(r"[.\u2026]+$", "", segmento).strip()
        if len(segmento) < 10:
            continue
        if segmento.lower() not in corpus_biblia:
            erros.append(f"[CITACAO] '{segmento[:60]}...' nao existe na Biblia interna")
    return erros


def carrega_corpus_biblia() -> str:
    """Concatena todos os versiculos de assets/biblia (ja em minusculas)
    para busca de citacoes."""
    partes = []
    for caminho in sorted(DIR_BIB.glob("*.json")):
        try:
            dados = json.loads(caminho.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        for cap in dados.get("capitulos", {}).values():
            partes.extend(cap.get("versiculos", {}).values())
    return "\n".join(partes).lower()


# Marcadores de padrao estrutural (nao literal) de molde: um percentual alto
# destes no livro inteiro indica geracao por template, mesmo com cada verso
# usando palavras diferentes (o que escapa da lista MOLDE, literal).
MARCADORES_ESTRUTURAIS = ("[FORMULAICO]", "[TELEGRAFICO]", "[MOLDE]")
LIMIAR_LIVRO_MOLDE = 0.15  # 15% dos versiculos com marcador estrutural


def valida_arquivo(caminho: Path, corpus_biblia: str):
    """Valida um livro inteiro. Retorna (erros, avisos, total)."""
    erros, avisos = [], []
    dados = json.loads(caminho.read_text(encoding="utf-8"))
    slug_arquivo = caminho.stem
    slug = dados.get("slug")
    book = dados.get("book")

    try:
        biblia = json.loads((RAIZ / "assets" / "biblia" / f"{slug}.json").read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        erros.append("[ESTRUTURA] Bible assets/biblia/<slug>.json ausente/invalida")
        biblia = None

    if biblia:
        if slug != slug_arquivo:
            erros.append(f"[ESTRUTURA] slug '{slug}' != nome do arquivo '{slug_arquivo}'")
        if book != biblia.get("nome"):
            erros.append(f"[ESTRUTURA] book '{book}' != nome na Biblia '{biblia.get('nome')}'")

    capitulos = dados.get("capitulos", {})
    total = 0
    marcados_molde = 0
    vistos = {}  # texto normalizado -> lista de "cap:ver" que o usam
    caudas = {}  # ultimas 2 frases normalizadas -> lista de "cap:ver" que terminam assim
    for num_cap, versiculos in capitulos.items():
        cap_bib = biblia.get("capitulos", {}).get(num_cap) if biblia else None
        if cap_bib is None:
            erros.append(f"[ESTRUTURA] {num_cap} nao existe no livro")
            continue
        for num_ver, texto in versiculos.items():
            versiculo_bib = cap_bib.get("versiculos", {}).get(num_ver)
            if versiculo_bib is None:
                erros.append(f"[ESTRUTURA] {num_cap}:{num_ver} nao existe no livro")
                continue
            total += 1
            ref = f"{num_cap}:{num_ver}"
            e, a = valida_texto(str(texto))
            if any(m in x for x in e + a for m in MARCADORES_ESTRUTURAIS):
                marcados_molde += 1
            e += valida_citacoes(str(texto), corpus_biblia)
            for x in e:
                erros.append(f"{ref}  {x}")
            for x in a:
                avisos.append(f"{ref}  {x}")

            normalizado = " ".join(str(texto).split()).strip().lower()
            if normalizado:
                vistos.setdefault(normalizado, []).append(f"{num_cap}:{num_ver}")

            cauda = cauda_do_texto(str(texto))
            if cauda:
                caudas.setdefault(cauda, []).append(ref)

    for refs in vistos.values():
        if len(refs) > 1:
            erros.append(f"[DUPLICADO] mesmo texto em {', '.join(refs)}")

    if total and marcados_molde / total >= LIMIAR_LIVRO_MOLDE:
        pct = 100 * marcados_molde / total
        erros.append(
            f"[LIVRO-MOLDE] {marcados_molde}/{total} versiculos ({pct:.1f}%) batem em "
            "padrao formulaico/telegrafico/molde estrutural -- livro provavelmente "
            "gerado por template, revisar ou reescrever inteiro"
        )

    # Fecho reciclado: mesmo quando a abertura de cada versiculo muda (o que
    # escapa da lista MOLDE, literal, e do DUPLICADO, que exige texto inteiro
    # identico), varios versiculos terminando com as mesmas 2 frases indicam
    # geracao por template disfarcada de prosa unica.
    marcados_final_repetido = 0
    for cauda, refs in sorted(caudas.items(), key=lambda kv: -len(kv[1])):
        if len(refs) > 1:
            marcados_final_repetido += len(refs)
            mostrar = ", ".join(refs[:8]) + (", ..." if len(refs) > 8 else "")
            avisos.append(f"[FINAL-REPETIDO] {len(refs)} versiculos terminam com o mesmo fecho: {mostrar}")

    if total and marcados_final_repetido / total >= LIMIAR_LIVRO_MOLDE:
        pct = 100 * marcados_final_repetido / total
        erros.append(
            f"[LIVRO-MOLDE-FINAL] {marcados_final_repetido}/{total} versiculos ({pct:.1f}%) "
            "reciclam um fecho de 2 frases identico ao de outro versiculo -- mesmo com "
            "aberturas diferentes, indica geracao por template; revisar ou reescrever o livro inteiro"
        )

    return erros, avisos, total


def main():
    args = sys.argv[1:]
    flags = {"--resumo": False, "--sem-avisos": False}
    slugs = []
    for a in args:
        if a in flags:
            flags[a] = True
        elif a.startswith("-"):
            print(f"flag desconhecida: {a}")
            sys.exit(2)
        else:
            slugs.append(a)

    arquivos = sorted(DIR_COM.glob("*.json"))
    if slugs:
        arquivos = [p for p in arquivos if p.stem in slugs]
    if not arquivos:
        print("nenhum arquivo de comentario encontrado")
        sys.exit(1)

    total_geral = erros_geral = avisos_geral = 0
    corpus_biblia = carrega_corpus_biblia()
    for caminho in arquivos:
        try:
            erros, avisos, total = valida_arquivo(caminho, corpus_biblia)
        except json.JSONDecodeError as exc:
            print(f"\n== {caminho.stem}: JSON INVALIDO ({exc_mensagem(exc)})")
            erros_geral += 1
            continue
        erros_geral += len(erros)
        avisos_geral += len(avisos)
        total_geral += total

        if flags["--resumo"]:
            print(f"{caminho.stem:18} n={total:5} erros={len(erros):4} avisos={len(avisos):4}")
            continue

        print(f"\n== {caminho.stem}: {total} comentarios, {len(erros)} erros, {len(avisos)} avisos")
        for x in erros:
            print("  ERRO  " + x)
        if not flags["--sem-avisos"]:
            for x in avisos:
                print("  aviso " + x)

    print(f"\nTOTAL: {total_geral} comentarios, {erros_geral} erros, {avisos_geral} avisos")
    sys.exit(1 if erros_geral else 0)


def exc_mensagem(exc):
    return str(exc)


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    main()

