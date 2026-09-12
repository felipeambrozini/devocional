import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';
import '../telas/chat.dart';

/// A conversa passou do teto de mensagens e as falas mais antigas saíram do
/// histórico. A nota quieta mora no topo da lista, logo abaixo do DevocionalFilete,
/// explicando por que a conversa não começa na primeira pergunta.
///
/// É nota de sistema, não fala da persona: por isso foge da gramática da
/// citação (fio esquerdo de 3) e usa a do chip — fio fechado, tom de cartão
/// dentro de cartão. A mesma caixa com fio à esquerda diria que a Palavra
/// falou, e quem fala aqui é o próprio app.
class DevocionalAvisoDeCorte extends StatelessWidget {
  const DevocionalAvisoDeCorte({super.key});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DevocionalEspacamento.sp14),
      child: Container(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp12),
        decoration: BoxDecoration(
          color: cor.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.outline.withValues(alpha: 0.5)),
        ),
        child: Text(
          avisoDeCorte,
          style: tema.bodySmall?.copyWith(
            color: cor.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
