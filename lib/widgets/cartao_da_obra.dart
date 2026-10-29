import 'package:flutter/material.dart';

import '../dados/biblioteca.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import 'capa_de_obra.dart';
import 'carrega_uma_vez.dart';
import 'progresso_fino.dart';

/// Cartão de um livro da biblioteca: capa, título, subtítulo e quanto já foi
/// lido. Serve à estante e ao destaque "continuar lendo" da Hoje.
class DevocionalCartaoDaObra extends StatelessWidget {
  const DevocionalCartaoDaObra({
    super.key,
    required this.obra,
    required this.aoAbrir,
    this.compacto = false,
  });

  final ObraDaBiblioteca obra;
  final VoidCallback? aoAbrir;

  /// Sem o subtítulo e com o título em até duas linhas: cabe numa lista
  /// horizontal de altura fixa.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final leitura = EscopoDoEstado.de(context).leituraDeLivros;
    final lidos = leitura.quantosLidos(obra.slug);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoAbrir,
        child: Padding(
          padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
          child: Row(
            children: [
              // O título ao lado já nomeia a obra: a capa falada duplicaria.
              ExcludeSemantics(
                child: DevocionalCapaDeObra(
                  titulo: obra.titulo,
                  capa: obra.capa,
                ),
              ),
              const SizedBox(width: DevocionalEspacamento.sp14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obra.titulo,
                      style: compacto ? tema.titleMedium : tema.titleLarge,
                      maxLines: compacto ? 2 : null,
                      overflow: compacto ? TextOverflow.ellipsis : null,
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp4),
                    if (!compacto) ...[
                      Text(obra.subtitulo, style: tema.bodySmall),
                      const SizedBox(height: DevocionalEspacamento.sp12),
                    ],
                    DevocionalCarregaUmaVez<List<CapituloDoLivro>?>(
                      chave: obra.slug,
                      carregar: () => Biblioteca.instancia.capitulos(obra.slug),
                      construir: (context, snap) {
                        final total = snap.data?.length ?? 0;
                        if (total == 0) return const SizedBox.shrink();
                        return _Progresso(
                          lidos: lidos,
                          total: total,
                          comecou: leitura.posicaoDe(obra.slug) != null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progresso extends StatelessWidget {
  const _Progresso({
    required this.lidos,
    required this.total,
    required this.comecou,
  });

  final int lidos;
  final int total;
  final bool comecou;

  @override
  Widget build(BuildContext context) {
    final legenda = lidos > 0
        ? '$lidos de $total capítulos lidos'
        : comecou
        ? 'Leitura começada'
        : '$total capítulos';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trilho vazio num livro não aberto lia como "0% feito": só aparece
        // quando há o que medir.
        if (lidos > 0) ...[
          DevocionalProgressoFino(valor: lidos / total),
          const SizedBox(height: DevocionalEspacamento.sp6),
        ],
        Text(legenda, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
