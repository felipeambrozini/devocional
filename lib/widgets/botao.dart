import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/estado.dart';
import 'folha_de_ajustes.dart';

/// Botões compartilhados entre telas: cada mudança neles (ícone, cor, texto)
/// acontece uma vez aqui, não em cada tela que precisa de um.

/// Abre os ajustes de leitura. Usado onde não há AppBar para pendurar a ação,
/// que hoje é só a tela Hoje.
class DevocionalBotaoDeAjustes extends StatelessWidget {
  const DevocionalBotaoDeAjustes({super.key, required this.estado});

  final Estado estado;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Tamanho do texto e aparência',
    icon: FaIcon(
      FontAwesomeIcons.sliders,
      color: Theme.of(context).colorScheme.primary,
    ),
    onPressed: () => ajustesDeLeitura(context, estado),
  );
}

/// Alterna "lido"/"não lido" de um dia: um círculo vazio enquanto falta ler,
/// preenchido com o check assim que já foi. Usado no cartão de um dia
/// qualquer (DevocionalCartaoDeDia) e na prévia da leitura de hoje.
class DevocionalBotaoDeLido extends StatelessWidget {
  const DevocionalBotaoDeLido({super.key, required this.lido, required this.aoAlternar});

  final bool lido;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: lido ? 'Desmarcar' : 'Marcar como lido',
      icon: FaIcon(
        lido ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circle,
        color: lido ? cor.secondary : cor.onSurfaceVariant,
      ),
      onPressed: aoAlternar,
    );
  }
}
