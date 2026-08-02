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

Sobre o icone que acompanha o tema: so o iOS 18 e o favicon da web trocam de
verdade. Android, Windows, macOS e Linux leem um arquivo so, e nenhum deles tem
variante por tema; no Android o unico mecanismo e' a camada monocromatica, que e'
uma silhueta chapada, e uma foto de rosto vira exatamente o avatar de "sem foto".
Por isso nesses o icone continua sendo o de fundo escuro, que se vira nos dois.
"""

import argparse
import pathlib

from PIL import Image, ImageOps

RAIZ = pathlib.Path(__file__).resolve().parent.parent
# Fonte em resolucao plena, fora de assets/images/: o app usa uma copia
# redimensionada e em WebP, pequena demais para recortar o icone com qualidade.
FOTO = RAIZ / 'tools/fontes/felipe.png'
FONTES = RAIZ / 'assets/icone'
# Os dois fundos do app, em lib/theme.dart: Cores.fundo e Cores.pergaminho.
FUNDO_ESCURO = (0x2E, 0x1B, 0x10, 255)
FUNDO_CLARO = (0xF7, 0xF1, 0xE3, 255)
LADO = 1024

# Na foto de 535x640 a cabeca ocupa x 159..366 (centro 262) e y 20..320. O
# quadrado pega cabeca, colo e gola, que e' o que ainda se le num favicon.
CENTRO_X = 262
ALTURA = 420


def _rosto() -> Image.Image:
    im = Image.open(FOTO).convert('RGBA')
    return im.crop((CENTRO_X - ALTURA // 2, 0, CENTRO_X + ALTURA // 2, ALTURA))


def _montar(rosto: Image.Image, ocupacao: float, fundo) -> Image.Image:
    """Poe o rosto numa lona quadrada. `fundo` None deixa transparente."""
    lona = Image.new('RGBA', (LADO, LADO), fundo or (0, 0, 0, 0))
    d = round(LADO * ocupacao)
    # Centralizado na horizontal; na vertical um pouco mais para baixo, senao o
    # queixo cai no meio e sobra vazio embaixo.
    lona.alpha_composite(rosto.resize((d, d), Image.LANCZOS),
                         ((LADO - d) // 2, round((LADO - d) * 0.60)))
    return lona


def _cinza(im: Image.Image) -> Image.Image:
    """Mesma arte em tons de cinza, preservando o recorte."""
    canais = ImageOps.grayscale(im.convert('RGB')).split() * 3
    return Image.merge('RGBA', (*canais, im.split()[3]))


def fontes() -> None:
    FONTES.mkdir(parents=True, exist_ok=True)
    rosto = _rosto()
    for nome, ocupacao, fundo in (
        # Escuro e' o icone universal: Android, Windows, macOS e o iOS antigo
        # leem um arquivo so, e nesses o fundo marrom se vira nos dois temas.
        ('icone.png', 0.88, FUNDO_ESCURO),
        # A variante clara existe so para a aparencia "Any" do iOS 18, que e' a
        # usada quando o aparelho esta no tema claro.
        ('icone_claro.png', 0.88, FUNDO_CLARO),
        ('icone_adaptativo.png', 0.60, None),   # camada de frente do Android
        ('icone_mascaravel.png', 0.60, FUNDO_ESCURO),  # maskable da web
    ):
        _montar(rosto, ocupacao, fundo).save(FONTES / nome)
        marca = 'transparente' if fundo is None else (
            'claro' if fundo == FUNDO_CLARO else 'escuro')
        print(f'{nome}: {LADO}x{LADO}, rosto em {ocupacao:.0%}, fundo {marca}')

    # Tingido do iOS 18: o sistema pinta a arte com a cor que o usuario escolheu,
    # entao ela vai em cinza e sem fundo. Nao ha equivalente nas outras
    # plataformas; e' um modo proprio do iOS, ao lado de claro e escuro.
    tingido = _cinza(_montar(rosto, 0.88, None))
    tingido.save(FONTES / 'icone_tingido.png')
    print(f'icone_tingido.png: {LADO}x{LADO}, cinza e sem fundo')


def corrigir() -> None:
    mascaravel = Image.open(FONTES / 'icone_mascaravel.png').convert('RGBA')
    for lado in (192, 512):
        destino = RAIZ / f'web/icons/Icon-maskable-{lado}.png'
        mascaravel.resize((lado, lado), Image.LANCZOS).save(destino)
        print(f'{destino.name}: {lado}x{lado}, com folga para o corte circular')

    # Dois favicons, um por tema, escolhidos por prefers-color-scheme no
    # index.html. O `favicon.png` sem sufixo continua existindo como reserva
    # para quem ignora o atributo `media` do <link>.
    for origem, destino in (
        ('icone.png', 'web/favicon.png'),
        ('icone.png', 'web/favicon-escuro.png'),
        ('icone_claro.png', 'web/favicon-claro.png'),
    ):
        alvo = RAIZ / destino
        Image.open(FONTES / origem).convert('RGBA') \
            .resize((32, 32), Image.LANCZOS).save(alvo)
        print(f'{alvo.name}: 32x32')


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
