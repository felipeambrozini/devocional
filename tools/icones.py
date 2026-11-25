"""Monta o icone e a splash do app a partir do desenho do Tabernaculo e
corrige o que o flutter_launcher_icons deixa errado.

O desenho junta as duas coisas que o nome evoca: a tenda do tabernaculo de
Exodo 26 (telhado de coberturas, colunas folheadas a ouro sustentando a
cortina da porta, a candeia acesa la dentro) e o portico de colunas e frontao
do Metropolitan Tabernacle, onde Spurgeon pregava. E' geometria pura, numa
cor so: o mesmo desenho sai dourado sobre couro, bronze sobre pergaminho e em
silhueta para o icone tingido e a splash.

Rodar da raiz do repositorio, nesta ordem:

    python tools/icones.py --fontes
    dart run flutter_launcher_icons
    python tools/icones.py --corrigir
    python tools/icones.py --splash
    fvm dart run flutter_native_splash:create
    python tools/icones.py --marcas

O --marcas gera o que nenhum gerador cobre: os icones de notificacao (web e
barra de status do Android) e a imagem de previa de link, web/og.png.

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
import math
import pathlib

from PIL import Image, ImageDraw, ImageFont, ImageOps

RAIZ = pathlib.Path(__file__).resolve().parent.parent
FONTES = RAIZ / 'assets/icone'
FONTE_TTF = RAIZ / 'assets/fontes/Cinzel-Variable.ttf'

# Os dois fundos do app e o par de destaque de cada tema, em lib/estilo/cores.dart.
# Dourado sobre pergaminho da 2,1:1 (ilegivel) — por isso o claro usa bronze,
# nao dourado; ver o comentario no topo de TabernaculoCores.
FUNDO_ESCURO = (0x2E, 0x1B, 0x10, 255)
FUNDO_CLARO = (0xF7, 0xF1, 0xE3, 255)
DOURADO = (0xC9, 0xA2, 0x27, 255)
BRONZE = (0x7A, 0x5C, 0x12, 255)
LADO = 1024
# Desenha em 4x e reduz: o PIL nao suaviza a borda de poligono.
SUPERAMOSTRA = 4

# Quanto o desenho ocupa: a metade da diagonal da caixa dele (o raio do menor
# circulo que o contem) sobre o lado da lona. Cada recorte pede o seu:
# - QUADRO: icone de quadro inteiro (iOS, Android antigo, favicon), sem
#   recorte redondo;
# - MASCARAVEL: maskable da web, circulo de seguranca de 40% do lado;
# - ADAPTATIVO: camada de frente do Android, que mostra so 66 de 108 dp
#   (circulo de raio ~30%);
# - ANDROID12: splash do Android 12+, cujo circulo corta ainda mais.
QUADRO = 0.40
FAVICON = 0.47
MASCARAVEL = 0.38
ADAPTATIVO = 0.30
ANDROID12 = 0.26


def _curva(p0, p1, p2, passos=24):
    """Pontos de uma curva de Bezier quadratica de p0 a p2."""
    return [
        ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
         (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
        for t in (i / passos for i in range(passos + 1))
    ]


def _retangulo(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def _formas():
    """O desenho, em coordenadas de uma lona de 1024: (poligono, tinta).

    `tinta` False recorta o que ja foi pintado (o vao entre as coberturas).
    A ordem importa: o recorte vem depois do que ele vaza.
    """
    formas = []
    # Telhado da tenda: a cobertura de fora, com a lona caindo nas pontas...
    formas.append((
        [(512, 214)]
        + _curva((512, 214), (340, 330), (150, 452))[1:]
        + [(150, 484), (196, 470), (196, 452), (828, 452), (828, 470),
           (874, 484), (874, 452)]
        + _curva((874, 452), (684, 330), (512, 214))[1:],
        True,
    ))
    # ...um vao, e a cobertura de dentro.
    formas.append((
        _curva((512, 262), (372, 352), (232, 440))
        + _curva((792, 440), (652, 352), (512, 262)),
        False,
    ))
    formas.append((
        _curva((512, 300), (400, 372), (292, 436))
        + _curva((732, 436), (624, 372), (512, 300)),
        True,
    ))
    # Viga
    formas.append((_retangulo(214, 494, 810, 516), True))
    # Colunas, com capitel e base
    for x in (258, 366, 658, 766):
        formas.append((_retangulo(x - 28, 528, x + 28, 546), True))
        formas.append((_retangulo(x - 19, 546, x + 19, 748), True))
        formas.append((_retangulo(x - 28, 748, x + 28, 764), True))
    # A cortina da porta presa nas colunas, abrindo um triangulo que repete o
    # telhado; a direita e' o espelho da esquerda.
    esquerda = (
        [(404, 528), (512, 528)]
        + _curva((512, 528), (452, 600), (420, 676))[1:]
        + _curva((420, 676), (430, 724), (440, 764))[1:]
        + [(404, 764)]
    )
    formas.append((esquerda, True))
    formas.append(([(LADO - x, y) for x, y in esquerda], True))
    # A candeia la dentro: a chama sobre a lamparina de azeite
    formas.append((
        _curva((512, 612), (476, 666), (512, 694))
        + _curva((512, 694), (548, 666), (512, 612))[1:],
        True,
    ))
    formas.append((
        [(466, 706), (558, 706)]
        + _curva((558, 706), (548, 740), (512, 742))[1:]
        + _curva((512, 742), (476, 740), (466, 706))[1:],
        True,
    ))
    # O chao: um degrau
    formas.append((_retangulo(180, 780, 844, 808), True))
    return formas


def _tabernaculo(cor, fundo=None, raio=QUADRO) -> Image.Image:
    """O desenho centralizado num quadrado, no tamanho que cabe em `raio`.

    `fundo` None deixa transparente (camada adaptativa, icone tingido do iOS
    18 e splash: o sistema/tema pinta a lona atras, entao so a silhueta
    importa).
    """
    formas = _formas()
    xs = [x for poligono, _ in formas for x, _ in poligono]
    ys = [y for poligono, _ in formas for _, y in poligono]
    centro_x = (min(xs) + max(xs)) / 2
    centro_y = (min(ys) + max(ys)) / 2
    meia_diagonal = math.hypot(max(xs) - min(xs), max(ys) - min(ys)) / 2
    escala = raio * LADO / meia_diagonal * SUPERAMOSTRA
    grande = LADO * SUPERAMOSTRA

    mascara = Image.new('L', (grande, grande), 0)
    desenho = ImageDraw.Draw(mascara)
    for poligono, tinta in formas:
        pontos = [
            ((x - centro_x) * escala + grande / 2,
             (y - centro_y) * escala + grande / 2)
            for x, y in poligono
        ]
        desenho.polygon(pontos, fill=255 if tinta else 0)

    lona = Image.new('RGBA', (grande, grande), fundo or (0, 0, 0, 0))
    lona.paste(Image.new('RGBA', (grande, grande), cor), (0, 0), mascara)
    return lona.resize((LADO, LADO), Image.LANCZOS)


def _cinza(im: Image.Image) -> Image.Image:
    """Mesma arte em tons de cinza, preservando o recorte."""
    canais = ImageOps.grayscale(im.convert('RGB')).split() * 3
    return Image.merge('RGBA', (*canais, im.split()[3]))


def fontes() -> None:
    FONTES.mkdir(parents=True, exist_ok=True)

    # Escuro opaco: o fundo vai dentro da propria arte (quadro inteiro) nas
    # camadas que nao podem depender da cor de fundo do sistema — icone
    # principal (Android <26, iOS, splash antigo) e maskable da web.
    _tabernaculo(DOURADO, FUNDO_ESCURO).save(FONTES / 'icone.png')
    print(f'icone.png: {LADO}x{LADO}, fundo escuro')
    _tabernaculo(DOURADO, FUNDO_ESCURO, MASCARAVEL).save(
        FONTES / 'icone_mascaravel.png')
    print(f'icone_mascaravel.png: {LADO}x{LADO}, fundo escuro, recuado')

    # Claro: hoje so alimenta o favicon-claro.png (ver --corrigir); fica
    # pronto em assets/icone/ para uma segunda aparencia do launcher, como
    # explica o docstring do modulo.
    claro = _tabernaculo(BRONZE, FUNDO_CLARO)
    claro.save(FONTES / 'icone_claro.png')
    print(f'icone_claro.png: {LADO}x{LADO}, fundo claro')

    # Adaptativo do Android: camada de frente transparente, uma por tema — o
    # fundo (values/values-night colors.xml) e' quem muda de cor por tras, e
    # o texto precisa trocar de dourado para bronze junto (dourado sobre
    # pergaminho e' ilegivel, mesmo motivo do modulo lib/theme.dart).
    _tabernaculo(BRONZE, raio=ADAPTATIVO).save(FONTES / 'icone_adaptativo.png')
    print('icone_adaptativo.png: {0}x{0}, bronze sem fundo (tema claro)'
          .format(LADO))
    _tabernaculo(DOURADO, raio=ADAPTATIVO).save(
        FONTES / 'icone_adaptativo_escuro.png')
    print('icone_adaptativo_escuro.png: {0}x{0}, dourado sem fundo (tema escuro)'
          .format(LADO))

    tingido = _cinza(_tabernaculo(DOURADO))
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

    A base usa a folga do maskable; a variante "_android12" e' recuada para
    caber no circulo que o Android 12+ recorta por cima.
    """
    FONTES.mkdir(parents=True, exist_ok=True)
    for nome, cor in (('splash', BRONZE), ('splash_escuro', DOURADO)):
        _tabernaculo(cor, raio=MASCARAVEL).save(FONTES / f'{nome}.png')
        _tabernaculo(cor, raio=ANDROID12).save(FONTES / f'{nome}_android12.png')
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
    # Em 32 px cada pixel conta: o favicon ocupa o quadro quase inteiro, sem a
    # folga que o icone do lancador guarda para o recorte.
    for cor, fundo, destino in (
        (DOURADO, FUNDO_ESCURO, 'web/favicon.png'),
        (DOURADO, FUNDO_ESCURO, 'web/favicon-escuro.png'),
        (BRONZE, FUNDO_CLARO, 'web/favicon-claro.png'),
    ):
        alvo = RAIZ / destino
        _tabernaculo(cor, fundo, FAVICON).resize((32, 32), Image.LANCZOS).save(alvo)
        print(f'{alvo.name}: 32x32')


