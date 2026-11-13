import 'package:flutter/material.dart';

/// Uma linha do painel: título, explicação e o interruptor. Com escrita no
/// voo ([salvando]), o switch desabilita e o giro ocupa o lugar do ícone à
/// esquerda — o toque tem resposta na hora, sem parecer morto.
class DevocionalInterruptor extends StatelessWidget {
  const DevocionalInterruptor({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.aoMudar,
    this.salvando = false,
  });

  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> aoMudar;
  final bool salvando;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(titulo),
      subtitle: Text(subtitulo),
      value: valor,
      onChanged: salvando ? null : aoMudar,
      secondary: salvando
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: 'Salvando',
              ),
            )
          : null,
    );
  }
}
