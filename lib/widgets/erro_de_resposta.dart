import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';

/// O aviso de resposta que não veio, com o motivo e o botão de tentar de
/// novo. Não é parte do histórico: some sozinho dois segundos depois de
/// aparecer, ou antes, quando a próxima tentativa começa.
class DevocionalErroDeResposta extends StatelessWidget {
  const DevocionalErroDeResposta({
    super.key,
    required this.persona,
    required this.mensagem,
    required this.aoTentarDeNovo,
  });

  final Persona persona;
  final String mensagem;

  /// Refaz a última pergunta (o `Conversador` guarda o texto dela).
  final Future<void> Function() aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp4,
        DevocionalEspacamento.sp16,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipOval(
              child: Image.asset(
                // O rosto de quem não respondeu: no chat do Felipe, o erro não
                // pode mostrar o Spurgeon.
                persona.foto,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(width: DevocionalEspacamento.sp8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  DevocionalEspacamento.sp14,
                  DevocionalEspacamento.sp10,
                  DevocionalEspacamento.sp8,
                  DevocionalEspacamento.sp8,
                ),
                decoration: BoxDecoration(
                  color: cor.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(color: cor.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mensagem,
                      style: tema.bodyMedium?.copyWith(
                        color: cor.error,
                        height: 1.4,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => aoTentarDeNovo(),
                      icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 18),
                      label: const Text('Tentar de novo'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DevocionalEspacamento.sp8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
