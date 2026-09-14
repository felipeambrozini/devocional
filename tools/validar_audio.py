#!/usr/bin/env python3
"""Valida mp3 gerados por TTS (XTTS-v2) contra o texto esperado, transcrevendo
de volta com Whisper (sempre em CPU) e comparando a semelhanca.

Uso:
  python tools/validar_audio.py biblia --pasta "C:\\Users\\USER\\audio_gen_at\\biblia"
  python tools/validar_audio.py comentarios --pasta "C:\\Users\\USER\\audio_gen_comentarios\\comentarios" --apagar
  python tools/validar_audio.py biblia joao --pasta ...\\biblia          # so um livro
  python tools/validar_audio.py biblia --pasta ...\\biblia --limiar 0.8  # mais rigoroso

Sem --apagar, so reporta o que esta ruim (semelhanca abaixo do limiar) -- nada
e tocado no disco. Com --apagar, os mp3 ruins sao apagados: rode de novo o
gerar_biblia_at.py / gerar_biblia_nt.py / gerar_comentarios.py correspondente
(sem --limpar) para recriar so esses, aproveitando o mecanismo resumivel que
ja existe (skip-if-exists).

Nao mexe em nada no Storage -- roda sobre os mp3 ja gerados localmente, antes
do upload (gcloud storage rsync).

Requer: pip install faster-whisper

Codigos de saida: 0 = nada abaixo do limiar, 1 = ha mp3 ruim, 2 = erro de uso.
"""

import argparse
import json
import re
import subprocess
import sys
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DIR_BIBLIA = RAIZ / "assets" / "biblia"
DIR_COMENTARIOS = RAIZ / "assets" / "comentarios"

# Nome falado de cada livro -- a maioria vem do campo "nome"/"book" do JSON
# (ja acentuado certo); so os numerados precisam de forma por extenso, porque
# o TTS le "1" como "um", nao como "Primeiro"/"Primeira" (mesmo dicionario
# usado em audio_gen_*/_common.py -- ver nota no README de la).
NOME_FALADO = {
    "1samuel": "Primeiro Samuel",
    "2samuel": "Segundo Samuel",
    "1reis": "Primeiro Reis",
    "2reis": "Segundo Reis",
    "1cronicas": "Primeira Cronicas",
    "2cronicas": "Segunda Cronicas",
    "1corintios": "Primeira Corintios",
    "2corintios": "Segunda Corintios",
    "1tessalonicenses": "Primeira Tessalonicenses",
    "2tessalonicenses": "Segunda Tessalonicenses",
    "1timoteo": "Primeiro Timoteo",
    "2timoteo": "Segundo Timoteo",
    "1pedro": "Primeira Pedro",
    "2pedro": "Segunda Pedro",
    "1joao": "Primeira Joao",
    "2joao": "Segunda Joao",
    "3joao": "Terceira Joao",
}


def nome_falado_do_livro(slug: str, nome_do_json: str) -> str:
    return NOME_FALADO.get(slug, nome_do_json)


def _normalizar(texto: str) -> str:
    """Baixa caixa, remove acento e pontuacao -- compara palavras ditas, nao
    grafia exata (o Whisper nao pontua igual ao texto original)."""
    sem_acento = "".join(
        c
        for c in unicodedata.normalize("NFD", texto.lower())
        if unicodedata.category(c) != "Mn"
    )
    sem_pontuacao = re.sub(r"[^a-z0-9 ]", " ", sem_acento)
    return re.sub(r"\s+", " ", sem_pontuacao).strip()


def semelhanca(esperado: str, transcrito: str) -> float:
    # autojunk=False: por padrao, o SequenceMatcher trata caracteres muito
    # frequentes num texto longo (aqui, o espaco) como "lixo" e os ignora ao
    # casar blocos -- isso derrubava a nota pra ~7% em capitulos com audio
    # perfeito so por causa de um pequeno desalinhamento cedo no texto
    # (ex.: "capitulo 6" falado como "capitulo seis").
    return SequenceMatcher(
        None, _normalizar(esperado), _normalizar(transcrito), autojunk=False
    ).ratio()


# Frases compostas antes das palavras soltas -- senao "ponto de exclamacao"
# seria contado (errado) como um "ponto" solto.
_PONTUACAO_FALADA = [
    "ponto e virgula",
    "ponto de interrogacao",
    "ponto de exclamacao",
    "dois pontos",
    "reticencias",
    "ponto",
    "virgula",
]


