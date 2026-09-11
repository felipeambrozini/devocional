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
    // Depois de dispensado o gesto, a alça fica sutil (0.22) mas nunca some:
    // é o único lembrete persistente de que o gesto existe. Sem ela, o
    // deslize vira gesto invisível em aparelho sem chevrons.
    final alphaFundo = primeiraVez ? 0.12 : 0.06;
    final alphaIcone = primeiraVez ? 0.5 : 0.22;
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 24,
      child: Tooltip(
        message: 'Deslize para trocar capítulo',
        child: Semantics(
          label: 'Deslize horizontalmente para trocar capítulo',
          hint: primeiraVez
              ? 'Dica: arraste a tela para o lado'
              : 'Gesto já usado, mas continua disponível',
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  cor.primary.withValues(alpha: alphaFundo),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.gripVertical,
                size: primeiraVez ? 20 : 14,
                color: cor.primary.withValues(alpha: alphaIcone),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
