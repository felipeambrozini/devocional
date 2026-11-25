import 'package:material_ui/material_ui.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import 'widgets.dart';

/// Primeira visita: o retrato, o nome e a fala de boas-vindas da persona, no
/// lugar da lista vazia.
class TabernaculoBoasVindas extends StatelessWidget {
  const TabernaculoBoasVindas({super.key, required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TabernaculoEspacamento.sp32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TabernaculoRetratoDePersona(
              persona: persona,
              tamanho: 92,
              espessuraDoAnel: 2,
              decorativo: true,
            ),
            const SizedBox(height: TabernaculoEspacamento.sp18),
            const TabernaculoFilete(largura: 64),
            const SizedBox(height: TabernaculoEspacamento.sp12),
            Text(persona.nome, style: tema.headlineSmall),
            const SizedBox(height: TabernaculoEspacamento.sp10),
            Text(
              persona.boasVindas,
              textAlign: TextAlign.center,
              style: tema.bodyLarge?.copyWith(
                color: cor.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
