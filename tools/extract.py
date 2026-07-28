"""PDF -> JSON para o app. Roda offline, uma vez; o app so consome os assets.

    python tools/extract.py --bibles
    python tools/extract.py --devotional
    python tools/extract.py --validate     <- portao de qualidade

Os dois PDFs de Biblia marcam numero de versiculo, numero de capitulo e titulo de
livro com FONTES DISTINTAS do corpo do texto. Isso foi verificado, nao presumido, e
e o que permite um parser exato em vez de heuristica sobre texto corrido -- que na NVT
confundiria marcador de nota de rodape com numero de versiculo.

Requer: pip install pymupdf
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

import fitz  # pymupdf

import canon

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
# Os PDFs sao fonte, nao produto: ficam fora do repo.
PDF_DIRS = [ROOT / "assets" / "source_pdfs", Path.home() / "Downloads"]


def find_pdf(*fragments: str) -> Path | None:
    """Localiza um PDF por fragmentos do nome, em qualquer das pastas de origem."""
    for d in PDF_DIRS:
        if not d.is_dir():
            continue
        for p in sorted(d.glob("*.pdf")) + sorted(d.glob("*.PDF")):
            low = p.name.lower()
            if all(f.lower() in low for f in fragments):
                return p
    return None


def dump_json(path: Path, obj) -> None:
    """JSON indentado. Custa alguns MB a mais no bundle, mas o arquivo fica legivel
    e diffavel, o que importa mais num app pessoal do que o byte economizado."""
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def norm(s: str) -> str:
    """NFC + espacos colapsados. A NVT vem em NFD; sem isso, 'Exodo' nao casa."""
    return re.sub(r"\s+", " ", unicodedata.normalize("NFC", s)).strip()


def lines(page) -> list[list[dict]]:
    """Spans agrupados por linha. A NVT so pode ser desambiguada no nivel da linha:
    a secao de notas de fim de livro reusa as mesmas fontes do corpo."""
    out = []
    for block in page.get_text("dict")["blocks"]:
        if block["type"] != 0:
            continue
        for line in block["lines"]:
            group = [{"text": sp["text"], "font": sp["font"], "size": round(sp["size"], 1),
                      "new_line": i == 0}
                     for i, sp in enumerate(s for s in line["spans"] if s["text"].strip())]
            if group:
                group[0]["new_line"] = True
                out.append(group)
    return out


def spans(page) -> list[dict]:
    """Spans de texto da pagina em ordem de leitura, com fonte, corpo e quebra de linha.

    `new_line` importa: dentro de uma linha os spans se concatenam SEM separador,
    porque a NVT parte palavras em spans distintos para renderizar versalete --
    'o S' + 'ENHOR' + '. Louvei'. Juntar com espaco produziria 'o S ENHOR'.
    """
    out = []
    for block in page.get_text("dict")["blocks"]:
        if block["type"] != 0:  # 0 = texto; 1 = imagem
            continue
        for line in block["lines"]:
            first = True
            for sp in line["spans"]:
                if sp["text"].strip():
                    out.append({"text": sp["text"], "font": sp["font"],
                                "size": round(sp["size"], 1), "new_line": first})
                    first = False
    return out


# --------------------------------------------------------------------------- #
# Biblia
# --------------------------------------------------------------------------- #

class Builder:
    """Acumula spans classificados em livro -> capitulo -> versiculos."""

    def __init__(self) -> None:
        self.books: dict[str, dict[int, dict]] = {}
        self.slug: str | None = None
        self.chapter: int | None = None
        self.verse: int | None = None
        self.hyphen_line_breaks = 0

    def open_chapter(self, slug: str, chapter: int) -> None:
        self.slug, self.chapter, self.verse = slug, chapter, None
        self.books.setdefault(slug, {}).setdefault(chapter, {"title": [], "verses": {}})

    def open_verse(self, n: int) -> None:
        if self.slug is None or self.chapter is None:
            return
        self.verse = n
        self.books[self.slug][self.chapter]["verses"].setdefault(n, [])

    def _target(self) -> list[str] | None:
        if self.slug is None or self.chapter is None:
            return None
        ch = self.books[self.slug][self.chapter]
        # Texto antes do versiculo 1: sobrescrito do salmo ("Salmo de Davi.")
        return ch["title"] if self.verse is None else ch["verses"][self.verse]

    def add_text(self, text: str, new_line: bool) -> None:
        lines = self._target()
        if lines is None:
            return
        if new_line or not lines:
            lines.append(text)
        else:
            lines[-1] += text  # mesma linha: versalete continua a palavra

    def finish(self) -> dict[str, dict]:
        out: dict[str, dict] = {}
        for slug, chapters in self.books.items():
            book_chapters = {}
            for c, ch in sorted(chapters.items()):
                verses = {v: join_lines(lines) for v, lines in sorted(ch["verses"].items())}
                # Um marcador sem texto nao e versiculo: e ruido de navegacao do ebook.
                # As lacunas reais continuam aparecendo na validacao contra o canon.
                verses = {v: t for v, t in verses.items() if t}
                title = join_lines(ch["title"])
                # Quando o span do numero do v.1 nao e emitido pelo PDF, o texto do v.1
                # cai no sobrescrito. Acontece na BKJ (ex. Oseias 6). Promove de volta.
                if 1 not in verses and title:
                    verses[1] = title
                    title = ""
                book_chapters[str(c)] = {
                    "title": title,
                    "verses": {str(v): t for v, t in sorted(verses.items())},
                }
            out[slug] = {
                "slug": slug,
                "name": canon.NAMES[slug],
                "abbrev": canon.ABBREV[slug],
                "chapters": book_chapters,
            }
        return out


def join_lines(lines: list[str]) -> str:
    """Junta linhas de um versiculo. Une palavra cortada por hifen no fim da linha."""
    text = ""
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if not text:
            text = line
        elif text.endswith("-") and line[:1].islower():
            text = text[:-1] + line  # 'multipli-' + 'quem' -> 'multipliquem'
        else:
            text += " " + line
    return norm(text)


# Estilos medidos nos PDFs. (fonte, tamanho) -> papel do span.
BKJ_BODY = ("CharisSIL", 13.6)
BKJ_VERSE = ("Cambria", 9.5)
BKJ_CHAPTER = ("Georgia-Bold", 14.0)
# Sobrescrito do salmo ("Ao Músico-chefe de Neginote, Salmo de Davi."). Vem antes do
# versiculo 1, entao cai no titulo do capitulo pelo mesmo caminho do corpo.
BKJ_SUPERSCRIPTION = ("Arial-ItalicMT", 11.0)

# 'Gênesis 1', 'Salmo 23', '1 Samuel 5', 'Cânticos 2'
CHAPTER_HEAD = re.compile(r"^(.+?)\s+(\d{1,3})\s*$")


def extract_bkj(pdf: Path) -> dict[str, dict]:
    doc = fitz.open(pdf)
    b = Builder()
    unresolved: set[str] = set()

    for page in doc:
        for sp in spans(page):
            font, size, text = sp["font"], sp["size"], norm(sp["text"])
            if font.startswith("Calibri"):
                continue  # rodape da BVBooks e numero de pagina
            if (font, size) == BKJ_CHAPTER:
                m = CHAPTER_HEAD.match(text)
                if m:
                    slug = canon.resolve(m.group(1))
                    if slug:
                        b.open_chapter(slug, int(m.group(2)))
                    else:
                        unresolved.add(m.group(1))
                continue
            if (font, size) == BKJ_VERSE and text.rstrip(".").isdigit():
                b.open_verse(int(text.rstrip(".")))
                continue
            if (font, size) in (BKJ_BODY, BKJ_SUPERSCRIPTION):
                b.add_text(sp["text"], sp["new_line"])
                continue
            # Cambria 16 (titulo de livro) e Cambria-Bold 18 (testamento): descartados,
            # o cabecalho de capitulo ja carrega o nome do livro.
    doc.close()
    if unresolved:
        print(f"  [BKJ] nomes de livro nao resolvidos: {sorted(unresolved)}", file=sys.stderr)
    return b.finish()


NVT_VERSE = ("ChaparralPro-Bold", 11.3)
NVT_CHAPTER = ("ChaparralPro-Bold", 27.5)
NVT_HEADING = ("ChaparralPro-Bold", 15.0)
# 15.0 = corpo; 11.3 = VERSALETE. A NVT grafa "SENHOR" e "DEUS" como 'S' no corpo +
# 'ENHOR' em versalete, num span separado. Tratar 11.3 como nota de rodape (foi o erro
# inicial) apaga a palavra SENHOR de toda a Biblia. Nota de rodape mesmo e 8.7.
NVT_BODY_SIZES = (15.0, 11.3)
# Italico de corpo e Escritura, nao enfase editorial: "está registrado no Livro de Jasar".
NVT_BODY_FONTS = ("LucernaNwPS", "LucernaNw-ItalicPS")
NVT_FOOTNOTE_SIZE = 8.7


def nvt_book_ranges(doc) -> list[tuple[str, int, int]]:
    """Usa o outline do PDF (73 entradas) para delimitar as paginas de cada livro.

    E exato: dispensa adivinhar onde um livro comeca a partir do texto -- na NVT o
    cabecalho de navegacao do ebook cita o livro SEGUINTE, o que enganaria o parser.
    """
    # Todas as entradas do outline, nao so as de livro: o fim de um livro e a proxima
    # entrada QUALQUER. Depois de Apocalipse vem 'Plano anual de leitura', e sem esse
    # limite o plano inteiro do apendice era anexado a Apocalipse 22:21.
    entries = [(canon.resolve(norm(title)), page - 1) for _lvl, title, page in doc.get_toc()]
    ranges = []
    for i, (slug, start) in enumerate(entries):
        if slug is None:
            continue
        end = entries[i + 1][1] if i + 1 < len(entries) else doc.page_count
        ranges.append((slug, start, end))
    return ranges


def extract_nvt(pdf: Path) -> dict[str, dict]:
    doc = fitz.open(pdf)
    ranges = nvt_book_ranges(doc)
    if len(ranges) != 66:
        print(f"  [NVT] outline resolveu {len(ranges)} livros, esperado 66", file=sys.stderr)

    b = Builder()
    skipped_note_lines = 0
    for slug, start, end in ranges:
        b.slug, b.chapter, b.verse = None, None, None
        for pno in range(start, end):
            for line in lines(doc[pno]):
                is_chapter = any((s["font"], s["size"]) == NVT_CHAPTER for s in line)
                has_body = any(s["font"] in NVT_BODY_FONTS and s["size"] == 15.0 for s in line)
                # Cada livro termina com uma secao de notas que reusa as fontes do corpo:
                # a referencia da nota ('111', '119.37') sai em ChaparralPro-Bold 11.3, a
                # mesma do numero de versiculo, e o texto em LucernaNwPS 11.3, a mesma do
                # versalete. O que separa as duas coisas e a linha: linha de corpo sempre
                # tem ao menos um span de 15.0; linha de nota, nunca.
                if not is_chapter and not has_body:
                    skipped_note_lines += 1
                    continue
                for sp in line:
                    font, size, text = sp["font"], sp["size"], norm(sp["text"])
                    if font.startswith("LucernaNw-Bold"):
                        continue  # barra de navegacao '1 • 2 • 3 ...'
                    if (font, size) == NVT_CHAPTER:
                        if text.isdigit():
                            # Nao abre o v.1 aqui: na linha do capitular pode vir antes o
                            # sobrescrito do salmo, que pertence ao titulo, nao ao v.1.
                            b.open_chapter(slug, int(text))
                        continue
                    if (font, size) == NVT_VERSE:
                        if text.isdigit():
                            b.open_verse(int(text))
                        continue
                    if font in NVT_BODY_FONTS and size in NVT_BODY_SIZES:
                        # Sobrescrito do salmo: italico 11.3 na propria linha do capitular
                        # ('Ao regente do coral: salmo de Davi.'). Fora da linha do
                        # capitular, 11.3 italico e apenas versalete dentro do versiculo.
                        superscription = (is_chapter and size == 11.3
                                          and font == "LucernaNw-ItalicPS")
                        if not superscription and b.verse is None:
                            b.open_verse(1)  # o capitular faz o papel do marcador do v.1
                        b.add_text(sp["text"], sp["new_line"])
                        continue
                    if (font, size) == NVT_HEADING:
                        continue  # subtitulo de secao ('A criação', 'Interlúdio')
                    # LucernaNw-ItalicPS = enfase; ChaparralPro 25 = titulo do livro
    doc.close()
    print(f"  [NVT] {skipped_note_lines} linhas de nota de fim de livro descartadas")
    return b.finish()


# --------------------------------------------------------------------------- #
# Devocional Manha e Noite
# --------------------------------------------------------------------------- #

MONTHS = ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
          "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
DAY_HEAD = re.compile(r"^(\d{1,2})\s+de\s+(" + "|".join(MONTHS) + r")\s*$", re.I)
# Depois do devocional de 31 de dezembro o PDF traz um apendice com OUTRO plano de
# leitura ('Dezembro 1: 1 Coríntios 9 - 11'), mais indice e links. Sem este terminador
# tudo isso era anexado ao devocional da noite de 31/12, que ficava com 14 mil chars.
APPENDIX = re.compile(
    r"^(?:(?:" + "|".join(MONTHS) + r")\s+\d{1,2}\s*[:\-]"      # 'Dezembro 1: 1 Co 9 - 11'
    r"|plano\s+cronol[oó]gico"                                   # titulo do apendice
    r"|table\s+of\s+contents)", re.I)
PERIOD_HEAD = re.compile(r"^(Manhã|Noite)\b\s*(.*)$", re.S)
#            livro         cap:vers    faixa        sigla da versao, ex. '(Is 64:6 ACF)'
REFERENCE = re.compile(r"\(([1-3]?\s?[A-ZÀ-Ú][\wÀ-ú]{1,12}\.?\s+\d{1,3}:\d{1,3}"
                       r"(?:-\d{1,3})?(?:\s+[A-Z]{2,4})?)\)")


def extract_devotional(pdf: Path) -> dict[str, dict]:
    """-> {'01-01': {'manha': {...}, 'noite': {...}}}"""
    doc = fitz.open(pdf)
    lines: list[str] = []
    for page in doc:
        for raw in page.get_text("text").split("\n"):
            t = norm(raw)
            if t:
                lines.append(t)
    doc.close()

    days: dict[str, dict] = {}
    key: str | None = None
    period: str | None = None
    buf: list[str] = []

    def flush() -> None:
        if key and period and buf:
            body = norm(" ".join(buf))
            ref = REFERENCE.search(body)
            days.setdefault(key, {})[period] = {
                "reference": ref.group(1) if ref else "",
                "text": body,
            }

    for line in lines:
        # So vale depois do primeiro dia: o titulo do apendice aparece tambem no
        # sumario do front matter, antes de 01 de janeiro.
        if key is not None and APPENDIX.match(line):
            break
        m = DAY_HEAD.match(line)
        if m:
            flush()
            buf = []
            period = None
            key = f"{MONTHS.index(m.group(2).lower()) + 1:02d}-{int(m.group(1)):02d}"
            continue
        m = PERIOD_HEAD.match(line)
        if m and key:
            flush()
            period = "manha" if m.group(1) == "Manhã" else "noite"
            buf = [m.group(2)] if m.group(2).strip() else []
            continue
        if period:
            buf.append(line)
    flush()
    return days


# --------------------------------------------------------------------------- #
# Cronograma de leitura anual
# --------------------------------------------------------------------------- #

# Nomes de livro ordenados do mais longo para o mais curto: ancorado no inicio do
# trecho, isso resolve '3 João 1' sem confundir com 'João', e '2 Reis 1 a 4' sem
# tratar o '2' como capitulo do livro anterior.
BOOK_PREFIXES = sorted(canon.ALIASES.items(), key=lambda kv: -len(kv[0]))
PLAN_LINE = re.compile(r"^(\d{1,2})/(\d{1,2}):\s*(.+)$")


def split_book(chunk: str) -> tuple[str | None, str]:
    """'2 Reis 1 a 4' -> ('2reis', '1 a 4');  '4' -> (None, '4')."""
    low = norm(chunk).lower()
    for name, slug in BOOK_PREFIXES:
        if low.startswith(name) and (len(low) == len(name) or not low[len(name)].isalnum()):
            return slug, norm(chunk[len(name):])
    return None, norm(chunk)


def parse_ranges(label: str) -> list[dict]:
    """'Tiago 4 a 5, Gálatas 1' e 'Salmos 119:1 a 56' -> faixas resolvidas."""
    ranges: list[dict] = []
    book: str | None = None
    for chunk in label.split(","):
        chunk = norm(chunk)
        if not chunk:
            continue
        found, rest = split_book(chunk)
        if found:
            book = found
        if book is None:
            raise ValueError(f"trecho sem livro definido: {chunk!r} em {label!r}")
        if not rest:  # livro inteiro, ex. 'Obadias'
            ranges.append({"book": book, "fromChapter": 1,
                           "toChapter": canon.CHAPTERS[book]})
            continue
        # 'Salmos 119:1 a 56' -> faixa de VERSICULOS dentro de um capitulo
        m = re.fullmatch(r"(\d{1,3}):(\d{1,3})\s*a\s*(\d{1,3})", rest)
        if m:
            ch, v1, v2 = (int(g) for g in m.groups())
            ranges.append({"book": book, "fromChapter": ch, "toChapter": ch,
                           "fromVerse": v1, "toVerse": v2})
            continue
        m = re.fullmatch(r"(\d{1,3})\s*a\s*(\d{1,3})", rest)
        if m:
            ranges.append({"book": book, "fromChapter": int(m.group(1)),
                           "toChapter": int(m.group(2))})
            continue
        m = re.fullmatch(r"(\d{1,3})", rest)
        if m:
            ch = int(m.group(1))
            ranges.append({"book": book, "fromChapter": ch, "toChapter": ch})
            continue
        raise ValueError(f"nao entendi o trecho {rest!r} em {label!r}")
    return ranges


def build_plan() -> tuple[list[dict], list[str]]:
    src = (Path(__file__).parent / "reading_plan.txt").read_text(encoding="utf-8")
    days: list[dict] = []
    errors: list[str] = []
    seen: set[str] = set()

    for raw in src.split("\n"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = PLAN_LINE.match(line)
        if not m:
            errors.append(f"linha fora do formato dia/mes: {line!r}")
            continue
        day, month, label = int(m.group(1)), int(m.group(2)), norm(m.group(3))
        key = f"{month:02d}-{day:02d}"
        if key in seen:
            errors.append(f"data repetida: {key}")
        seen.add(key)
        try:
            ranges = parse_ranges(label)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        # Toda faixa e conferida contra o canon: capitulo inexistente ou versiculo fora
        # do capitulo viram erro aqui, e nao uma tela vazia no app.
        for r in ranges:
            nch = canon.CHAPTERS[r["book"]]
            if not 1 <= r["fromChapter"] <= r["toChapter"] <= nch:
                errors.append(f"{key} {label!r}: {canon.NAMES[r['book']]} "
                              f"{r['fromChapter']}-{r['toChapter']} fora de 1..{nch}")
                continue
            if "fromVerse" in r:
                nv = canon.VERSES[r["book"]][r["fromChapter"] - 1]
                if not 1 <= r["fromVerse"] <= r["toVerse"] <= nv:
                    errors.append(f"{key} {label!r}: versiculos "
                                  f"{r['fromVerse']}-{r['toVerse']} fora de 1..{nv}")
        days.append({"date": key, "label": label, "ranges": ranges})

    for month, last in enumerate([31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31], start=1):
        for day in range(1, last + 1):
            key = f"{month:02d}-{day:02d}"
            if key not in seen:
                errors.append(f"data ausente no cronograma: {key}")

    days.sort(key=lambda d: d["date"])
    return days, errors


# --------------------------------------------------------------------------- #
# Defeitos da fonte
# --------------------------------------------------------------------------- #

# Erros de composicao do proprio PDF, removidos explicitamente e com registro no
# console. Cada entrada foi conferida abrindo a pagina -- nao sao diferencas de
# versificacao entre traducoes, que a validacao reporta em separado.
SOURCE_DEFECTS: dict[str, dict[tuple[str, str, str], str]] = {
    "bkj": {
        ("2samuel", "7", "34"): "duplicata literal do v24 num capitulo de 29 versiculos",
    },
}


def drop_defects(version: str, books: dict[str, dict]) -> None:
    for (slug, ch, v), why in SOURCE_DEFECTS.get(version, {}).items():
        verses = books.get(slug, {}).get("chapters", {}).get(ch, {}).get("verses", {})
        if v in verses:
            del verses[v]
            print(f"  defeito do PDF removido: {canon.NAMES[slug]} {ch}:{v} -- {why}")


# --------------------------------------------------------------------------- #
# Validacao
# --------------------------------------------------------------------------- #

def validate_bible(version: str, books: dict[str, dict]) -> int:
    """Compara o extraido com a tabela canonica. Retorna o numero de problemas."""
    problems = 0
    missing = [s for s in canon.SLUGS if s not in books]
    if missing:
        print(f"  {version}: {len(missing)} livros AUSENTES: {missing[:8]}")
        problems += len(missing)

    for slug in canon.SLUGS:
        if slug not in books:
            continue
        chapters = books[slug]["chapters"]
        expected_ch = canon.CHAPTERS[slug]
        if len(chapters) != expected_ch:
            got = sorted(int(c) for c in chapters)
            gaps = [c for c in range(1, expected_ch + 1) if c not in got]
            print(f"  {version}/{slug}: {len(chapters)} capitulos, esperado {expected_ch}"
                  f"{f' | faltam {gaps[:10]}' if gaps else ''}")
            problems += 1
    # Lacuna = texto perdido pelo parser -> ERRO. Excedente = versificacao propria da
    # traducao (a NVT segue a NLT, que divide alguns versiculos diferente da KJV) ->
    # informativo. Sao coisas distintas e nao podem cair no mesmo contador.
    extras: list[str] = []
    for slug in canon.SLUGS:
        if slug not in books:
            continue
        chapters = books[slug]["chapters"]
        for ci, expected_v in enumerate(canon.VERSES[slug], start=1):
            ch = chapters.get(str(ci))
            if ch is None:
                continue
            nums = sorted(int(v) for v in ch["verses"])
            if not nums:
                print(f"  {version}/{slug} {ci}: capitulo VAZIO")
                problems += 1
                continue
            gaps = [v for v in range(1, expected_v + 1) if v not in nums]
            if gaps:
                print(f"  {version}/{slug} {ci}: LACUNA, faltam "
                      f"{gaps[:6]}{'...' if len(gaps) > 6 else ''}")
                problems += 1
            if max(nums) > expected_v:
                extras.append(f"{canon.NAMES[slug]} {ci}:{expected_v}->{max(nums)}")

    if extras:
        print(f"  {version}: {len(extras)} capitulos com versificacao propria "
              f"(nao e erro): {', '.join(extras[:10])}"
              f"{' ...' if len(extras) > 10 else ''}")
    return problems


def summary(version: str, books: dict[str, dict]) -> None:
    nch = sum(len(b["chapters"]) for b in books.values())
    nv = sum(len(c["verses"]) for b in books.values() for c in b["chapters"].values())
    chars = sum(len(t) for b in books.values() for c in b["chapters"].values() for t in c["verses"].values())
    print(f"  {version}: {len(books)} livros | {nch} capitulos | {nv} versiculos | {chars:,} chars")


# --------------------------------------------------------------------------- #

def write_bible(version: str, books: dict[str, dict]) -> None:
    out = ASSETS / "bible" / version
    out.mkdir(parents=True, exist_ok=True)
    for slug, book in books.items():
        dump_json(out / f"{slug}.json", book)
    index = [{"slug": s, "name": canon.NAMES[s], "abbrev": canon.ABBREV[s],
              "chapters": len(books[s]["chapters"]),
              "testament": "at" if i < canon.OT_COUNT else "nt"}
             for i, s in enumerate(canon.SLUGS) if s in books]
    dump_json(out / "index.json", index)
    print(f"  -> {out.relative_to(ROOT)} ({len(books)} arquivos + index.json)")


def load_bible(version: str) -> dict[str, dict]:
    d = ASSETS / "bible" / version
    return {p.stem: json.loads(p.read_text(encoding="utf-8"))
            for p in d.glob("*.json") if p.stem != "index"} if d.is_dir() else {}


SOURCES = {
    "bkj": ("Portugues-BKJFiel", extract_bkj),
    "nvt": ("NVT", extract_nvt),
}


def main() -> int:
    ap = argparse.ArgumentParser(description="Extrai Biblias e devocionais de PDF para JSON.")
    ap.add_argument("--bibles", action="store_true")
    ap.add_argument("--devotional", action="store_true")
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--validate", action="store_true")
    args = ap.parse_args()
    if not (args.bibles or args.devotional or args.plan or args.validate):
        ap.print_help()
        return 2

    problems = 0

    if args.plan:
        print("[plano] lendo tools/reading_plan.txt")
        days, errors = build_plan()
        nranges = sum(len(d["ranges"]) for d in days)
        verse_days = [d["date"] for d in days
                      if any("fromVerse" in r for r in d["ranges"])]
        print(f"  {len(days)} dias | {nranges} faixas | "
              f"{len(verse_days)} dias com faixa de versiculos: {verse_days}")
        for e in errors:
            print(f"  ERRO: {e}")
        problems += len(errors)
        if not errors:
            ASSETS.mkdir(parents=True, exist_ok=True)
            dump_json(ASSETS / "reading_plan.json", days)
            print(f"  -> {(ASSETS / 'reading_plan.json').relative_to(ROOT)}")

    if args.bibles:
        for version, (fragment, fn) in SOURCES.items():
            pdf = find_pdf(fragment)
            if not pdf:
                print(f"[{version}] PDF nao encontrado ({fragment}) -- pulando")
                continue
            print(f"[{version}] lendo {pdf.name}")
            books = fn(pdf)
            drop_defects(version, books)
            summary(version, books)
            write_bible(version, books)

    if args.devotional:
        pdf = find_pdf("Devocional", "Manha")
        if not pdf:
            print("[devocional] PDF Manha e Noite nao encontrado -- pulando")
        else:
            print(f"[devocional] lendo {pdf.name}")
            days = extract_devotional(pdf)
            complete = sum(1 for d in days.values() if d.get("manha") and d.get("noite"))
            print(f"  {len(days)} dias | {complete} com manha e noite")
            out = ASSETS / "devotional"
            out.mkdir(parents=True, exist_ok=True)
            dump_json(out / "morning_evening.json", days)
            print(f"  -> {(out / 'morning_evening.json').relative_to(ROOT)}")
            if len(days) < 365:
                print(f"  ATENCAO: {365 - len(days)} dias sem conteudo")
                problems += 1

    if args.validate:
        print("validando contra a tabela canonica "
              f"({len(canon.BOOKS)} livros / {canon.TOTAL_CHAPTERS} cap / {canon.TOTAL_VERSES} vers)")
        for version in SOURCES:
            books = load_bible(version)
            if not books:
                print(f"  {version}: nenhum asset extraido ainda")
                continue
            summary(version, books)
            problems += validate_bible(version, books)
        dev = ASSETS / "devotional" / "morning_evening.json"
        if dev.is_file():
            days = json.loads(dev.read_text(encoding="utf-8"))
            incomplete = [k for k, v in days.items() if not (v.get("manha") and v.get("noite"))]
            print(f"  devocional: {len(days)} dias"
                  + (f" | {len(incomplete)} incompletos: {incomplete[:8]}" if incomplete else " | todos completos"))
            problems += len(incomplete)

    print()
    print("OK, nada divergente." if problems == 0 else f"{problems} problema(s) encontrado(s).")
    return 0 if problems == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
