import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A [AppBar] usada em toda tela do app, com o botão de voltar em Font
/// Awesome em vez do `arrow_back` do Material.
///
/// O AppBar comum decide sozinho, a partir de `ModalRoute.canPop`, se mostra
/// esse botão — e quando mostra, usa sempre o ícone do Material, sem jeito
/// de trocar. Assumir a mesma decisão aqui é o único jeito de pôr o ícone
/// certo nela.
class DevocionalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DevocionalAppBar({super.key, required this.title, this.actions, this.bottom});

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final podeVoltar = ModalRoute.of(context)?.canPop ?? false;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: podeVoltar
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const FaIcon(FontAwesomeIcons.arrowLeft),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      title: title,
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
