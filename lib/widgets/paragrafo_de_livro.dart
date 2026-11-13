import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../estilo/toque.dart';

/// Um parágrafo do livro. Grifado, ganha o fundo de citação e o fio do metal à
/// esquerda; com nota, a nota aparece embaixo. A faixa à esquerda existe sempre
/// (transparente) para o texto não pular de lugar quando o grifo liga.
class DevocionalParagrafoDeLivro extends StatelessWidget {
  const DevocionalParagrafoDeLivro({
    super.key,
    required this.texto,
    required this.destaque,
    required this.aoTocar,
  });

  final String texto;
  final DestaqueDeLivro? destaque;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final grifado = destaque != null;
    final nota = destaque?.nota ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: DevocionalEspacamento.sp12),
      child: ConstrainedBox(
        // O alvo de uma linha curta ficava abaixo dos 48 dp: o mesmo mínimo da
        // Bíblia vale aqui, inclusive para quem lê com o texto ampliado.
        constraints: const BoxConstraints(minHeight: DevocionalToque.minimo),
        child: Semantics(
          button: true,
          label: grifado ? 'Destacado' : null,
          hint: 'Toque para destacar, anotar ou copiar',
          child: InkWell(
            onTap: aoTocar,
            // Ink e não Container: o fundo do grifo é opaco e, pintado por
            // cima do InkWell, escondia o splash e o foco do teclado.
            child: Ink(
              decoration: BoxDecoration(
                color: grifado ? cor.surfaceContainerHighest : null,
                border: Border(
                  left: BorderSide(
                    color: grifado ? cor.secondary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.fromLTRB(
                  DevocionalEspacamento.sp10,
                  DevocionalEspacamento.sp4,
                  DevocionalEspacamento.sp4,
                  DevocionalEspacamento.sp4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(texto, style: tema.bodyLarge?.copyWith(height: 1.7)),
                    if (nota.isNotEmpty) ...[
                      const SizedBox(height: DevocionalEspacamento.sp8),
                      Text(
                        nota,
                        style: tema.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cor.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
