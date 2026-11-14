import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../dados/modelos.dart';
import '../dados/voz.dart';
import '../estilo/espacamento.dart';
import 'abertura_de_livro.dart';
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
    this.aoAbrirCapitulos,
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

  /// Sem o deslize (que é invisível), o título do capítulo no corpo abre a
  /// grade de capítulos num toque.
  final VoidCallback? aoAbrirCapitulos;

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
      itemCount: capitulo.versiculos.length + 1,
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
              Semantics(
                header: true,
                button: aoAbrirCapitulos != null,
                child: aoAbrirCapitulos == null
                    ? Text(capitulo.referencia, style: tema.displayMedium)
                    : Tooltip(
                        // O mesmo atalho da AppBar: a referência no corpo
                        // também abre a grade, e só a AppBar tinha a dica.
                        message: 'Toque para escolher o capítulo',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: aoAbrirCapitulos,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: DevocionalEspacamento.sp4,
                              horizontal: DevocionalEspacamento.sp2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  capitulo.referencia,
                                  style: tema.displayMedium,
                                ),
                                const SizedBox(
                                  width: DevocionalEspacamento.sp8,
                                ),
                                // Grade, não chevron: este título abre a grade
                                // de capítulos do livro, enquanto o da AppBar
                                // (chevron) troca de livro.
                                FaIcon(
                                  FontAwesomeIcons.tableCells,
                                  size: 20,
                                  color: cor.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