def pontuacao_falada(esperado: str, transcrito: str) -> list[str]:
    """Sinaliza quando a transcricao tem, como palavra isolada, "ponto",
    "virgula" etc. -- defeito conhecido do XTTS-v2 que as vezes le o
    caractere de pontuacao em voz alta em vez de so pausar (ver
    _remover_ponto_final em audio_gen_*/_common.py). So conta se a palavra
    nao aparece tambem no texto esperado, pra nao dar falso positivo num
    versiculo que realmente cite alguma dessas palavras."""
    ne = _normalizar(esperado)
    nt = _normalizar(transcrito)
    achados = []
    restante = nt
    for termo in _PONTUACAO_FALADA:
        padrao = r"\b" + termo.replace(" ", r"\s+") + r"\b"
        if termo in ne:
            continue
        if re.search(padrao, restante):
            achados.append(termo)
            restante = re.sub(padrao, " ", restante, count=1)
    return achados


def gerar_espectrograma(caminho_mp3: Path, destino_png: Path, duracao_s: float = 2.0) -> None:
    """Miniatura do espectrograma dos primeiros [duracao_s] segundos.

    Chiado/estatica aparece nele como energia continua espalhada por toda a
    faixa de frequencia, sem os intervalos de silabas que a fala real tem --
    visualmente obvio, mas nao vira uma metrica numerica confiavel (tentado
    e descartado: planura espectral, proporcao de agudo, rolloff espectral e
    piso de ruido em silencio nao separaram de forma robusta os casos
    conhecidos com poucos exemplos). Por isso a checagem aqui e visual: gera
    a miniatura, quem revisa bate o olho em vez de ouvir o arquivo inteiro.
    """
    destino_png.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg", "-y", "-v", "error",
            # -t ANTES do -i: e opcao de entrada, limita quanto e lido do
            # arquivo. Depois do -i (junto do -lavfi) ele e ignorado com
            # showspectrumpic, que gera uma imagem so pro audio inteiro.
            "-t", str(duracao_s),
            "-i", str(caminho_mp3),
            "-lavfi", "showspectrumpic=s=1024x256:legend=0:scale=log",
            str(destino_png),
        ],
        check=True,
    )


_MODELO = None


def _dispositivo_whisper() -> tuple[str, str]:
    """GPU quando disponivel (Kaggle/Colab -- Whisper "small" fica bem mais
    rapido) e CPU como fallback (maquina local sem GPU). Rodando validacao
    JUNTO com uma sessao de geracao (XTTS-v2 na mesma GPU), prefira forcar
    CPU aqui pra nao disputar VRAM -- ver --cpu."""
    try:
        import torch

        if torch.cuda.is_available():
            return "cuda", "float16"
    except Exception:
        pass
    return "cpu", "int8"


def transcrever(caminho_mp3: Path, forcar_cpu: bool = False) -> str:
    global _MODELO
    if _MODELO is None:
        from faster_whisper import WhisperModel

        dispositivo, tipo_calculo = ("cpu", "int8") if forcar_cpu else _dispositivo_whisper()
        print(f"Carregando Whisper ({dispositivo})...", file=sys.stderr)
        _MODELO = WhisperModel("small", device=dispositivo, compute_type=tipo_calculo)
    segmentos, _ = _MODELO.transcribe(str(caminho_mp3), language="pt")
    return " ".join(s.text for s in segmentos)


def tarefas_biblia(slugs_filtro: set | None) -> list[tuple[str, str]]:
    """(caminho relativo dentro da pasta de saida, texto esperado)."""
    tarefas = []
    for caminho in sorted(DIR_BIBLIA.glob("*.json")):
        slug = caminho.stem
        if slugs_filtro and slug not in slugs_filtro:
            continue
        livro = json.loads(caminho.read_text(encoding="utf-8"))
        nome_falado = nome_falado_do_livro(slug, livro["nome"])
        for numero_str, capitulo in livro["capitulos"].items():
            versiculos = capitulo["versiculos"]
            unidades = [versiculos[v] for v in sorted(versiculos, key=int)]
            esperado = f"{nome_falado} Capitulo {numero_str}. " + " ".join(unidades)
            tarefas.append((f"{slug}/{numero_str}.mp3", esperado))
    return tarefas


