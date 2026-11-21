import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';
import '../telas/busca.dart';

/// Um resultado da busca: de onde é ([titulo], e o [subtitulo] quando há),
/// e o trecho com o [termo] destacado. Serve às duas abas da busca, Bíblia e
/// Devocionais, que só diferem no título e em para onde o toque leva.
class DevocionalItemDeAchado extends StatelessWidget {
  const DevocionalItemDeAchado({
    super.key,
    required this.titulo,
    required this.texto,
    required this.termo,
    required this.aoAbrir,
    this.subtitulo,
  });

  /// "João 3:16" ou "Manhã · 17 de novembro".
  final String titulo;

  /// O título do devocional, em itálico abaixo; nulo ou vazio some.
  final String? subtitulo;
  final String texto;
  final String termo;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final subtitulo = this.subtitulo;
    return InkWell(
      onTap: aoAbrir,
      // 12 como no destaque de versículo: 8 está fora da escala do DESIGN.md.
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: DevocionalEspacamento.sp4,
          horizontal: DevocionalEspacamento.sp4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: tema.titleSmall?.copyWith(color: cor.secondary),
            ),
            if (subtitulo != null && subtitulo.isNotEmpty) ...[
              const SizedBox(height: DevocionalEspacamento.sp2),
              Text(
                subtitulo,
                style: tema.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: cor.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: DevocionalEspacamento.sp4),
            Text.rich(
              destacar(texto, termo, tema, cor),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
