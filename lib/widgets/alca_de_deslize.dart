import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A alça de arraste na borda esquerda do leitor (mobile): o gradiente e o
/// ícone indicam que deslizar horizontalmente troca de capítulo. O tooltip de
/// primeiro uso só some quando o gesto acontece de verdade (ver
/// `_passarCapituloComDesfazer`). Um toque nela não faz nada: quem desliza
/// usa a tela inteira como alvo, muito maior que os 48px mínimos.
class DevocionalAlcaDeDeslize extends StatelessWidget {
  const DevocionalAlcaDeDeslize({super.key, required this.primeiraVez});

  final bool primeiraVez;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 24,
      child: Tooltip(
        message: primeiraVez ? 'Arraste para trocar capítulo' : '',
        child: Semantics(
          label: primeiraVez ? 'Arraste para trocar capítulo' : '',
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  cor.primary.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.gripVertical,
                size: 20,
                color: cor.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
