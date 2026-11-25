import 'package:material_ui/material_ui.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import 'caixa_de_citacao.dart';
import 'retrato_de_persona.dart';

/// O que a persona diz no chat: a foto pequena, rente à base, e a fala na
/// caixa de citação. Um só desenho para a resposta, o "pensando" e o aviso de
/// resposta que não veio, para o rodapé não parecer elemento diferente das
/// mensagens.
class TabernaculoFalaDaPersona extends StatelessWidget {
  const TabernaculoFalaDaPersona({
    super.key,
    required this.persona,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: TabernaculoEspacamento.sp14,
      vertical: TabernaculoEspacamento.sp10,
    ),
    this.larguraMaxima = double.infinity,
  });

  /// De quem é a fala: no chat do Felipe, nem o erro pode mostrar o Spurgeon.
  final Persona persona;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Teto da caixa, para a linha não se esticar numa janela larga.
  final double larguraMaxima;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // O rótulo de quem fala vem do contexto (a lista do chat, o
        // "está respondendo"): a foto é enfeite.
        TabernaculoRetratoDePersona(
          persona: persona,
          tamanho: 28,
          anel: false,
          decorativo: true,
        ),
        const SizedBox(width: TabernaculoEspacamento.sp8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: larguraMaxima),
            child: TabernaculoCaixaDeCitacao(padding: padding, child: child),
          ),
        ),
      ],
    );
  }
}
