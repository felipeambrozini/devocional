import 'package:flutter/material.dart';

import '../widgets/layout_leitura.dart';

/// Capa da Bíblia de Estudo Charles Haddon Spurgeon, trocada conforme o tema claro/escuro.
String capaBibliaSpurgeon(BuildContext context) {
  final escuro = Theme.of(context).brightness == Brightness.dark;
  return escuro
      ? 'assets/images/capa_biblia_spurgeon_dark.webp'
      : 'assets/images/capa_biblia_spurgeon_light.webp';
}

/// A mesma altura em pixels lógicos ocupa bem menos da tela num monitor
/// (janela de navegador) do que num celular, então a capa parece pequena mesmo já
/// aumentada. Escala para cima quando a largura disponível passa de 600px.
double alturaCapa(BuildContext context, double base) {
  final largura = MediaQuery.sizeOf(context).width;
  return largura >= larguraDeTelaLarga ? base * 1.4 : base;
}
