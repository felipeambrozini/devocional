import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

/// A [AppBar] usada em toda tela do app, com o botão de voltar em Font
/// Awesome em vez do `arrow_back` do Material.
///
/// O AppBar comum decide sozinho, a partir de `ModalRoute.canPop`, se mostra
/// esse botão — e quando mostra, usa sempre o ícone do Material, sem jeito
/// de trocar. Assumir a mesma decisão aqui é o único jeito de pôr o ícone
/// certo nela.
class DevocionalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DevocionalAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.voltarPara,
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  /// Para onde o voltar leva quando não há tela embaixo: a de uma rota que
  /// abre por cima das abas e chegou sozinha na pilha, pelo F5 ou por um link
  /// (ver `/ler` em `main.dart`). Sem ele, a tela ficaria sem voltar e sem a
  /// barra de baixo, um beco sem saída.
  final String? voltarPara;

  @override
  Widget build(BuildContext context) {
    final podeVoltar = ModalRoute.of(context)?.canPop ?? false;
    final destino = voltarPara;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: podeVoltar || destino != null
          ? IconButton(
              // Sem tela embaixo, o botão não volta: vai para [voltarPara], e
              // o rótulo diz isso a quem usa leitor de tela.
              tooltip: podeVoltar || destino != '/hoje'
                  ? MaterialLocalizations.of(context).backButtonTooltip
                  : 'Ir para a Hoje',
              icon: const FaIcon(FontAwesomeIcons.arrowLeft),
              onPressed: () => podeVoltar || destino == null
                  ? Navigator.maybePop(context)
                  : context.go(destino),
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
