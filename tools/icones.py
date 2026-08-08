"""Monta as fontes do icone do app a partir da foto, corrige o que o
flutter_launcher_icons deixa errado e gera a previa de link da web.

Rodar da raiz do repositorio, nesta ordem:

    python tools/icones.py --fontes
    dart run flutter_launcher_icons
    python tools/icones.py --corrigir
    python tools/icones.py --og

O passo --corrigir e' obrigatorio: o gerador copia o icone normal nos
Icon-maskable-*, e o Chrome recorta o maskable em circulo, descartando os 20% de
fora, o que cortaria o topo da cabeca. Ele tambem gera o favicon em 16, que fica
embaracado em tela de retina.

O passo --og monta web/og.png, a imagem de previa quando o link do site e'
colado no WhatsApp, no Instagram ou numa descricao de live (ver og:image em
web/index.html). Nao depende de nada que --corrigir gere; a ordem e' so
para regenerar tudo de uma vez com um comando por linha.

Sobre o icone que acompanha o tema: Android, iOS 18 e o favicon da web trocam.
Windows, macOS e Linux leem um arquivo so e nao tem variante; neles o icone
continua sendo o de fundo escuro, que se vira nos dois temas.

No Android quem faz a troca e' o qualificador -night no fundo do icone
adaptativo, escrito pelo passo --corrigir. Nao confundir com a camada
monocromatica, que e' outra coisa: silhueta chapada, e uma foto de rosto vira o
avatar de "sem foto".
"""

import argparse
import pathlib

from PIL import Image, ImageDraw, ImageFont, ImageOps

RAIZ = pathlib.Path(__file__).resolve().parent.parent
# Fonte em resolucao plena, fora de assets/images/: o app usa uma copia
# redimensionada e em WebP, pequena demais para recortar o icone com qualidade.
FOTO = RAIZ / 'tools/fontes/felipe.png'
FONTES = RAIZ / 'assets/icone'
# Os dois fundos do app, em lib/theme.dart: Cores.fundo e Cores.pergaminho.
FUNDO_ESCURO = (0x2E, 0x1B, 0x10, 255)
FUNDO_CLARO = (0xF7, 0xF1, 0xE3, 255)
# O destaque dourado do tema escuro, em lib/theme.dart.
DOURADO = (0xC9, 0xA2, 0x27, 255)
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
        # Escuro e' o icone de quem le um arquivo so: Windows, macOS, o iOS
        # antigo e o Android anterior ao icone adaptativo. Nesses o fundo marrom
        # se vira nos dois temas. No Android moderno quem manda sao as duas
        # camadas: `icone_adaptativo.png` na frente e a cor por tema atras.
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

    # Telas de abertura, para o flutter_native_splash. Sao sem fundo: quem poe a
    # cor e' a configuracao, e por isso a mesma arte serve ao tema claro e ao
    # escuro. Duas medidas porque o Android 12 mudou o mecanismo.
    #
    # A classica e' centralizada pelo sistema numa lona da cor escolhida.
    _montar(rosto, 0.90, None).resize((640, 640), Image.LANCZOS) \
        .save(FONTES / 'splash.png')
    print('splash.png: 640x640, sem fundo')

    # No Android 12+ quem desenha e' a SplashScreen do sistema, e ela recorta em
    # circulo: sem fundo de icone, a arte vai numa lona de 1152 e precisa caber
    # num circulo de 768 no meio. Os 55% deixam ombro e cabelo dentro do corte
    # com folga; mais que isso e o sistema come as pontas.
    lona12 = Image.new('RGBA', (1152, 1152), (0, 0, 0, 0))
    d = round(1152 * 0.55)
    lona12.alpha_composite(rosto.resize((d, d), Image.LANCZOS),
                           ((1152 - d) // 2, round((1152 - d) * 0.60)))
    lona12.save(FONTES / 'splash_android12.png')
    print('splash_android12.png: 1152x1152, arte dentro do circulo de 768')


def _fundo_do_icone_no_escuro() -> None:
    """Variante escura do fundo do icone adaptativo do Android.

    O `mipmap-anydpi-v26/ic_launcher.xml` aponta o fundo para
    `@color/ic_launcher_background`, e recurso de cor aceita o qualificador
    `-night`. O gerador so escreve `values/colors.xml`, com o valor do pubspec,
    entao a variante escura tem que ser acrescentada depois dele, ou ele a
    apagaria na proxima rodada.

    Funciona porque o lancador resolve o icone com a configuracao dele, que segue
    o modo escuro do sistema. **Verificado num Galaxy, One UI.** Nao e' mecanismo
    documentado pelo Android e pode variar por fabricante; se um dia parar, o
    icone fica no claro, que e' o valor do pubspec.

    Lancadores guardam icone em cache: instalar por cima nao basta para ver a
    mudanca, e o teste pede desinstalar antes.
    """
    destino = RAIZ / 'android/app/src/main/res/values-night/colors.xml'
    destino.parent.mkdir(parents=True, exist_ok=True)
    cor = '#%02X%02X%02X' % FUNDO_ESCURO[:3]
    destino.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        # Sem hifen duplo no comentario: XML nao permite "--" dentro dele, e o
        # merge de recursos do Gradle falha com erro de parser.
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


def og() -> None:
    """Previa de link (Open Graph/Twitter card), 1200x630.

    So existe uma, para o site inteiro: um link direto para um versiculo
    (ver lib/data/canon.dart, alvoDoLink) mostra a mesma imagem generica,
    porque previa por rota exigiria render no servidor, e o GitHub Pages e'
    estatico. Roda depois de --corrigir, mas nao depende dele.

    Sem rosto de proposito: a identidade da web e' neutra (ver CONTINUAR.md),
    e o card de previa e' a peca mais visivel de tudo, a primeira coisa que
    aparece quando o link circula num link do WhatsApp ou do Instagram.
    """
    lona = Image.new('RGBA', (1200, 630), FUNDO_ESCURO)
    desenho = ImageDraw.Draw(lona)

    # Sem rosto disputando espaco, o texto usa o canvas inteiro: mede a
    # largura antes de fixar o tamanho, em vez de chutar um valor que pode
    # cortar nas bordas (foi o que aconteceu com 100px na versao com rosto).
    texto = 'Devocional'
    tamanho = 160
    fonte_ttf = RAIZ / 'assets/fonts/Cinzel-Variable.ttf'
    while True:
        fonte = ImageFont.truetype(str(fonte_ttf), tamanho)
        largura = fonte.getbbox(texto)[2]
        if largura <= 1000:  # 100px de margem de cada lado.
            break
        tamanho -= 4

    desenho.text((600, 315), texto, font=fonte, fill=DOURADO, anchor='mm')

    destino = RAIZ / 'web/og.png'
    lona.convert('RGB').save(destino)
    print(f'{destino.name}: 1200x630, "{texto}" em {tamanho}px, sem rosto')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fontes', action='store_true',
                   help='monta assets/icone/ a partir da foto')
    p.add_argument('--corrigir', action='store_true',
                   help='reescreve os maskable e o favicon depois do gerador')
    p.add_argument('--og', action='store_true',
                   help='monta web/og.png, a previa de link')
    args = p.parse_args()
    if not (args.fontes or args.corrigir or args.og):
        p.error('escolha --fontes, --corrigir ou --og')
    if args.fontes:
        fontes()
    if args.corrigir:
        corrigir()
    if args.og:
        og()