def marcas() -> None:
    """O resto da marca: notificacoes e a imagem de previa de link."""
    # Notificacao na web: o navegador mostra o PNG em cor cheia, e o service
    # worker escolhe o do tema espelhado (web/firebase-messaging-sw.js).
    for cor, fundo, destino in (
        (BRONZE, FUNDO_CLARO, 'web/icons/notificacao-tema-claro.png'),
        (DOURADO, FUNDO_ESCURO, 'web/icons/notificacao-tema-escuro.png'),
    ):
        _tabernaculo(cor, fundo, FAVICON).resize((192, 192), Image.LANCZOS) \
            .save(RAIZ / destino)
        print(f'{destino}: 192x192')

    # Barra de status do Android: o sistema so le o alfa e repinta a cor
    # (ver README.md, "Icone unico no Android").
    destino = 'android/app/src/main/res/drawable/ic_lembrete.png'
    _tabernaculo(FUNDO_ESCURO, raio=FAVICON).resize((96, 96), Image.LANCZOS) \
        .save(RAIZ / destino)
    print(f'{destino}: 96x96, so a silhueta')

    # Previa de link (WhatsApp, Instagram): o desenho sobre o nome, em couro.
    largura, altura = 1200, 630
    og = Image.new('RGBA', (largura, altura), FUNDO_ESCURO)
    arte = _tabernaculo(DOURADO, raio=0.46).resize((460, 460), Image.LANCZOS)
    og.alpha_composite(arte, ((largura - 460) // 2, 30))
    desenho = ImageDraw.Draw(og)
    fonte = ImageFont.truetype(str(FONTE_TTF), 92)
    fonte.set_variation_by_axes([700])
    desenho.text((largura / 2, 488), 'Tabernáculo', font=fonte, fill=DOURADO,
                 anchor='mm')
    og.convert('RGB').save(RAIZ / 'web/og.png')
    print(f'web/og.png: {largura}x{altura}')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fontes', action='store_true',
                    help='monta assets/icone/ a partir do desenho do Tabernaculo')
    p.add_argument('--corrigir', action='store_true',
                    help='reescreve os maskable e os favicons depois do gerador')
    p.add_argument('--splash', action='store_true',
                    help='monta as artes da splash (dourado/bronze, sem fundo)')
    p.add_argument('--marcas', action='store_true',
                    help='monta os icones de notificacao e o web/og.png')
    args = p.parse_args()
    if not (args.fontes or args.corrigir or args.splash or args.marcas):
        p.error('escolha --fontes, --corrigir, --splash ou --marcas')
    if args.fontes:
        fontes()
    if args.corrigir:
        corrigir()
    if args.splash:
        splash()
    if args.marcas:
        marcas()
