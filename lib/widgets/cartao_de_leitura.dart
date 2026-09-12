import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/capa_biblia.dart';
import '../funcoes/citacao.dart';
import '../telas/biblia.dart';
import '../widgets/widgets.dart';

class DevocionalCartaoDeLeitura extends StatelessWidget {
  const DevocionalCartaoDeLeitura({
    super.key,
    required this.titulo,
    required this.dev,
    required this.texto,
    this.capa,
    required this.vozChave,
    required this.vozReferencia,
    required this.link,
  });

  final String titulo;

  /// De onde vêm o(s) versículo(s)-base em destaque.
  final Devocional dev;
  final String texto;

  /// Capa do livro de onde a leitura vem, para dar identidade ao cartão.
  final String? capa;

  /// O que a voz de Spurgeon lê: chave do áudio e referência.
  final String vozChave;
  final String vozReferencia;

  /// Link absoluto da leitura, para o fim do texto de Compartilhar — é como
  /// quem recebe chega direto nela, mesmo fora do app.
  final String link;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final spans = spansDeCitacao(
      dev,
      estiloCitacao: tema.bodyLarge?.copyWith(
        height: 1.7,
        fontStyle: FontStyle.italic,
        color: cor.secondary,
      ),
      estiloReferencia: tema.titleSmall?.copyWith(color: cor.secondary),
      // A epígrafe é a porta do devocional para o texto da BKJ: tocar na
      // referência abre o capítulo com os versículos citados em destaque.
      aoAbrirReferencia: (livro, capitulo, deVersiculo, ateVersiculo) =>
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaBiblia(
                livroInicial: livro.slug,
                capituloInicial: capitulo,
                destacar: (deVersiculo, ateVersiculo),
              ),
            ),
          ),
    );
    return DevocionalCartao(
      padding: const EdgeInsets.all(DevocionalEspacamento.sp20),
      // Igual à Bíblia: o texto vira selecionável e copiável, e "Compartilhar"
      // entra no próprio menu de seleção. Ver DevocionalAreaDeSelecaoComCompartilhar.
      child: DevocionalAreaDeSelecaoComCompartilhar(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (capa != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      capa!,
                      height: alturaCapa(context, 130),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: DevocionalEspacamento.sp14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: tema.headlineMedium),
                      // A citação vem alinhada embaixo do título, não embaixo da
                      // capa, e o nome do livro fica ao lado do fim da citação
                      // (não numa linha própria embaixo), como uma epígrafe
                      // seguida da atribuição. Mais de uma linha no raro dia com
                      // mais de um versículo-base.
                      if (spans.isNotEmpty) ...[
                        const SizedBox(height: DevocionalEspacamento.sp10),
                        Text.rich(TextSpan(children: spans)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DevocionalEspacamento.sp14),
            // A linha dourada só separa a citação do comentário, por isso vem
            // depois dela, não antes.
            const DevocionalFilete(),
            const SizedBox(height: DevocionalEspacamento.sp14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flexible, não solto: sem largura limitada, a barra de
                // progresso do botão (que preenche a largura disponível
                // durante a leitura) tenta se esticar ao infinito numa Row, e
                // o layout quebra — sumindo com o botão de voz e o de
                // compartilhar ao lado.
                Flexible(
                  child: DevocionalBotaoDeVoz(chave: vozChave, referencia: vozReferencia),
                ),
                IconButton(
                  tooltip: 'Compartilhar',
                  icon: FaIcon(
                    FontAwesomeIcons.arrowUpFromBracket,
                    color: cor.primary,
                  ),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: _textoParaCompartilhar),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DevocionalEspacamento.sp14),
            Text(texto, style: tema.bodyLarge?.copyWith(height: 1.7)),
            const SizedBox(height: DevocionalEspacamento.sp8),
            Center(
              child: Image.asset(
                'assets/imagens/assinatura_spurgeon.webp',
                height: 40,
                semanticLabel: 'Assinatura de Charles Spurgeon',
                // A imagem é tinta chapada num tom só, o próprio dourado claro do
                // tema escuro, e sobre pergaminho ela sumiria. Como é de uma cor
                // só, tingir o mesmo arquivo pelo tema resolve, e evita ter duas
                // versões do asset para manter em sincronia.
                color: cor.secondary,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Título, citação e comentário do cartão, terminando no link da leitura —
  /// o mesmo texto que a tela mostra, pronto para sair do app.
  String get _textoParaCompartilhar => [
    titulo,
    textoDeCitacao(dev),
    texto,
    link,
  ].where((parte) => parte.isNotEmpty).join('\n\n');
}
