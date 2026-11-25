import 'package:material_ui/material_ui.dart';

import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import 'carta_de_conversa.dart';

class TabernaculoCartasDeConversa extends StatelessWidget {
  const TabernaculoCartasDeConversa({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(TabernaculoEspacamento.sp16),
      children: [
        Text(
          'Pergunte sobre a Palavra, peça uma aplicação, desabafe.',
          style: tema.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
        ),
        const SizedBox(height: TabernaculoEspacamento.sp16),
        TabernaculoCartaDeConversa(
          persona: personaSpurgeon,
          sobre: 'Sobre a Palavra e a vida',
        ),
        const SizedBox(height: TabernaculoEspacamento.sp16),
        TabernaculoCartaDeConversa(
          persona: personaFelipe,
          sobre: 'Sobre fé e criação de conteúdo',
        ),
      ],
    );
  }
}
