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

/// A ação decisiva de um diálogo ou de uma folha — Salvar, Remover, Criar
/// plano, Aceitar, Entrar (ver Buttons em DESIGN.md). Só uma por tela ou
/// diálogo: o fundo cheio de metal do [FilledButton] é a maior mancha de cor
/// que o sistema permite, e é a exceção nomeada da Regra do Metal — competir
/// com outro botão igual na mesma tela apaga o motivo de ela existir.
class DevocionalBotaoPrimario extends StatelessWidget {
  const DevocionalBotaoPrimario({
    super.key,
    required this.onPressed,
    required Widget this.child,
  }) : icon = null,
       label = null;

  const DevocionalBotaoPrimario.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    final icone = icon;
    final rotulo = label;
    if (icone != null && rotulo != null) {
      return FilledButton.icon(onPressed: onPressed, icon: icone, label: rotulo);
    }
    return FilledButton(onPressed: onPressed, child: child);
  }
}

/// A ação de "abrir alguma coisa" — Continuar leitura, faixa do cronograma,
/// Entrar com Google, Compartilhar, Escolher livros (ver Buttons em
/// DESIGN.md). Fio do metal com letra de destaque, nunca preenchido.
class DevocionalBotaoSecundario extends StatelessWidget {
  const DevocionalBotaoSecundario({
    super.key,
    required this.onPressed,
    required Widget this.child,
  }) : icon = null,
       label = null;

  const DevocionalBotaoSecundario.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    final icone = icon;
    final rotulo = label;
    if (icone != null && rotulo != null) {
      return OutlinedButton.icon(onPressed: onPressed, icon: icone, label: rotulo);
    }
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

/// A ação quieta — Cancelar, Ler tudo, Sair, Exportar (ver Buttons em
/// DESIGN.md). Sem fundo, letra na cor de destaque.
class DevocionalBotaoTerciario extends StatelessWidget {
  const DevocionalBotaoTerciario({
    super.key,
    required this.onPressed,
    required Widget this.child,
  }) : icon = null,
       label = null;

  const DevocionalBotaoTerciario.icon({
    super.key,
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    final icone = icon;
    final rotulo = label;
    if (icone != null && rotulo != null) {
      return TextButton.icon(onPressed: onPressed, icon: icone, label: rotulo);
    }
    return TextButton(onPressed: onPressed, child: child!);
  }
}
