import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/voz.dart';
import '../estilo/espacamento.dart';
import '../estilo/tema.dart';
import '../funcoes/aviso.dart';
import '../funcoes/cartao_imagem.dart';
import '../funcoes/dialogos.dart';
import 'botao_de_voz.dart';
import 'comentario_no_capitulo.dart';
import 'comentarios_do_capitulo.dart';

/// Um versículo: número, texto e, se houver, a nota. Usado tanto pelo leitor
/// de uma coluna quanto por cada lado do leitor duplo.
class DevocionalLinhaDeVersiculo extends StatelessWidget {
  const DevocionalLinhaDeVersiculo({
    super.key,
    required this.livro,
    required this.capituloNumero,
    required this.referencia,
    required this.numero,
    required this.texto,
    required this.comentario,
    required this.falasDivinas,
    required this.noRecorte,
    required this.selecionando,
    required this.selecionado,
    required this.aoAlternarSelecao,
  });

  final String livro;
  final int capituloNumero;
  final String referencia;
  final int numero;
  final String texto;
  final String? comentario;
  final List<(int, int)> falasDivinas;
  final bool noRecorte;

  /// Há versículos marcados no capítulo: o toque marca em vez de abrir a folha.
  final bool selecionando;
  final bool selecionado;
  final VoidCallback aoAlternarSelecao;

  /// Fora da faixa pedida pelo cronograma o texto continua legível, apenas
  /// recuado, para o contexto não se perder.
  ///
  /// onSurface a 0.75 e não onSurfaceVariant a 0.7: este dava cerca de 3,1:1
  /// no tema claro, abaixo do 4,5:1 que a WCAG AA pede para texto corrido, e
  /// isto aqui é Escritura, não legenda. A fala divina recua menos (0.9): o
  /// vermelho a 0.75 caía para 3,7:1 sobre o fundo de selecionado.
  TextStyle? _estiloDoTrecho(BuildContext context, {required bool divino}) {
    final cor = Theme.of(context).colorScheme;
    final base = divino ? cor.tertiary : cor.onSurface;
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
      height: 1.6,
      color: noRecorte ? base : base.withValues(alpha: divino ? 0.9 : 0.75),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);
    final marcacao = estado.marcacaoDe(livro, capituloNumero, numero);
    final temNota = marcacao != null && marcacao.nota.trim().isNotEmpty;

