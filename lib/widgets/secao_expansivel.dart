import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Envolve uma seção de referência (lida uma vez, raramente revisitada) num
/// `ExpansionTile` colapsado por padrão — mesma técnica de
/// `_SecaoDeLembretesExpansivel` em `folha_de_ajustes.dart`, para não exigir
/// rolar por texto estático até chegar em Ajuda e Conta e privacidade.
class DevocionalSecaoExpansivel extends StatelessWidget {
  const DevocionalSecaoExpansivel({
    super.key,
    required this.icone,
    required this.titulo,
    required this.children,
    this.abertaPorPadrao = false,
  });

  final FaIconData icone;
  final String titulo;
  final List<Widget> children;

  /// Só a seção com um CTA interativo (a demonstração de voz) deveria abrir
  /// já expandida — as outras três são texto de crédito, sem ação, e ficam
  /// fechadas como o resto do padrão.
  final bool abertaPorPadrao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        // Mesmo tamanho dos ícones de Ajuda/Conta e privacidade nesta tela
        // (FaIcon sem `size:` explícito) — um `size: 18` menor aqui destoava
        // do resto da tela.
        leading: FaIcon(icone, color: cor.primary),
        initiallyExpanded: abertaPorPadrao,
        // Cabeçalho semântico: sem isto, quem navega por leitor de tela só
        // consegue rolar linearmente, sem pular de seção em seção.
        title: Semantics(
          header: true,
          child: Text(titulo, style: tema.headlineSmall),
        ),
        children: children,
      ),
    );
  }
}
