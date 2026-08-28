import 'package:flutter/material.dart';

import '../data/personas.dart';
import '../estilo/spacing.dart';

/// O retrato de uma persona num anel do metal — a gramática única dos três
/// pontos que mostram quem fala: as entradas de conversa (a carta da aba
/// Conversas e o topo do histórico), o botão de voz da leitura e o balão
/// flutuante do chat (`chat.dart`). Anel de 1,5 na cor primária, folga entre
/// o anel e a foto, e o corte alinhado ao topo que preserva o cabelo (a foto
/// é mais alta que larga). Sem o asset, a inicial ocupa o lugar.
class RetratoDePersona extends StatelessWidget {
  const RetratoDePersona({
    super.key,
    required this.persona,
    this.tamanho = 38,
    this.folga = Spacing.sp2,
    this.decorativo = false,
  });

  final Persona persona;
  final double tamanho;

  /// A folga entre o anel dourado e a foto: sem ela a foto preenche o círculo
  /// até a borda e o cabelo encosta no aro. As entradas de conversa usam a
  /// apertada; botão de voz e balão usam [Spacing.sp3].
  final double folga;

  /// Dentro de um botão cujo rótulo já diz o que faz, a imagem é enfeite:
  /// fora da árvore de semântica para o leitor de tela não ler duas vezes.
  final bool decorativo;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cor.primary, width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(folga),
        child: ClipOval(
          child: Image.asset(
            persona.foto,
            width: tamanho,
            height: tamanho,
            fit: BoxFit.cover,
            excludeFromSemantics: decorativo,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => Container(
              color: cor.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Text(
                persona.nomeCurto.characters.first,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: cor.primary,
                  fontSize: tamanho * 0.42,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
