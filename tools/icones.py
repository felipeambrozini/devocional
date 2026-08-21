"""Monta o icone e a splash do app a partir da marca "Devocional" — mesma
fonte e cores do web/og.png — e corrige o que o flutter_launcher_icons deixa
errado.

Rodar da raiz do repositorio, nesta ordem:

    python tools/icones.py --fontes
    dart run flutter_launcher_icons
    python tools/icones.py --corrigir
    python tools/icones.py --splash
    fvm dart run flutter_native_splash:create

O passo --corrigir e' obrigatorio: o gerador copia o icone normal nos
Icon-maskable-*, e o Chrome recorta o maskable em circulo. Ele tambem gera o
favicon em 16px (embaralhado em tela de retina) e nao sabe da variante clara
do favicon (favicon-claro.png).

Sobre o icone que acompanha o tema: o favicon da web troca por
prefers-color-scheme (web/index.html). No Android, o icone adaptativo tambem
troca — a camada de frente (icone_adaptativo.png/icone_adaptativo_escuro.png)
fica transparente e so a cor de fundo por tras (values/values-night
colors.xml) muda, entao o --corrigir precisa copiar a camada escura a mao para
drawable-night-*/, ja que o flutter_launcher_icons 0.14.4 nao gera variante
clara/escura sozinho. `icone_claro.png` fica pronto para quando o iOS 18
tambem tiver uma segunda aparencia configurada.

A splash, ao contrario, troca de cor nos dois temas (flutter_native_splash
suporta `image_dark`), entao --splash gera quatro artes com fundo
transparente — dourado para o tema escuro, bronze para o claro, cada uma em
duas escalas (a base e a recuada para caber no circulo do Android 12+).
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


def _texto(cor, fundo=None, largura_max=None) -> Image.Image:
    """"Devocional" centralizado num quadrado, no maior tamanho que cabe.

    `fundo` None deixa transparente (icone tingido do iOS 18 e splash: o
    sistema/tema pinta a lona atras, entao so a silhueta importa).
    """
    largura_max = largura_max or LARGURA_MAX
    lona = Image.new('RGBA', (LADO, LADO), fundo or (0, 0, 0, 0))
    desenho = ImageDraw.Draw(lona)
    tamanho = 400
    while True:
        fonte = ImageFont.truetype(str(FONTE_TTF), tamanho)
        caixa = desenho.textbbox((0, 0), TEXTO, font=fonte)
        if caixa[2] - caixa[0] <= largura_max:
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

    # Escuro opaco: o fundo vai dentro da propria arte (quadro inteiro) nas
    # camadas que nao podem depender da cor de fundo do sistema — icone
    # principal (Android <26, iOS, splash antigo) e maskable da web.
    escuro = _texto(DOURADO, FUNDO_ESCURO)
    for nome in ('icone.png', 'icone_mascaravel.png'):
        escuro.save(FONTES / nome)
        print(f'{nome}: {LADO}x{LADO}, fundo escuro')

    # Claro: hoje so alimenta o favicon-claro.png (ver --corrigir); fica
    # pronto em assets/icone/ para uma segunda aparencia do launcher, como
    # explica o docstring do modulo.
    claro = _texto(BRONZE, FUNDO_CLARO)
    claro.save(FONTES / 'icone_claro.png')
    print(f'icone_claro.png: {LADO}x{LADO}, fundo claro')

    # Adaptativo do Android: camada de frente transparente, uma por tema — o
    # fundo (values/values-night colors.xml) e' quem muda de cor por tras, e
    # o texto precisa trocar de dourado para bronze junto (dourado sobre
    # pergaminho e' ilegivel, mesmo motivo do modulo lib/theme.dart).
    _texto(BRONZE).save(FONTES / 'icone_adaptativo.png')
    print('icone_adaptativo.png: {0}x{0}, bronze sem fundo (tema claro)'
          .format(LADO))
    _texto(DOURADO).save(FONTES / 'icone_adaptativo_escuro.png')
    print('icone_adaptativo_escuro.png: {0}x{0}, dourado sem fundo (tema escuro)'
          .format(LADO))

    tingido = _cinza(_texto(DOURADO))
    tingido.save(FONTES / 'icone_tingido.png')
    print(f'icone_tingido.png: {LADO}x{LADO}, cinza e sem fundo')


def _fundo_do_icone_no_escuro() -> None:
    """Variante escura do fundo do icone adaptativo do Android."""
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


def splash() -> None:
    """Gera as artes da splash: fundo transparente, cor por tema.

    A base usa a mesma folga do icone (LARGURA_MAX); a variante "_android12"
    e' recuada para caber no circulo que o Android 12+ recorta por cima.
    """
    FONTES.mkdir(parents=True, exist_ok=True)
    recuo_android12 = round(LADO * 0.45)
    for nome, cor in (('splash', BRONZE), ('splash_escuro', DOURADO)):
        _texto(cor).save(FONTES / f'{nome}.png')
        _texto(cor, largura_max=recuo_android12).save(FONTES / f'{nome}_android12.png')
        print(f'{nome}.png / {nome}_android12.png: {LADO}x{LADO}, sem fundo')


def _foreground_noturno() -> None:
    """Copia a camada dourada em cada densidade para drawable-night-*/.

    O flutter_launcher_icons so escreve a camada clara (drawable-*/); sem
    isto o tema escuro do Android usaria o bronze errado por baixo do fundo
    escuro.
    """
    escuro = Image.open(FONTES / 'icone_adaptativo_escuro.png').convert('RGBA')
    base = RAIZ / 'android/app/src/main/res'
    # list() antes do loop: sem isto, as pastas drawable-night-* recem-criadas
    # entram na mesma varredura do glob e viram drawable-night-night-*.
    for claro in list(base.glob('drawable-*/ic_launcher_foreground.png')):
        if claro.parent.name.startswith('drawable-night-'):
            continue
        densidade = claro.parent.name.removeprefix('drawable-')
        lado = Image.open(claro).size[0]
        destino = base / f'drawable-night-{densidade}' / 'ic_launcher_foreground.png'
        destino.parent.mkdir(parents=True, exist_ok=True)
        escuro.resize((lado, lado), Image.LANCZOS).save(destino)
        print(f'{destino.relative_to(RAIZ)}: {lado}x{lado}')


def corrigir() -> None:
    _fundo_do_icone_no_escuro()
    _foreground_noturno()

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
    p.add_argument('--splash', action='store_true',
                    help='monta as artes da splash (dourado/bronze, sem fundo)')
    args = p.parse_args()
    if not (args.fontes or args.corrigir or args.splash):
        p.error('escolha --fontes, --corrigir ou --splash')
    if args.fontes:
        fontes()
    if args.corrigir:
        corrigir()
    if args.splash:
        splash()
