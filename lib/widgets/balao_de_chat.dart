import 'package:flutter/material.dart';

import '../data/estado.dart';
import '../data/personas.dart';
import '../estilo/spacing.dart';
import 'widgets.dart';

/// Balão circular com o retrato da persona, o botão flutuante do chat.
///
/// Fica pendurado por cima de todas as telas (ver o `builder` em `main.dart`),
/// no canto do próprio dono: Spurgeon à esquerda, Felipe à direita.
class BalaoDeChat extends StatelessWidget {
  const BalaoDeChat({super.key, required this.persona, required this.onTap});

  final Persona persona;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    // O mesmo retrato que serve o polegar no celular (52) se perde na janela
    // do navegador e no tablet: o balão cresce junto com a plataforma, no
    // mesmo limiar largo ([larguraDeTelaLarga]) que o resto do app usa para
    // trocar de moldura.
    final tamanho = MediaQuery.sizeOf(context).width >= larguraDeTelaLarga
        ? 64.0
        : 52.0;
    return ListenableBuilder(
      listenable: EscopoDoEstado.de(context),
      builder: (context, _) {
        final estado = EscopoDoEstado.de(context);
        final primeiraVez = !estado.baloesTooltipDispensado;
        return Tooltip(
          message: 'Conversas com ${persona.nome}',
          child: Semantics(
            button: true,
            label: 'Abrir histórico de conversas com ${persona.nome}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: cor.surfaceContainer,
                  // Chapado, como todo o app: a sombra era a única do sistema inteiro,
                  // e o círculo com sombra flutuava sobre a leitura de Manhã.
                  elevation: 0,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (primeiraVez) {
                        estado.dispensarBalcaoTooltip();
                      }
                      onTap();
                    },
                    child: RetratoDePersona(
                      persona: persona,
                      tamanho: tamanho,
                      folga: Spacing.sp3,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sp4),
                // A placa com o nome curto: o retrato flutuante sem nome era um
                // enigma na primeira visita, quando só o tooltip dizia quem era.
                // Mesmo tom do círculo, para o balão ler como um pendão só, e
                // fio do metal a 45% como as bordas do sistema. Fora da
                // Semantics, para o anúncio do botão não anunciar duas vezes.
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp8,
                      vertical: Spacing.sp3,
                    ),
                    decoration: BoxDecoration(
                      color: cor.surfaceContainer,
                      border: Border.all(
                        color: cor.outline.withValues(alpha: 0.45),
                        width: 1,
                      ),
                      // Cantos quase retos dos elementos recortados do sistema.
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      persona.nomeCurto,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
