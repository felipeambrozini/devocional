import 'package:material_ui/material_ui.dart';

import 'botao.dart';

/// Boas-vindas do primeiro login: apresenta o plano que toda conta ganha.
/// Devolve `true` quando a pessoa pede para ver o plano.
class TabernaculoBoasVindasDialogo extends StatelessWidget {
  const TabernaculoBoasVindasDialogo({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      // Sem isto o Android e a web anunciam a rota como "Alerta".
      semanticLabel: 'Boas-vindas ao Tabernáculo',
      title: const Text('Boas-vindas ao Tabernáculo'),
      content: const Text(
        'Sua conta já vem com o plano "A Vida de Jesus em 30 dias": os quatro '
        'evangelhos em harmonia, um trecho por dia.\n\n'
        'Você o encontra na aba Plano, em Meus Planos. Ele é fixo: não pode ser '
        'alterado nem excluído.',
      ),
      actions: [
        TabernaculoBotaoTerciario(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Depois'),
        ),
        TabernaculoBotaoPrimario(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ver o plano'),
        ),
      ],
    );
  }
}
