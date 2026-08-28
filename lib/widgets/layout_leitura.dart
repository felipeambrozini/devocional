import 'package:flutter/material.dart';

/// A largura (em px lógicos) a partir da qual a tela conta como larga: barra
/// de navegação vira trilho lateral, a capa cresce e os balões de conversa
/// existem. Um valor só em todo o app — o corte é onde seis rótulos deixam de
/// caber com folga na horizontal (`main.dart`).
const double larguraDeTelaLarga = 720;

bool telaLarga(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= larguraDeTelaLarga;

/// Limita a largura de leitura e centraliza, para a web não esticar texto
/// de ponta a ponta numa janela larga. No celular a tela já é mais estreita
/// que o limite, então nada muda.
class LarguraDeLeitura extends StatelessWidget {
  const LarguraDeLeitura({
    super.key,
    required this.child,
    this.maxWidth = larguraDeTelaLarga,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
