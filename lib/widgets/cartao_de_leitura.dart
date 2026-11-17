import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/estado.dart';
import '../dados/leitura_de_livros.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/capa_biblia.dart';
import '../funcoes/cartao_imagem.dart';
import '../funcoes/citacao.dart';
import '../funcoes/dialogos.dart';
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
    required this.slugDeNota,
    required this.diaDeNota,
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

  /// Onde o favorito e a nota deste texto são guardados: a leitura
  /// (`slugDoDevocional`) e o dia (`diaDoDevocional`).
  final String slugDeNota;
  final int diaDeNota;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);
    final destaque = estado.leituraDeLivros.destaquesDe(
      slugDeNota,
      diaDeNota,
    )[paragrafoDoDevocional];
    final spans = spansDeCitacao(
      dev,
      estiloCitacao: tema.bodyLarge?.copyWith(
        height: 1.7,
        fontStyle: FontStyle.italic,
        color: cor.secondary,
      ),
      estiloReferencia: tema.titleSmall?.copyWith(color: cor.secondary),
      // A epígrafe é a porta do devocional para o texto da King James: tocar na
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
      // O texto vira selecionável e copiável; o Compartilhar fica só no botão
      // do cartão, uma rota única em vez de duas entradas para a mesma ação.
      child: SelectionArea(
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
            // Flexible, não solto: sem largura limitada, a barra de
            // progresso do botão (que preenche a largura disponível durante a
            // leitura) tenta se esticar ao infinito numa Row, e o layout
            // quebra — sumindo com o botão de voz.
            Row(
              children: [
                Flexible(
                  child: DevocionalBotaoDeVoz(
                    chave: vozChave,
                    referencia: vozReferencia,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DevocionalEspacamento.sp14),
            // O texto abre a folha de ações, como um parágrafo dos livros da
            // Biblioteca: favoritar, anotar, copiar e compartilhar a leitura.
            DevocionalParagrafoDeLivro(
              texto: texto,
              destaque: destaque,
              dica: 'Toque para favoritar, anotar, copiar ou compartilhar',
              aoTocar: () => _abrirAcoes(context, estado, destaque),
            ),
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

  /// A folha do texto: favoritar, anotar, copiar e compartilhar a leitura. O
  /// compartilhar mora aqui, e não solto no cartão, junto das outras ações do
  /// texto; favorito com nota não se desmarca (ver
  /// `LeituraDeLivros.alternarDestaque`), então a ação some enquanto há nota.
  Future<void> _abrirAcoes(
    BuildContext context,
    Estado estado,
    DestaqueDeLivro? destaque,
  ) async {
    final leitura = estado.leituraDeLivros;
    final temNota = destaque != null && destaque.nota.isNotEmpty;
    final cor = Theme.of(context).colorScheme;
    final mensageiro = ScaffoldMessenger.of(context);

    final compartilhar = await showModalBottomSheet<bool>(
      context: context,
      builder: (folha) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!temNota)
                ListTile(
                  leading: FaIcon(
                    FontAwesomeIcons.bookmark,
                    color: cor.primary,
                  ),
                  title: Text(
                    destaque == null ? 'Favoritar' : 'Tirar dos favoritos',
                  ),
                  onTap: () async {
                    await leitura.alternarDestaque(
                      slugDeNota,
                      diaDeNota,
                      paragrafoDoDevocional,
                    );
                    if (folha.mounted) Navigator.pop(folha);
                  },
                ),
              ListTile(
                leading: FaIcon(
                  FontAwesomeIcons.penToSquare,
                  color: cor.primary,
                ),
                title: Text(temNota ? 'Editar anotação' : 'Anotar'),
                onTap: () async {
                  final nota = await editarNota(
                    folha,
                    referencia: titulo,
                    notaAtual: destaque?.nota ?? '',
                  );
                  if (nota != null) {
                    await leitura.definirNota(
                      slugDeNota,
                      diaDeNota,
                      paragrafoDoDevocional,
                      nota,
                    );
                  }
                  if (folha.mounted) Navigator.pop(folha);
                },
              ),
              ListTile(
                leading: FaIcon(FontAwesomeIcons.copy, color: cor.primary),
                title: const Text('Copiar'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: texto));
                  if (folha.mounted) Navigator.pop(folha);
                },
              ),
              ListTile(
                leading: FaIcon(
                  FontAwesomeIcons.arrowUpFromBracket,
                  color: cor.primary,
                ),
                title: const Text('Compartilhar'),
                onTap: () => Navigator.pop(folha, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (compartilhar != true) return;

    // A imagem leva só título e citação (o comentário inteiro viraria um
    // cartaz ilegível); o comentário viaja no texto que acompanha, com o link
    // que reabre a leitura.
    final citacao = textoDeCitacao(dev);
    try {
      await compartilharCartao(
        texto: citacao.isEmpty ? '"$titulo"' : '"$citacao"',
        referencia: titulo,
        link: link,
        textoParaAcompanhar: _textoParaCompartilhar,
      );
    } catch (_) {
      mostrarErroNo(mensageiro, 'Não foi possível compartilhar.');
    }
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
