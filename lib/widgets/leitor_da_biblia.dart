import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../dados/modelos.dart';
import '../dados/voz.dart';
import '../estilo/espacamento.dart';
import 'abertura_de_livro.dart';
import 'botao.dart';
import 'botao_de_voz.dart';
import 'comentarios_do_capitulo.dart';
import 'filete.dart';
import 'linha_de_versiculo.dart';

/// A lista rolável de um capítulo: o cabeçalho (abertura do livro, título e
/// voz) e, abaixo dele, um [DevocionalLinhaDeVersiculo] por versículo.
class DevocionalLeitorDaBiblia extends StatelessWidget {
  const DevocionalLeitorDaBiblia({
    super.key,
    required this.capitulo,
    required this.rolagem,
    this.destacar,
    this.alvoDeRolagem,
    this.chaveDoAlvoDeRolagem,
    this.proximo,
    this.aoAvancar,
    this.aoCarregarComentarios,
    required this.selecionados,
    required this.aoAlternarSelecao,
  });

  final Capitulo capitulo;

  /// Versículos marcados para copiar ou compartilhar juntos; ver
  /// [BibliaControlador.selecionados].
  final Set<int> selecionados;
  final ValueChanged<int> aoAlternarSelecao;
  final ScrollController rolagem;
  final (int, int)? destacar;

  /// Versículo para onde rolar ao abrir (o primeiro da faixa pedida). Sempre
  /// nulo no uso comum; só link, nota e busca pedem um versículo exato.
  final int? alvoDeRolagem;
  final GlobalKey? chaveDoAlvoDeRolagem;

  /// O capítulo seguinte por extenso ("Êxodo 1"), para o botão no fim do
  /// texto; nulo em Apocalipse 22. O deslize é invisível para quem chegou
  /// agora e os chevrons do rodapé só existem na web, então o fim do capítulo
  /// precisa dizer para onde se vai.
  final String? proximo;
  final VoidCallback? aoAvancar;

  /// Com um versículo pedido, rola de novo até ele quando os comentários
  /// entram e crescem o conteúdo acima dele.
  final VoidCallback? aoCarregarComentarios;

  @override
  Widget build(BuildContext context) {
    return DevocionalComentariosDoCapitulo(
      livro: capitulo.livro,
      capituloNumero: capitulo.numero,
      construir: _lista,
      aoCarregar: aoCarregarComentarios,
    );
  }

  Widget _lista(BuildContext context, Map<int, String>? comentarios) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;

    return ListView.builder(
      controller: rolagem,
      padding: const EdgeInsets.fromLTRB(
        DevocionalEspacamento.sp20,
        DevocionalEspacamento.sp8,
        DevocionalEspacamento.sp20,
        DevocionalEspacamento.sp32,
      ),
      itemCount: capitulo.versiculos.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O cartão é o único caminho para a introdução, então fica
              // disponível em todo capítulo, não só antes do primeiro.
              DevocionalAberturaDeLivro(slug: capitulo.livro),
              // O título completo do livro só aparece no capítulo 1: é a
              // abertura do livro, não algo para repetir a cada capítulo.
              if (capitulo.numero == 1) ...[
                Text(
                  livroPorSlug(capitulo.livro)!.tituloFormal,
                  style: tema.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cor.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DevocionalEspacamento.sp4),
              ],
              // Título simples: escolher livro e capítulo mora num lugar só,
              // o título da barra de cima. Container: sem ele, o leitor de
              // tela fundia o título com a pílula de ouvir logo abaixo num nó
              // só, cabeçalho e botão ao mesmo tempo.
              Semantics(
                container: true,
                header: true,
                child: Text(capitulo.referencia, style: tema.displayMedium),
              ),
              const SizedBox(height: DevocionalEspacamento.sp8),
              const DevocionalFilete(),
              // A voz de Spurgeon lê o capítulo inteiro, do título ao último
              // versículo; tocar de novo para a leitura.
              const SizedBox(height: DevocionalEspacamento.sp14),
              DevocionalBotaoDeVoz(
                chave: chaveDeCapitulo(capitulo.livro, capitulo.numero),
              ),
              if (capitulo.titulo.isNotEmpty) ...[
                const SizedBox(height: DevocionalEspacamento.sp12),
                Text(
                  capitulo.titulo,
                  style: tema.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cor.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: DevocionalEspacamento.sp16),
            ],
          );
        }

        if (i > capitulo.versiculos.length) {
          final proximo = this.proximo;
          final aoAvancar = this.aoAvancar;
          if (proximo == null || aoAvancar == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: DevocionalEspacamento.sp24),
            child: Center(
              child: DevocionalBotaoSecundario(
                onPressed: aoAvancar,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Próximo: $proximo',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: DevocionalEspacamento.sp8),
                    const FaIcon(FontAwesomeIcons.arrowRight, size: 16),
                  ],
                ),
              ),
            ),
          );
        }

        final (numero, texto) = capitulo.versiculos[i - 1];
        final noRecorte =
            destacar == null ||
            (numero >= destacar!.$1 && numero <= destacar!.$2);

        return DevocionalLinhaDeVersiculo(
          key: chaveDoAlvoDeRolagem != null && numero == alvoDeRolagem
              ? chaveDoAlvoDeRolagem
              : null,
          livro: capitulo.livro,
          capituloNumero: capitulo.numero,
          referencia: capitulo.referencia,
          numero: numero,
          texto: texto,
          comentario: comentarios?[numero],
          falasDivinas: capitulo.falasDivinas[numero] ?? const [],
          noRecorte: noRecorte,
          selecionando: selecionados.isNotEmpty,
          selecionado: selecionados.contains(numero),
          aoAlternarSelecao: () => aoAlternarSelecao(numero),
        );
      },
    );
  }
}
