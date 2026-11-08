import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';

/// O comentário de Spurgeon abaixo de um versículo, em corpo menor e com o
/// fio do metal à esquerda (como a caixa de citação). Some sem rastro quando
/// o versículo não tem comentário ([texto] nulo); quem decide se o recurso
/// está ligado é o [DevocionalComentariosDoCapitulo].
class DevocionalComentarioNoCapitulo extends StatelessWidget {
  const DevocionalComentarioNoCapitulo({super.key, required this.texto});

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
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: DevocionalEspacamento.sp8),
        padding: const EdgeInsets.only(left: DevocionalEspacamento.sp12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: cor.primary, width: 3)),
        ),
        child: Text(
          comentario,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cor.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