    // A marcação era só visual (fundo a 18%): quem usa leitor de tela não
    // sabia o que já marcou. O estado vai no rótulo, não só na cor.
    return Semantics(
      label:
          '$referencia:$numero'
          '${marcacao == null ? '' : ', favoritado'}'
          '${temNota ? ', com anotação' : ''}',
      selected: selecionando ? selecionado : marcacao != null,
      hint: selecionando
          ? 'Toque para marcar ou desmarcar'
          : 'Toque para favoritar, anotar ou copiar; toque longo para '
                'selecionar vários',
      child: InkWell(
        // Toque longo é a entrada do modo de seleção; dentro dele, marcar e
        // desmarcar é o toque simples.
        onLongPress: selecionando ? null : aoAlternarSelecao,
        onTap: selecionando
            ? aoAlternarSelecao
            : () => _abrirAcoesDoVersiculo(
                context,
                estado,
                livro: livro,
                capituloNumero: capituloNumero,
                referencia: referencia,
                numero: numero,
                texto: texto,
              ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // 12 e não 7: com bodyLarge em 17 e altura 1.6, um versículo de uma
          // linha ficava em cerca de 41 dp de alvo, abaixo dos 48 dp mínimos.
          // Os curtos são justamente os mais marcados.
          padding: const EdgeInsets.symmetric(
            vertical: DevocionalEspacamento.sp12,
            horizontal: DevocionalEspacamento.sp6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selecionado
                ? cor.primary.withValues(alpha: 0.18)
                : marcacao != null
                ? cor.outline.withValues(alpha: 0.18)
                : null,
            border: selecionado
                ? Border.all(color: cor.primary, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$numero ',
                      style: tema.labelMedium
                          ?.copyWith(color: cor.primary)
                          .comPeso(FontWeight.w700),
                    ),
                    if (marcacao != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: DevocionalEspacamento.sp6,
                          ),
                          child: FaIcon(
                            FontAwesomeIcons.solidBookmark,
                            size: 11,
                            color: cor.primary,
                          ),
                        ),
                      ),
                    for (final (pedaco, divino) in partesDoVersiculo(
                      texto,
                      estado.letraVermelha ? falasDivinas : const [],
                    ))
                      TextSpan(
                        text: pedaco,
                        style: _estiloDoTrecho(context, divino: divino),
                      ),
                  ],
                ),
              ),
              DevocionalComentarioNoCapitulo(texto: comentario),
              if (marcacao != null && marcacao.nota.isNotEmpty) ...[
                const SizedBox(height: DevocionalEspacamento.sp6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.penToSquare,
                      size: 15,
                      color: cor.primary,
                    ),
                    const SizedBox(width: DevocionalEspacamento.sp6),
                    Expanded(
                      child: Text(
                        marcacao.nota,
                        style: tema.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A folha de ações de um versículo: favoritar (com desfazer), copiar,
/// compartilhar e anotar, mais o "Tela cheia" no cabeçalho. Um objeto por
/// abertura: os closures das ações leem o snapshot da marcação feito antes da
/// folha abrir — recalcular dentro dos itens mudaria o que se vê ao tocar.
class _AcoesDoVersiculo {
  const _AcoesDoVersiculo({
    required this.estado,
    required this.livro,
    required this.capituloNumero,
    required this.referencia,
    required this.numero,
    required this.texto,
    required this.marcacao,
    required this.comentario,
  });

  final Estado estado;
  final String livro;
  final int capituloNumero;

  /// Referência do capítulo ("João 3"), sem o número do versículo.
  final String referencia;
  final int numero;
  final String texto;

  /// A marcação como estava na hora em que a folha abriu.
  final Marcacao? marcacao;

  /// Comentário de Spurgeon sobre este versículo, se já escrito. Criado uma
  /// vez antes da folha abrir, para os redesenhos não refazerem o pedido.
  final Future<String?> comentario;

  Widget folha(BuildContext contextoDaFolha) {
    final cor = Theme.of(contextoDaFolha).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DevocionalEspacamento.sp20,
                DevocionalEspacamento.sp20,
                DevocionalEspacamento.sp8,
                DevocionalEspacamento.sp20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$referencia:$numero',
                    style: Theme.of(contextoDaFolha).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp8),
                  Text(
                    texto,
                    style: Theme.of(contextoDaFolha).textTheme.bodyMedium,
                  ),
                  FutureBuilder<String?>(
                    future: comentario,
                    builder: (context, snap) => _comentario(context, cor, snap),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _itemFavoritar(contextoDaFolha, cor),
            // Copiar é o que mais se faz com um versículo, e não existia. Vem
            // antes de anotar porque é a ação sem consequência das três.
            _itemCopiar(contextoDaFolha, cor),
            _itemCompartilhar(contextoDaFolha, cor),
            _itemAnotar(contextoDaFolha),
          ],
        ),
      ),
    );
  }

  Widget _comentario(
    BuildContext context,
    ColorScheme cor,
    AsyncSnapshot<String?> snap,
  ) {
    if (snap.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.only(top: DevocionalEspacamento.sp16),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: 'Carregando',
          ),
        ),
      );
    }
    final texto = snap.data;
    if (texto == null || texto.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DevocionalEspacamento.sp16),
        Text(
          'Comentário de Charles Spurgeon',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: cor.primary)
              .comPeso(FontWeight.w700),
        ),
        const SizedBox(height: DevocionalEspacamento.sp8),
        DevocionalBotaoDeVoz(
          chave: chaveDoComentario(livro, capituloNumero, numero),
          referencia: '$referencia:$numero, comentário',
        ),
        const SizedBox(height: DevocionalEspacamento.sp8),
        Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  ListTile _itemFavoritar(BuildContext folha, ColorScheme cor) {
    return ListTile(
      leading: FaIcon(
        marcacao != null
            ? FontAwesomeIcons.solidBookmark
            : FontAwesomeIcons.bookmark,
        color: cor.primary,
      ),
      title: Text(marcacao != null ? 'Remover dos favoritos' : 'Favoritar'),
      onTap: () {
        final eraFavorito = marcacao != null;
        estado.alternarFavorito(livro, capituloNumero, numero);
        Navigator.pop(folha);
        // Remover é a única ação da folha sem volta, e o mesmo toque que
        // remove oferece o "Desfazer" (o padrão do deslize de capítulo). Com
        // nota o alternarFavorito se recusa a remover (a nota manda, ver
        // estado.dart), e nesse caso não há o que desfazer.
        if (eraFavorito && !estado.ehFavorito(livro, capituloNumero, numero)) {
          final mensageiro = ScaffoldMessenger.of(folha);
          mostrarAvisoNo(
            mensageiro,
            'Removido dos favoritos.',
            rotuloDeAcao: 'Desfazer',
            aoAgir: () =>
                estado.alternarFavorito(livro, capituloNumero, numero),
          );
        }
      },
    );
  }

  ListTile _itemCopiar(BuildContext folha, ColorScheme cor) {
    return ListTile(
      leading: FaIcon(FontAwesomeIcons.copy, color: cor.primary),
      title: const Text('Copiar'),
      onTap: () async {
        final mensageiro = ScaffoldMessenger.of(folha);
        final navegador = Navigator.of(folha);
        await Clipboard.setData(ClipboardData(text: _textoDoVersiculo));
        navegador.pop();
        mostrarAvisoNo(mensageiro, 'Versículo copiado.');
      },
    );
  }

  ListTile _itemCompartilhar(BuildContext folha, ColorScheme cor) {
    return ListTile(
      leading: FaIcon(FontAwesomeIcons.arrowUpFromBracket, color: cor.primary),
      title: const Text('Compartilhar'),
      onTap: () async {
        final navegador = Navigator.of(folha);
        final mensageiro = ScaffoldMessenger.of(folha);
        try {
          // Cartão-imagem com o texto junto: rende no WhatsApp e no
          // Instagram, onde texto puro morre sem rosto. O texto que acompanha
          // é o mesmo de Copiar, com o link que reabre o versículo.
          await compartilharCartao(
            texto: '"$texto"',
            referencia: '$referencia:$numero',
            link: linkDoVersiculo(livro, capituloNumero, numero),
            textoParaAcompanhar: _textoDoVersiculo,
          );
        } catch (_) {
          mostrarErroNo(mensageiro, 'Não foi possível compartilhar.');
        }
        navegador.pop();
      },
    );
  }

  ListTile _itemAnotar(BuildContext folha) {
    return ListTile(
      leading: FaIcon(
        FontAwesomeIcons.penToSquare,
        color: Theme.of(folha).colorScheme.primary,
      ),
      title: Text(
        marcacao?.nota.isNotEmpty == true ? 'Editar anotação' : 'Anotar',
      ),
      onTap: () async {
        final nota = await editarNota(
          folha,
          referencia: '$referencia:$numero',
          notaAtual: marcacao?.nota ?? '',
        );
        if (nota != null) {
          await estado.definirNota(livro, capituloNumero, numero, nota);
        }
        if (folha.mounted) Navigator.pop(folha);
      },
    );
  }

  /// O mesmo texto para Copiar e Compartilhar. O link vale em qualquer
  /// plataforma, não só na web: é assim que quem recebe chega direto ao
  /// versículo, mesmo copiado ou compartilhado do celular numa live.
  String get _textoDoVersiculo => textoCitado(
    texto: texto,
    referencia: '$referencia:$numero',
    link: linkDoVersiculo(livro, capituloNumero, numero),
  );
}

