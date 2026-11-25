import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';
import 'caixa_de_citacao.dart';

/// O comentário de Spurgeon abaixo de um versículo, em corpo menor e com o
/// fio do metal à esquerda (como a caixa de citação). Some sem rastro quando
/// o versículo não tem comentário ([texto] nulo); quem decide se o recurso
/// está ligado é o [TabernaculoComentariosDoCapitulo].
class TabernaculoComentarioNoCapitulo extends StatelessWidget {
  const TabernaculoComentarioNoCapitulo({super.key, required this.texto});

  final String? texto;

  @override
  Widget build(BuildContext context) {
    final comentario = texto;
    if (comentario == null) return const SizedBox.shrink();
    final cor = Theme.of(context).colorScheme;
    // container: o leitor de tela anuncia que o trecho é de Spurgeon, e não
    // da Escritura, em vez de fundi-lo ao versículo.
    return Semantics(
      container: true,
      label: 'Comentário no estilo de Spurgeon',
      child: Padding(
        padding: const EdgeInsets.only(top: TabernaculoEspacamento.sp8),
        child: TabernaculoCaixaDeCitacao(
          comFundo: false,
          expandir: true,
          padding: const EdgeInsets.only(left: TabernaculoEspacamento.sp12),
          child: Text(
            comentario,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cor.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