def tarefas_comentarios(slugs_filtro: set | None) -> list[tuple[str, str]]:
    tarefas = []
    for caminho in sorted(DIR_COMENTARIOS.glob("*.json")):
        slug = caminho.stem
        if slugs_filtro and slug not in slugs_filtro:
            continue
        comentario = json.loads(caminho.read_text(encoding="utf-8"))
        nome_falado = nome_falado_do_livro(slug, comentario["book"])
        for capitulo_str, versiculos in comentario["capitulos"].items():
            for versiculo_str, texto in versiculos.items():
                esperado = (
                    f"Comentario de {nome_falado} Capitulo {capitulo_str} "
                    f"Versiculo {versiculo_str}. {texto}"
                )
                tarefas.append((f"{slug}/{capitulo_str}-{versiculo_str}.mp3", esperado))
    return tarefas


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("tipo", choices=["biblia", "comentarios"])
    parser.add_argument("slugs", nargs="*", help="Livros a validar (vazio = todos)")
    parser.add_argument(
        "--pasta", required=True, help="Pasta com os mp3 ja gerados (ex.: audio_gen_at/biblia)"
    )
    parser.add_argument("--limiar", type=float, default=0.75)
    parser.add_argument(
        "--apagar", action="store_true", help="Apaga os mp3 ruins (sem isso, so reporta)"
    )
    parser.add_argument(
        "--espectros",
        help=(
            "Pasta onde salvar uma miniatura de espectrograma (2s iniciais) de cada mp3 que "
            "passar no teste de texto -- pra bater o olho e pegar artefato (chiado, estatica) "
            "que a transcricao nao pega por nao mudar as palavras reconhecidas."
        ),
    )
    parser.add_argument(
        "--cpu",
        action="store_true",
        help="Forca Whisper em CPU mesmo com GPU disponivel -- use ao validar na mesma sessao/GPU que uma geracao (XTTS-v2) esta usando.",
    )
    args = parser.parse_args()

    pasta = Path(args.pasta)
    if not pasta.is_dir():
        print(f"pasta nao encontrada: {pasta}")
        sys.exit(2)

    slugs_filtro = set(args.slugs) or None
    tarefas = (
        tarefas_biblia(slugs_filtro) if args.tipo == "biblia" else tarefas_comentarios(slugs_filtro)
    )
    existentes = [(rel, esperado) for rel, esperado in tarefas if (pasta / rel).exists()]
    print(f"{len(existentes)}/{len(tarefas)} mp3 ja gerados em {pasta}. Validando...")

    pasta_espectros = Path(args.espectros) if args.espectros else None

    ruins = 0
    for relativo, esperado in existentes:
        caminho_mp3 = pasta / relativo
        transcrito = transcrever(caminho_mp3, forcar_cpu=args.cpu)
        nota = semelhanca(esperado, transcrito)
        # Semelhanca sozinha quase nao cai por causa disso -- um "ponto"
        # falado a mais em meio a um capitulo inteiro apenas arranha a nota.
        # Por isso e uma checagem a parte, que reprova mesmo com nota alta.
        falado = pontuacao_falada(esperado, transcrito)
        if nota < args.limiar or falado:
            ruins += 1
            motivo = f"semelhanca {nota:.0%}"
            if falado:
                motivo += f", falou pontuacao em voz alta: {', '.join(falado)}"
            print(f"RUIM  {relativo}  ({motivo})")
            print(f"      esperado:   {esperado[:120]}")
            print(f"      transcrito: {transcrito[:120]}")
            if args.apagar:
                try:
                    caminho_mp3.unlink()
                except OSError as erro:
                    # Pasta so leitura (ex.: /kaggle/input) -- nao para o
                    # resto da validacao por causa disso, so avisa.
                    print(f"      nao apagou ({erro}) -- pasta so leitura?")
        else:
            print(f"ok    {relativo}  (semelhanca {nota:.0%})")
            if pasta_espectros:
                destino = pasta_espectros / Path(relativo).with_suffix(".png")
                gerar_espectrograma(caminho_mp3, destino)

    print(f"\n{ruins}/{len(existentes)} arquivo(s) abaixo do limiar de {args.limiar:.0%}.")
    if pasta_espectros:
        print(f"Espectrogramas salvos em {pasta_espectros} -- chiado/estatica aparece como energia continua espalhada pela frequencia toda, sem os intervalos que a fala real tem.")
    if ruins and args.apagar:
        print("Apagados -- rode o gerar_*.py correspondente de novo (sem --limpar) para recriar so esses.")
    elif ruins:
        print("Rode de novo com --apagar para apagar e poder regenerar.")
    sys.exit(1 if ruins else 0)


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    main()
