import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../estilo/espacamento.dart';

/// Só é montado onde não há gesto de toque; ver `_semGestoDeToque` em
/// `_TelaBibliaState`. No celular deslizar já faz isso, e a barra custava uma
/// faixa do fim de toda tela, logo acima da barra de navegação.
class DevocionalBarraDeCapitulo extends StatelessWidget {
  const DevocionalBarraDeCapitulo({
    super.key,
    required this.podeVoltar,
    required this.podeAvancar,
    required this.aoVoltar,
    required this.aoAvancar,
  });

  final bool podeVoltar;
  final bool podeAvancar;
  final VoidCallback aoVoltar;
  final VoidCallback aoAvancar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DevocionalEspacamento.sp12,
          vertical: DevocionalEspacamento.sp4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Capítulo anterior',
              onPressed: podeVoltar ? aoVoltar : null,
              icon: const FaIcon(FontAwesomeIcons.chevronLeft),
            ),
            IconButton(
              tooltip: 'Próximo capítulo',
              onPressed: podeAvancar ? aoAvancar : null,
              icon: const FaIcon(FontAwesomeIcons.chevronRight),
            ),
          ],
        ),
      ),
    );
  }
}
