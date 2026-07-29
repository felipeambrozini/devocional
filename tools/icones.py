"""Monta as fontes do icone do app a partir da foto e corrige o que o
flutter_launcher_icons deixa errado.

Rodar da raiz do repositorio, nesta ordem:

    python tools/icones.py --fontes
    dart run flutter_launcher_icons
    python tools/icones.py --corrigir

O passo --corrigir e' obrigatorio: o gerador copia o icone normal nos
Icon-maskable-*, e o Chrome recorta o maskable em circulo, descartando os 20% de
fora, o que cortaria o topo da cabeca. Ele tambem gera o favicon em 16, que fica
embaracado em tela de retina.
"""

import argparse
import pathlib

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
FOTO = RAIZ / 'assets/images/felipe.png'
FONTES = RAIZ / 'assets/icone'
FUNDO = (0x2E, 0x1B, 0x10, 255)  # Cores.fundo, em lib/theme.dart
LADO = 1024

# Na foto de 535x640 a cabeca ocupa x 159..366 (centro 262) e y 20..320. O
# quadrado pega cabeca, colo e gola, que e' o que ainda se le num favicon.
CENTRO_X = 262
ALTURA = 420


def _rosto() -> Image.Image:
    im = Image.open(FOTO).convert('RGBA')
    return im.crop((CENTRO_X - ALTURA // 2, 0, CENTRO_X + ALTURA // 2, ALTURA))


def _montar(rosto: Image.Image, ocupacao: float, com_fundo: bool) -> Image.Image:
    lona = Image.new('RGBA', (LADO, LADO), FUNDO if com_fundo else (0, 0, 0, 0))
    d = round(LADO * ocupacao)
    # Centralizado na horizontal; na vertical um pouco mais para baixo, senao o
    # queixo cai no meio e sobra vazio embaixo.
    lona.alpha_composite(rosto.resize((d, d), Image.LANCZOS),
                         ((LADO - d) // 2, round((LADO - d) * 0.60)))
    return lona


def fontes() -> None:
    FONTES.mkdir(parents=True, exist_ok=True)
    rosto = _rosto()
    for nome, ocupacao, com_fundo in (
        ('icone.png', 0.88, True),            # iOS, macOS, Windows, Android legado
        ('icone_adaptativo.png', 0.60, False),  # camada de frente do Android
        ('icone_mascaravel.png', 0.60, True),   # maskable da web
    ):
        _montar(rosto, ocupacao, com_fundo).save(FONTES / nome)
        print(f'{nome}: {LADO}x{LADO}, rosto em {ocupacao:.0%}')


def corrigir() -> None:
    mascaravel = Image.open(FONTES / 'icone_mascaravel.png').convert('RGBA')
    for lado in (192, 512):
        destino = RAIZ / f'web/icons/Icon-maskable-{lado}.png'
        mascaravel.resize((lado, lado), Image.LANCZOS).save(destino)
        print(f'{destino.name}: {lado}x{lado}, com folga para o corte circular')

    favicon = RAIZ / 'web/favicon.png'
    Image.open(FONTES / 'icone.png').convert('RGBA') \
        .resize((32, 32), Image.LANCZOS).save(favicon)
    print(f'{favicon.name}: 32x32')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fontes', action='store_true',
                   help='monta assets/icone/ a partir da foto')
    p.add_argument('--corrigir', action='store_true',
                   help='reescreve os maskable e o favicon depois do gerador')
    args = p.parse_args()
    if not (args.fontes or args.corrigir):
        p.error('escolha --fontes ou --corrigir')
    if args.fontes:
        fontes()
    if args.corrigir:
        corrigir()
