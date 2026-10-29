import 'package:flutter/material.dart';

/// O ponto de foco invisível de uma aba: é para ele que a troca de aba manda
/// o foco do teclado (ver `Moldura._irParaAba` em `main.dart`). Antes o foco
/// caía no primeiro botão da tela, que ganhava o realce de foco sem ninguém
/// ter tocado nele (a lupa do Devocional, o título do capítulo na Bíblia).
///
/// Fora da ordem do Tab: quem navega pelo teclado começa no primeiro
/// controle de verdade. Uma tela com atalhos de teclado põe a sua dentro
/// deles (a Bíblia e o leitor de livro), para a tecla subir a partir daqui e passar por eles.
class DevocionalAncoraDeFoco extends StatefulWidget {
  const DevocionalAncoraDeFoco({super.key, required this.child});

  final Widget child;

  @override
  State<DevocionalAncoraDeFoco> createState() => _DevocionalAncoraDeFocoState();
}

/// Tipo próprio para a troca de aba achar a âncora entre os nós de foco da
/// aba sem depender de rótulo de depuração.
class NoDeAncoraDeFoco extends FocusNode {
  NoDeAncoraDeFoco() : super(debugLabel: 'Âncora de foco', skipTraversal: true);
}

class _DevocionalAncoraDeFocoState extends State<DevocionalAncoraDeFoco> {
  final _no = NoDeAncoraDeFoco();

  @override
  void dispose() {
    _no.dispose();
    super.dispose();
  }

  // Sem semântica: a âncora não é um controle, e o leitor de tela anunciaria
  // um grupo vazio (ou a tela inteira) a cada troca de aba.
  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _no, includeSemantics: false, child: widget.child);
}
