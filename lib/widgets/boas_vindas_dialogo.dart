import 'package:flutter/material.dart';

import 'botao.dart';

/// Boas-vindas do primeiro login: apresenta o plano que toda conta ganha.
/// Devolve `true` quando a pessoa pede para ver o plano.
class DevocionalBoasVindasDialogo extends StatelessWidget {
  const DevocionalBoasVindasDialogo({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Bem-vindo ao Devocional!'),
      content: const Text(
        'Que bom ter você aqui. Para começar, sua conta já vem com um plano '
        'especial: A Vida de Jesus em 30 dias. Em um mês você percorre os '
        'quatro evangelhos em harmonia, acompanhando a vida e o ministério '
        'de Jesus dia após dia.\n\n'
        'Você o encontra na aba Plano, em Meus Planos. Ele é fixo: não pode ser '
        'alterado nem excluído.',
      ),
      actions: [
        DevocionalBotaoTerciario(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Depois'),
        ),
        DevocionalBotaoPrimario(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ver o plano'),
        ),
      ],
    );
  }
}
