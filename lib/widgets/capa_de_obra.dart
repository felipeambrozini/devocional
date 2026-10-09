import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';
import '../funcoes/capa_biblia.dart';

/// Capa de um livro da biblioteca, na mesma proporção das outras capas do app
/// (3:4). Sem o arquivo da capa ainda, desenha uma capa tipográfica: o título
/// em Cinzel sobre o tom do tema, com a borda dourada.
class DevocionalCapaDeObra extends StatelessWidget {
  const DevocionalCapaDeObra({
    super.key,
    required this.titulo,
    required this.capa,
    this.alturaBase = 104,
  });

  final String titulo;

  /// Caminho da imagem da capa; se o arquivo não existir, desenha a tipográfica.
  final String capa;
  final double alturaBase;

  @override
  Widget build(BuildContext context) {
    final altura = alturaCapa(context, alturaBase);
    final largura = altura * 0.75;

    return Semantics(
      image: true,
      label: 'Capa de $titulo',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          capa,
          height: altura,
          width: largura,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _CapaTipografica(
            titulo: titulo,
            altura: altura,
            largura: largura,
          ),
        ),
      ),
    );
  }
}

class _CapaTipografica extends StatelessWidget {
  const _CapaTipografica({
    required this.titulo,
    required this.altura,
    required this.largura,
  });

  final String titulo;
  final double altura;
  final double largura;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;

    return Container(
      height: altura,
      width: largura,
      padding: const EdgeInsets.all(DevocionalEspacamento.sp8),
      decoration: BoxDecoration(
        color: cor.surfaceContainerHighest,
        border: Border.all(
          color: cor.secondary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          titulo,
          textAlign: TextAlign.center,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: cor.primary),
        ),
      ),
    );
  }
}