Future<void> _abrirAcoesDoVersiculo(
  BuildContext context,
  Estado estado, {
  required String livro,
  required int capituloNumero,
  required String referencia,
  required int numero,
  required String texto,
}) async {
  final marcacao = estado.marcacaoDe(livro, capituloNumero, numero);
  // A folha abre já e o comentário chega dentro dela: o primeiro toque num
  // livro baixa o arquivo de comentários inteiro (1 MB em Salmos), e esperar
  // por ele antes de abrir deixava o toque sem resposta na web.
  // Com o comentário já junto do texto, a folha não o repete.
  final comentario = comentarioNoTextoAtivo(estado)
      ? Future<String?>.value()
      : Conteudo.instancia.comentario(livro, capituloNumero, numero);
  final acoes = _AcoesDoVersiculo(
    estado: estado,
    livro: livro,
    capituloNumero: capituloNumero,
    referencia: referencia,
    numero: numero,
    texto: texto,
    marcacao: marcacao,
    comentario: comentario,
  );
  await showModalBottomSheet<void>(
    context: context,
    // Quatro ações mais o cabeçalho passam da altura em telas baixas ou em
    // paisagem — mesmo motivo e mesma solução de ajustesDeLeitura, em
    // widgets/folha_de_ajustes.dart: isScrollControlled deixa a folha crescer, e o
    // SingleChildScrollView rola o que não couber em vez de estourar.
    isScrollControlled: true,
    useSafeArea: true,
    builder: acoes.folha,
  );
}
