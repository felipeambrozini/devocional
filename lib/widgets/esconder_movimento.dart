import 'package:material_ui/material_ui.dart';

import '../funcoes/movimento.dart';

/// Web: `prefers-reduced-motion: reduce` não chegava ao `MediaQuery`, e as
/// transições de rota e rolagens que leem `disableAnimationsOf` continuavam
/// animadas. Aqui o MediaQuery é sobrescrito uma vez, na raiz, e toda a
/// árvore passa a respeitar a preferência (Android/iOS já a anunciam sozinhos).
class DevocionalEsconderMovimento extends StatelessWidget {
  const DevocionalEsconderMovimento({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!prefereReduzirMovimento) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    );
  }
}
