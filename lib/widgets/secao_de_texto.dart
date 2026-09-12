import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';

/// Uma seção de texto corrido com título: usada nas telas de Termos de
/// Serviço e Política de Privacidade, que são só uma sequência dessas.
class DevocionalSecaoDeTexto extends StatelessWidget {
  const DevocionalSecaoDeTexto({
    super.key,
    required this.titulo,
    required this.texto,
  });

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: DevocionalEspacamento.sp32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho semântico: sem isto, quem navega por leitor de tela só
          // consegue rolar linearmente por um documento com várias seções,
          // sem pular direto para a que motivou a visita.
          Semantics(
            header: true,
            child: Text(titulo, style: tema.headlineSmall),
          ),
          const SizedBox(height: DevocionalEspacamento.sp10),
          Text(texto, style: tema.bodyLarge?.copyWith(height: 1.7)),
        ],
      ),
    );
  }
}
