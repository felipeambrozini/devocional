import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';

/// Cartão com título em Cinzel na cor do tema. Repete em quase toda tela.
class TabernaculoCartao extends StatelessWidget {
  const TabernaculoCartao({
    super.key,
    this.titulo,
    this.acessorio,
    required this.child,
    this.padding = const EdgeInsets.all(TabernaculoEspacamento.sp16),
  });

  final String? titulo;
  final Widget? acessorio;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        titulo!,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  ?acessorio,
                ],
              ),
              const SizedBox(height: TabernaculoEspacamento.sp12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
