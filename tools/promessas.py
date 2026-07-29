"""Extrai os 366 dias de Faith's Checkbook (Spurgeon, 1888) do texto do CCEL.

    python tools/promessas.py --extrair CAMINHO/checkbook.txt
    python tools/promessas.py --validar

Produz tools/promessas_en.json, que e a fonte em ingles, dominio publico, com
titulo, referencia, versiculo e comentario de cada dia. A traducao para portugues
vive em assets/devotional/promises.json e e feita em lotes; este script nao traduz.

O texto do CCEL e edicao digital, nao OCR. As duas digitalizacoes do Internet
Archive foram descartadas: os cabecalhos de dia sairam corrompidos ('Feb. iz' em
vez de 'Feb. 12'), o que impossibilitava segmentar os 366 dias com seguranca.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FONTE_EN = Path(__file__).parent / "promessas_en.json"
TRADUCOES = Path(__file__).parent / "promessas_pt"
DESTINO_PT = ROOT / "assets" / "devotional" / "promises.json"

# Abreviacoes inglesas usadas no livro -> slug do canon. O versiculo em portugues
# nao e traduzido por mim: e lido da BKJ ja extraida, para que o texto da promessa
# seja identico ao que o usuario le no leitor da Biblia.
LIVROS_EN = {
    "gen": "genesis", "ex": "exodo", "exod": "exodo", "lev": "levitico",
    "num": "numeros", "deut": "deuteronomio", "josh": "josue", "judg": "juizes",
    "ruth": "rute", "sam": None, "kings": None, "chron": None,
    "ezra": "esdras", "neh": "neemias", "esther": "ester", "job": "jo",
    "ps": "salmos", "psa": "salmos", "prov": "proverbios", "eccles": "eclesiastes",
    "eccl": "eclesiastes", "song": "cantares", "cant": "cantares",
    "isa": "isaias", "jer": "jeremias", "lam": "lamentacoes", "ezek": "ezequiel",
    "dan": "daniel", "hos": "oseias", "joel": "joel", "amos": "amos",
    "obad": "obadias", "jonah": "jonas", "micah": "miqueias", "mic": "miqueias",
    "nahum": "naum", "nah": "naum", "hab": "habacuque", "zeph": "sofonias",
    "hag": "ageu", "zech": "zacarias", "mal": "malaquias",
    "matt": "mateus", "mat": "mateus", "mark": "marcos", "luke": "lucas",
    "john": "joao", "acts": "atos", "rom": "romanos", "cor": None,
    "gal": "galatas", "eph": "efesios", "phil": "filipenses",
    "philem": "filemom", "col": "colossenses", "thess": None, "tim": None,
    "titus": "tito", "heb": "hebreus", "james": "tiago", "pet": None,
    "jude": "judas", "rev": "apocalipse",
    # O livro alterna entre abreviacao e nome completo na mesma obra:
    # 'Hos. 2:18' num dia e 'Hosea 6:1' no outro.
    "genesis": "genesis", "exodus": "exodo", "leviticus": "levitico",
    "numbers": "numeros", "deuteronomy": "deuteronomio", "joshua": "josue",
    "judges": "juizes", "nehemiah": "neemias", "psalms": "salmos",
    "psalm": "salmos", "proverbs": "proverbios", "ecclesiastes": "eclesiastes",
    "isaiah": "isaias", "jeremiah": "jeremias", "lamentations": "lamentacoes",
    "ezekiel": "ezequiel", "hosea": "oseias", "obadiah": "obadias",
    "habakkuk": "habacuque", "zephaniah": "sofonias", "haggai": "ageu",
    "zechariah": "zacarias", "malachi": "malaquias", "matthew": "mateus",
    "romans": "romanos", "galatians": "galatas", "ephesians": "efesios",
    "philippians": "filipenses", "colossians": "colossenses",
    "philemon": "filemom", "hebrews": "hebreus", "revelation": "apocalipse",
}
# Livros com numero antes: 'I Sam.', '1 Cor.', '2 John'.
NUMERADOS = {
    "sam": ("1samuel", "2samuel"), "samuel": ("1samuel", "2samuel"),
    "kings": ("1reis", "2reis"),
    "chron": ("1cronicas", "2cronicas"), "chronicles": ("1cronicas", "2cronicas"),
    "cor": ("1corintios", "2corintios"),
    "corinthians": ("1corintios", "2corintios"),
    "thess": ("1tessalonicenses", "2tessalonicenses"),
    "thessalonians": ("1tessalonicenses", "2tessalonicenses"),
    "tim": ("1timoteo", "2timoteo"), "timothy": ("1timoteo", "2timoteo"),
    "pet": ("1pedro", "2pedro"), "peter": ("1pedro", "2pedro"),
    "john": ("1joao", "2joao", "3joao"),
}
ROMANOS_NUM = {"i": 1, "ii": 2, "iii": 3, "1": 1, "2": 2, "3": 3}


def resolver_referencia(ref: str) -> tuple[str, int, list[int]] | None:
    """'I Sam. 2:9' -> ('1samuel', 2, [9]);  'Prov. 3: 25,26' -> ('proverbios', 3, [25, 26])"""
    m = re.match(
        r"^\s*(?:([1-3]|I{1,3})\s+)?([A-Za-z][A-Za-z\. ]*?)\.?\s*"
        r"(\d{1,3}):\s*([\d,\s-]+)$",
        ref.strip(),
    )
    if not m:
        return None
    numero, nome, capitulo, versos = m.groups()
    chave = nome.strip().lower().replace(".", "").split()[-1]
    if chave == "sol":  # 'Song of Sol.'
        chave = "song"

    if numero:
        opcoes = NUMERADOS.get(chave)
        if not opcoes:
            return None
        indice = ROMANOS_NUM.get(numero.lower())
        if not indice or indice > len(opcoes):
            return None
        slug = opcoes[indice - 1]
    else:
        slug = LIVROS_EN.get(chave)
        if slug is None:
            # 'John 1:50' sem numero e o Evangelho, nao as epistolas.
            slug = "joao" if chave == "john" else None
        if slug is None:
            return None

    numeros: list[int] = []
    for parte in versos.replace(" ", "").split(","):
        if "-" in parte:
            a, b = parte.split("-")[:2]
            if a.isdigit() and b.isdigit():
                numeros.extend(range(int(a), int(b) + 1))
        elif parte.isdigit():
            numeros.append(int(parte))
    return (slug, int(capitulo), numeros) if numeros else None

MESES = ["January", "February", "March", "April", "May", "June",
         "July", "August", "September", "October", "November", "December"]
DIAS_NO_MES = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]  # inclui 29/02

# O CCEL alterna entre nome abreviado e completo: 'Jan. 1' e 'March 1'. E setembro
# aparece como 'Sept.', com quatro letras, o que fez os 30 dias do mes sumirem na
# primeira tentativa, engolidos pela entrada de 31 de agosto.
_ABREV = "|".join(["Sept"] + [m[:3] for m in MESES])
_COMPLETO = "|".join(MESES)
DIA = re.compile(rf"^\s*(?:({_COMPLETO})|({_ABREV}))\.?\s+(\d{{1,2}})\s*$")

# Referencia biblica: 'Gen. 3:15', 'Isa. 66:5', '1 Cor. 2:9', 'I Sam. 2:9',
# 'Song of Sol. 2:16'. Localizar a referencia e mais seguro que confiar nas aspas,
# porque em alguns dias o CCEL deixou a aspa de fechamento de fora.
REFERENCIA = re.compile(
    r"((?:[1-3]|I{1,3})?\s?(?:Song of Sol|[A-Z][a-z]{1,5})\.?\s*"
    # 'Prov. 3: 25,26' existe na fonte: o espaco depois dos dois pontos e opcional.
    r"\d{1,3}:\s*\d{1,3}(?:[-,]\s*\d{1,3})*)"
)


def parece_titulo(linha: str) -> bool:
    """Titulo da entrada: linha praticamente toda em maiuscula.

    Nao exige caixa alta perfeita porque o CCEL tem casos como
    'DESIRES OF RlGHTEOUS GRANTED', com um l minusculo no lugar do I.
    """
    letras = [c for c in linha if c.isalpha()]
    if len(letras) < 4:
        return False
    return sum(1 for c in letras if c.isupper()) / len(letras) >= 0.8


def extrair(caminho: Path) -> tuple[dict, list[str]]:
    linhas = caminho.read_text(encoding="utf-8", errors="replace").split("\n")
    dias: dict[str, dict] = {}
    erros: list[str] = []

    chave: str | None = None
    titulo = ""
    buffer: list[str] = []
    # O sumario no inicio do arquivo tem centenas de linhas 'Gen. 1:1 -- Jan. 5'
    # que casariam com o padrao de dia. O corpo comeca no primeiro THE MONTH OF.
    dentro = False

    def fechar() -> None:
        nonlocal titulo
        if not chave:
            return
        bruto = " ".join(p.strip() for p in buffer if p.strip())
        bruto = re.sub(r"\s+", " ", bruto).strip()
        if not bruto:
            erros.append(f"{chave}: sem texto")
            return
        # A entrada e: versiculo, referencia, comentario. A referencia e a divisa,
        # e nao a aspa: ha dias em que a aspa de fechamento nao existe na fonte.
        ref, versiculo, comentario = "", "", bruto
        m = REFERENCIA.search(bruto[:700])
        if m:
            ref = " ".join(m.group(1).split())
            versiculo = bruto[:m.start()].strip().strip('"').strip()
            comentario = bruto[m.end():].strip()
        # Quando o titulo nao foi capturado como linha propria, ele sobra no
        # comeco do versiculo em caixa alta; separa-se aqui.
        if not titulo and versiculo:
            palavras = versiculo.split()
            caixa_alta = []
            for p in palavras:
                if parece_titulo(p):
                    caixa_alta.append(p)
                else:
                    break
            if len(caixa_alta) >= 2:
                titulo = " ".join(caixa_alta)
                versiculo = " ".join(palavras[len(caixa_alta):]).strip().strip('"').strip()
        dias[chave] = {
            "title": titulo,
            "reference": ref,
            "verse": versiculo,
            "body": comentario,
        }

    for linha in linhas:
        if "THE MONTH OF" in linha:
            dentro = True
            continue
        if not dentro:
            continue
        # Depois de 31 de dezembro o CCEL anexa indices e uma lista de links
        # internos. Sem este corte, tudo isso entrava no ultimo dia do ano.
        if "file:///" in linha or linha.strip().startswith("Index"):
            dentro = False
            continue
        if linha.strip().startswith("___"):
            continue
        m = DIA.match(linha)
        if m:
            fechar()
            nome = m.group(1) or m.group(2)
            mes = next(i for i, x in enumerate(MESES, 1) if x.startswith(nome[:3]))
            chave = f"{mes:02d}-{int(m.group(3)):02d}"
            titulo, buffer = "", []
            continue
        # 'ainda sem conteudo' precisa ignorar as linhas em branco entre o dia e o
        # titulo, senao a primeira delas ja bloquearia a deteccao.
        if (chave and not titulo and not any(b.strip() for b in buffer)
                and parece_titulo(linha.strip())):
            # Linha em caixa alta logo depois do dia: o titulo da entrada.
            titulo = " ".join(linha.split())
            continue
        if chave:
            buffer.append(linha)
    fechar()

    for mes, ultimo in enumerate(DIAS_NO_MES, 1):
        for dia in range(1, ultimo + 1):
            k = f"{mes:02d}-{dia:02d}"
            if k not in dias:
                erros.append(f"dia ausente: {k}")
    return dias, erros


def resumo(dias: dict) -> None:
    import statistics
    tamanhos = [len(d["body"].split()) for d in dias.values()]
    sem_ref = [k for k, d in dias.items() if not d["reference"]]
    sem_titulo = [k for k, d in dias.items() if not d["title"]]
    sem_versiculo = [k for k, d in dias.items() if not d["verse"]]
    print(f"  {len(dias)} dias | comentario medio {statistics.mean(tamanhos):.0f} palavras "
          f"| min {min(tamanhos)} | max {max(tamanhos)}")
    print(f"  sem referencia: {len(sem_ref)} {sem_ref[:6]}")
    print(f"  sem titulo: {len(sem_titulo)} {sem_titulo[:6]}")
    print(f"  sem versiculo: {len(sem_versiculo)} {sem_versiculo[:6]}")


def montar() -> tuple[dict, list[str]]:
    """Junta as traducoes de tools/promessas_pt/*.json com os versiculos da BKJ."""
    import canon

    en = json.loads(FONTE_EN.read_text(encoding="utf-8"))
    pt: dict[str, dict] = {}
    for arquivo in sorted(TRADUCOES.glob("*.json")):
        pt.update(json.loads(arquivo.read_text(encoding="utf-8")))

    biblia: dict[str, dict] = {}
    saida: dict[str, dict] = {}
    erros: list[str] = []

    for chave in sorted(en):
        traduzido = pt.get(chave)
        if not traduzido:
            continue
        alvo = resolver_referencia(en[chave]["reference"])
        if alvo is None:
            erros.append(f"{chave}: referencia nao resolvida {en[chave]['reference']!r}")
            continue
        slug, capitulo, versos = alvo
        if slug not in biblia:
            caminho = ROOT / "assets" / "bible" / "bkj" / f"{slug}.json"
            biblia[slug] = json.loads(caminho.read_text(encoding="utf-8"))
        cap = biblia[slug]["chapters"].get(str(capitulo), {}).get("verses", {})
        textos = [cap.get(str(v), "") for v in versos]
        if not any(textos):
            erros.append(f"{chave}: versiculo ausente na BKJ "
                         f"{canon.NAMES[slug]} {capitulo}:{versos}")
            continue
        faixa = (f"{versos[0]}-{versos[-1]}"
                 if len(versos) > 1 and versos == list(range(versos[0], versos[-1] + 1))
                 else ",".join(str(v) for v in versos))
        saida[chave] = {
            "title": traduzido["title"],
            "reference": f"{canon.NAMES[slug]} {capitulo}:{faixa}",
            "verse": " ".join(t for t in textos if t),
            "text": traduzido["body"],
        }
    return saida, erros


def main() -> int:
    ap = argparse.ArgumentParser(description="Faith's Checkbook: fonte em ingles.")
    ap.add_argument("--extrair", metavar="TXT", help="texto do CCEL")
    ap.add_argument("--montar", action="store_true",
                    help="junta traducoes + versiculos da BKJ em assets")
    ap.add_argument("--referencias", action="store_true",
                    help="confere se as 366 referencias resolvem na BKJ")
    ap.add_argument("--validar", action="store_true")
    args = ap.parse_args()

    if args.referencias:
        en = json.loads(FONTE_EN.read_text(encoding="utf-8"))
        ruins = [(k, v["reference"]) for k, v in en.items()
                 if resolver_referencia(v["reference"]) is None]
        print(f"{len(en)} referencias | {len(ruins)} nao resolvidas")
        for k, r in ruins[:15]:
            print(f"  {k}: {r!r}")
        return 1 if ruins else 0

    if args.montar:
        TRADUCOES.mkdir(exist_ok=True)
        saida, erros = montar()
        for e in erros[:15]:
            print(f"  ERRO: {e}")
        DESTINO_PT.parent.mkdir(parents=True, exist_ok=True)
        DESTINO_PT.write_text(
            json.dumps(saida, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{len(saida)} de 366 dias montados -> "
              f"{DESTINO_PT.relative_to(ROOT)}")
        return 1 if erros else 0

    if args.extrair:
        dias, erros = extrair(Path(args.extrair))
        resumo(dias)
        for e in erros[:12]:
            print(f"  ERRO: {e}")
        if erros:
            print(f"  ({len(erros)} problemas)")
            return 1
        FONTE_EN.write_text(
            json.dumps(dias, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"  -> {FONTE_EN.relative_to(ROOT)}")
        return 0

    if args.validar:
        if not FONTE_EN.is_file():
            print("fonte em ingles ainda nao extraida")
            return 1
        en = json.loads(FONTE_EN.read_text(encoding="utf-8"))
        print(f"fonte em ingles: {len(en)} dias")
        pt = json.loads(DESTINO_PT.read_text(encoding="utf-8")) if DESTINO_PT.is_file() else {}
        faltam = [k for k in sorted(en) if k not in pt]
        print(f"traduzidos: {len(pt)} de {len(en)}")
        if faltam:
            print(f"  faltam {len(faltam)}, comecando em {faltam[:6]}")
        return 0

    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
