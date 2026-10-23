"""Converte o render de uma capa (PNG sobre fundo branco) em WebP 225x300 com fundo transparente.

Uso: python tools/capa_para_webp.py <png> <slug>   (grava assets/imagens/capa_<slug>.webp)

O fundo é o que se liga à borda da imagem e é claro e sem cor; a sombra de contato sai junto.
O livro é recortado rente e encaixado em 225x300, como as outras capas.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

DESTINO = Path(__file__).resolve().parent.parent / "assets" / "imagens"
LARGURA, ALTURA = 225, 300
BRILHO_MINIMO_DO_FUNDO = 130
SATURACAO_MAXIMA_DO_FUNDO = 22


def mascara_do_livro(rgb: np.ndarray) -> np.ndarray:
    claro_e_sem_cor = (rgb.min(axis=2) >= BRILHO_MINIMO_DO_FUNDO) & (
        rgb.max(axis=2).astype(int) - rgb.min(axis=2) <= SATURACAO_MAXIMA_DO_FUNDO
    )
    rotulos, _ = ndimage.label(claro_e_sem_cor)
    borda = np.unique(np.concatenate([rotulos[0], rotulos[-1], rotulos[:, 0], rotulos[:, -1]]))
    fundo = np.isin(rotulos, borda[borda > 0])
    livro = ndimage.binary_opening(~fundo, structure=np.ones((5, 5)))
    rotulos, quantidade = ndimage.label(livro)
    maior = np.argmax(ndimage.sum(livro, rotulos, range(1, quantidade + 1))) + 1
    return ndimage.binary_fill_holes(rotulos == maior)


def converter(origem: Path, slug: str) -> Path:
    imagem = Image.open(origem).convert("RGB")
    livro = mascara_do_livro(np.array(imagem))
    recuada = ndimage.binary_erosion(livro, iterations=1)
    alfa = ndimage.gaussian_filter(recuada.astype(float), 0.8)
    rgba = imagem.convert("RGBA")
    rgba.putalpha(Image.fromarray((alfa * 255).astype(np.uint8)))
    rgba = rgba.crop(rgba.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    escala = min(ALTURA / rgba.height, LARGURA / rgba.width)
    rgba = rgba.resize((round(rgba.width * escala), round(rgba.height * escala)), Image.LANCZOS)
    tela = Image.new("RGBA", (LARGURA, ALTURA), (0, 0, 0, 0))
    tela.paste(rgba, ((LARGURA - rgba.width) // 2, (ALTURA - rgba.height) // 2))
    saida = DESTINO / f"capa_{slug}.webp"
    tela.save(saida, "WEBP", quality=82, method=6, alpha_quality=90)
    return saida


if __name__ == "__main__":
    print(converter(Path(sys.argv[1]), sys.argv[2]))
