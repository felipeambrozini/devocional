import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../controladores/notas_controlador.dart';
import '../dados/estado.dart';
import '../dados/nuvem.dart';
import 'folha_de_ajustes.dart';

/// Botões compartilhados entre telas: cada mudança neles (ícone, cor, texto)
/// acontece uma vez aqui, não em cada tela que precisa de um.

/// Abre a busca. Usado nas telas de leitura (Bíblia e devocional): a mesma
/// lupa, com o mesmo tooltip, sem cada AppBar declarar o próprio IconButton.
class TabernaculoBotaoDeBusca extends StatelessWidget {
  const TabernaculoBotaoDeBusca({super.key, required this.aoBuscar});

  final VoidCallback aoBuscar;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Buscar',
    icon: const FaIcon(FontAwesomeIcons.magnifyingGlass),
    onPressed: aoBuscar,
  );
}

/// Abre os ajustes de leitura e ajuda, na barra de cima de cada aba.
class TabernaculoBotaoDeAjustes extends StatelessWidget {
  const TabernaculoBotaoDeAjustes({super.key, required this.estado});

  final Estado estado;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Ajustes e ajuda',
    icon: FaIcon(
      FontAwesomeIcons.sliders,
      color: Theme.of(context).colorScheme.primary,
    ),
    onPressed: () => ajustesDeLeitura(context, estado),
  );
}

/// Abre o seletor de data. Usado onde a data é navegável, que hoje é só o
/// devocional: sem isto, cada tela com calendário teria o próprio IconButton
/// de elipse-e-item.
class TabernaculoBotaoDeData extends StatelessWidget {
  const TabernaculoBotaoDeData({super.key, required this.aoEscolher});

  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Escolher data',
    icon: const FaIcon(FontAwesomeIcons.calendarDays),
    onPressed: aoEscolher,
  );
}

/// Alterna "lido"/"não lido" de um dia: um círculo vazio enquanto falta ler,
/// preenchido com o check assim que já foi. Usado nos cartões da Hoje (leitura
/// de hoje e planos em andamento); o cartão de um dia do cronograma e dos
/// planos (TabernaculoCartaoDeDia) tem botão com texto.
class TabernaculoBotaoDeLido extends StatelessWidget {
  const TabernaculoBotaoDeLido({
    super.key,
    required this.lido,
    required this.rotulo,
    required this.aoAlternar,
    this.pedeConta = false,
  });

  final bool lido;

  /// O que se lê no dia ("Gênesis 1 a 3"). Entra no tooltip porque o leitor
  /// de tela anuncia o botão sozinho: no cronograma são até 31 iguais por mês.
  final String rotulo;
  final VoidCallback aoAlternar;

  /// Sem conta, o toque só pede para entrar: o tooltip (e o leitor de tela)
  /// avisa antes, em vez de prometer marcar.
  final bool pedeConta;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: rotuloDoBotaoDeLido(
        lido: lido,
        rotulo: rotulo,
        pedeConta: pedeConta,
      ),
      icon: FaIcon(
        lido ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circle,
        color: lido ? cor.secondary : cor.onSurfaceVariant,
      ),
      onPressed: aoAlternar,
    );
  }
}

/// O que o botão de marcar um dia anuncia: o mesmo texto no tooltip da Hoje e
/// no do cronograma.
String rotuloDoBotaoDeLido({
  required bool lido,
  required String rotulo,
  required bool pedeConta,
}) {
  if (lido) return 'Desmarcar $rotulo';
  if (pedeConta) return 'Entre na conta para marcar $rotulo';
  return 'Marcar $rotulo como lido';
}

/// A ação decisiva de um diálogo ou de uma folha — Salvar, Remover, Criar
/// plano, Aceitar, Entrar (ver Buttons em DESIGN.md). Só uma por tela ou
/// diálogo: o fundo cheio de metal do [FilledButton] é a maior mancha de cor
/// que o sistema permite, e é a exceção nomeada da Regra do Metal — competir
/// com outro botão igual na mesma tela apaga o motivo de ela existir.
class TabernaculoBotaoPrimario extends StatelessWidget {
  const TabernaculoBotaoPrimario({
    super.key,
    required this.onPressed,
    required Widget this.child,
  }) : icon = null,
       label = null;

  const TabernaculoBotaoPrimario.icon({
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
      return FilledButton.icon(
        onPressed: onPressed,
        icon: icone,
        label: rotulo,
      );
    }
    return FilledButton(onPressed: onPressed, child: child);
  }
}

/// A ação de "abrir alguma coisa" — Continuar leitura, faixa do cronograma,
/// Entrar com Google, Compartilhar, Escolher livros (ver Buttons em
/// DESIGN.md). Fio do metal com letra de destaque, nunca preenchido.
class TabernaculoBotaoSecundario extends StatelessWidget {
  const TabernaculoBotaoSecundario({
    super.key,
    required this.onPressed,
    required Widget this.child,
  }) : icon = null,
       label = null;

  const TabernaculoBotaoSecundario.icon({
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
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: icone,
        label: rotulo,
      );
    }
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

/// A ação quieta — Cancelar, Ler tudo, Sair, Exportar (ver Buttons em
/// DESIGN.md). Sem fundo, letra na cor de destaque.
class TabernaculoBotaoTerciario extends StatelessWidget {
  const TabernaculoBotaoTerciario({
    super.key,
    required this.onPressed,
    required Widget this.child,
  }) : icon = null,
       label = null;

  const TabernaculoBotaoTerciario.icon({
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

/// Abre as Notas (favoritos e anotações) da aba [origem]. Não é aba: fica na
/// barra de cima do Devocional, da Bíblia e da Biblioteca e abre a tela por
/// cima, só com o que é daquela aba.
class TabernaculoBotaoDeNotas extends StatelessWidget {
  const TabernaculoBotaoDeNotas({super.key, required this.origem});

  final OrigemDasNotas origem;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Nuvem.instancia,
    // Favoritos e notas só existem com conta: sem ela, o ícone some.
    builder: (context, _) => !Nuvem.instancia.logado
        ? const SizedBox.shrink()
        : IconButton(
            tooltip: 'Favoritos e notas: ${origem.rotulo}',
            icon: const FaIcon(FontAwesomeIcons.bookmark),
            onPressed: () => context.push('/notas?aba=${origem.name}'),
          ),
  );
}
