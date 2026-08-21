"""Monta o icone do app a partir da marca "Devocional" — mesma fonte e cores
do web/og.png — e corrige o que o flutter_launcher_icons deixa errado.

Rodar da raiz do repositorio, nesta ordem:

    python tools/icones.py --fontes
    dart run flutter_launcher_icons
    python tools/icones.py --corrigir

O passo --corrigir e' obrigatorio: o gerador copia o icone normal nos
Icon-maskable-*, e o Chrome recorta o maskable em circulo. Ele tambem gera o
favicon em 16px (embaralhado em tela de retina) e nao sabe da variante clara
do favicon (favicon-claro.png).

Sobre o icone que acompanha o tema: so o favicon da web troca hoje (por
prefers-color-scheme, em web/index.html). `icone_claro.png` fica pronto em
assets/icone/ para quando o Android/iOS 18 tiverem uma segunda aparencia
configurada — o flutter_launcher_icons 0.14.4 nao gera variante clara/escura/
tingida sozinho, entao essa parte ainda e' manual.
"""

import argparse
import pathlib

from PIL import Image, ImageDraw, ImageFont, ImageOps

RAIZ = pathlib.Path(__file__).resolve().parent.parent
FONTES = RAIZ / 'assets/icone'
FONTE_TTF = RAIZ / 'assets/fonts/Cinzel-Variable.ttf'

# Os dois fundos do app e o par de destaque de cada tema, em lib/theme.dart.
# Dourado sobre pergaminho da 2,1:1 (ilegivel) — por isso o claro usa bronze,
# nao dourado; ver o comentario no topo de Cores.
FUNDO_ESCURO = (0x2E, 0x1B, 0x10, 255)
FUNDO_CLARO = (0xF7, 0xF1, 0xE3, 255)
DOURADO = (0xC9, 0xA2, 0x27, 255)
BRONZE = (0x7A, 0x5C, 0x12, 255)
LADO = 1024
TEXTO = 'Devocional'
# Cabe dentro do circulo de seguranca de ~66% que o recorte "maskable" da web
# usa, sem cortar as pontas do "D" e do "l".
LARGURA_MAX = round(LADO * 0.62)


def _texto(cor, fundo=None) -> Image.Image:
    """"Devocional" centralizado num quadrado, no maior tamanho que cabe.

    `fundo` None deixa transparente (icone tingido do iOS 18: o sistema pinta
    a arte com a cor escolhida, entao so a silhueta importa).
    """
    lona = Image.new('RGBA', (LADO, LADO), fundo or (0, 0, 0, 0))
    desenho = ImageDraw.Draw(lona)
    tamanho = 400
    while True:
        fonte = ImageFont.truetype(str(FONTE_TTF), tamanho)
        caixa = desenho.textbbox((0, 0), TEXTO, font=fonte)
        if caixa[2] - caixa[0] <= LARGURA_MAX:
            break
        tamanho -= 4
    # O anchor "mm" centraliza pela metrica da fonte (que reserva espaco para
    # descendentes como "g"/"j"), nao pela caixa real da tinta — e "Devocional"
    # nao tem nenhum, entao sobra sem embaixo e o texto parece alto demais.
    # Mede a tinta primeiro e desloca para o centro geometrico ficar certo.
    centro = desenho.textbbox((LADO / 2, LADO / 2), TEXTO, font=fonte, anchor='mm')
    ajuste = LADO / 2 - (centro[1] + centro[3]) / 2
    desenho.text((LADO / 2, LADO / 2 + ajuste), TEXTO, font=fonte, fill=cor, anchor='mm')
    return lona


def _cinza(im: Image.Image) -> Image.Image:
    """Mesma arte em tons de cinza, preservando o recorte."""
    canais = ImageOps.grayscale(im.convert('RGB')).split() * 3
    return Image.merge('RGBA', (*canais, im.split()[3]))


def fontes() -> None:
    FONTES.mkdir(parents=True, exist_ok=True)

    # Escuro: o fundo vai dentro da propria arte (opaco, quadro inteiro) nas
    # camadas que nao podem depender da cor de fundo do sistema — adaptativo
    # do Android e maskable da web — assim o fundo claro do pubspec nunca
    # aparece por baixo do texto.
    escuro = _texto(DOURADO, FUNDO_ESCURO)
    for nome in ('icone.png', 'icone_adaptativo.png', 'icone_mascaravel.png'):
        escuro.save(FONTES / nome)
        print(f'{nome}: {LADO}x{LADO}, fundo escuro')

    # Claro: hoje so alimenta o favicon-claro.png (ver --corrigir); fica
    # pronto em assets/icone/ para uma segunda aparencia do launcher, como
    # explica o docstring do modulo.
    claro = _texto(BRONZE, FUNDO_CLARO)
    claro.save(FONTES / 'icone_claro.png')
    print(f'icone_claro.png: {LADO}x{LADO}, fundo claro')

    tingido = _cinza(_texto(DOURADO))
    tingido.save(FONTES / 'icone_tingido.png')
    print(f'icone_tingido.png: {LADO}x{LADO}, cinza e sem fundo')


def _fundo_do_icone_no_escuro() -> None:
    """Variante escura do fundo do icone adaptativo do Android.

    Sem efeito visivel hoje — `icone_adaptativo.png` agora e' opaco e cobre o
    quadro inteiro, entao o fundo do pubspec nunca aparece — mas mantido pelo
    mesmo motivo do original: se um dia o adaptativo voltar a ter
    transparencia, e' aqui que o tema escuro dele mora.
    """
    destino = RAIZ / 'android/app/src/main/res/values-night/colors.xml'
    destino.parent.mkdir(parents=True, exist_ok=True)
    cor = '#%02X%02X%02X' % FUNDO_ESCURO[:3]
    destino.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Gerado por tools/icones.py, passo corrigir. Nao editar a mao. -->\n'
        '<resources>\n'
        f'    <color name="ic_launcher_background">{cor}</color>\n'
        '</resources>\n',
        encoding='utf-8',
    )
    print(f'values-night/colors.xml: fundo do icone {cor} no tema escuro')


def corrigir() -> None:
    _fundo_do_icone_no_escuro()

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
                    help='monta assets/icone/ a partir da marca "Devocional"')
    p.add_argument('--corrigir', action='store_true',
                    help='reescreve os maskable e os favicons depois do gerador')
    args = p.parse_args()
    if not (args.fontes or args.corrigir):
        p.error('escolha --fontes ou --corrigir')
    if args.fontes:
        fontes()
    if args.corrigir:
        corrigir()
