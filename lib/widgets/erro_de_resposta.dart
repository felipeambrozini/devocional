import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import 'fala_da_persona.dart';

/// O aviso de resposta que não veio, com o motivo e o botão de tentar de
/// novo. Não é parte do histórico: some sozinho dois segundos depois de
/// aparecer, ou antes, quando a próxima tentativa começa.
class TabernaculoErroDeResposta extends StatelessWidget {
  const TabernaculoErroDeResposta({
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
        TabernaculoEspacamento.sp16,
        TabernaculoEspacamento.sp4,
        TabernaculoEspacamento.sp16,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TabernaculoFalaDaPersona(
          persona: persona,
          padding: const EdgeInsets.fromLTRB(
            TabernaculoEspacamento.sp14,
            TabernaculoEspacamento.sp10,
            TabernaculoEspacamento.sp8,
            TabernaculoEspacamento.sp8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O vermelho fica no ícone, não na letra: sobre o tom da caixa
              // de citação, o `error` do tema escuro não chega a 4,5:1 em
              // texto de corpo, e o ícone diz "erro" sem depender da cor.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: TabernaculoEspacamento.sp2,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.triangleExclamation,
                      size: 16,
                      color: cor.error,
                    ),
                  ),
                  const SizedBox(width: TabernaculoEspacamento.sp8),
                  Flexible(
                    child: Text(
                      mensagem,
                      style: tema.bodyMedium?.copyWith(
                        color: cor.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => aoTentarDeNovo(),
                icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 18),
                label: const Text('Tentar de novo'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TabernaculoEspacamento.sp8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
