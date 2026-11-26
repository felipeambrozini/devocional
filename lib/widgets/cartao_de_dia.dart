import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/modelos.dart';
import '../dados/dia_da_leitura.dart';
import '../estilo/espacamento.dart';
import 'botao.dart';
import 'faixa.dart';

/// Um dia de leitura: número, o que se lê e o botão de marcar como lido.
///
/// O botão tem texto ("Marcar como lido" / "Dia lido"), como o da Biblioteca:
/// o círculo sozinho no canto só dizia o que fazia no tooltip, que não existe
/// no toque. O tooltip continua com o nome do dia para o leitor de tela, porque
/// no cronograma são até 31 botões iguais por mês.
///
/// Serve o cronograma anual (com data e borda dourada no dia de hoje) e os
/// dias dos planos do usuário (uma sequência de 1 a N), porque são a mesma
/// peça de UI.
class TabernaculoCartaoDeDia extends StatelessWidget {
  const TabernaculoCartaoDeDia({
    super.key,
    required this.numero,
    required this.rotulo,
    required this.itens,
    required this.lido,
    required this.aoAlternar,
    this.destacar = false,
    this.dia,
    this.somenteLeitura = false,
  });

  final int numero;
  final String rotulo;
  final List<ItemDoDia> itens;
  final bool lido;

  /// Borda dourada plena, para o dia de hoje se achar de relance dentro de
  /// uma lista de trinta e um cartões parecidos.
  final bool destacar;
  final VoidCallback aoAlternar;

  /// O dia a marcar quando a leitura chega ao fim dele, repassado às faixas
  /// (ver [DiaDaLeitura]).
  final DiaDaLeitura? dia;

  /// Registro de um ano que já passou: o botão de marcar some e o estado de
  /// lido fica só no número e no rótulo. Abrir a leitura continua valendo.
  final bool somenteLeitura;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: destacar ? cor.primary : cor.outline.withValues(alpha: 0.35),
          width: destacar ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TabernaculoEspacamento.sp14,
          TabernaculoEspacamento.sp12,
          TabernaculoEspacamento.sp14,
          TabernaculoEspacamento.sp4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Só leitura: o dia vira um nó só ("Dia 3, 3 de janeiro, lido") em
            // vez de número, rótulo e "Dia lido" soltos; as faixas, que são
            // botões, continuam separadas.
            Semantics(
              label: somenteLeitura
                  ? 'Dia $numero, $rotulo, ${lido ? 'lido' : 'não lido'}'
                  : null,
              excludeSemantics: somenteLeitura,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 34),
                child: Text(
                  '$numero',
                  style: tema.headlineSmall?.copyWith(
                    color: lido ? cor.secondary : cor.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: TabernaculoEspacamento.sp8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    excluding: somenteLeitura,
                    child: Text(
                      rotulo,
                      style: tema.bodyMedium?.copyWith(
                        decoration: lido ? TextDecoration.lineThrough : null,
                        color: lido ? cor.onSurfaceVariant : cor.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: TabernaculoEspacamento.sp10),
                  Wrap(
                    spacing: TabernaculoEspacamento.sp8,
                    runSpacing: TabernaculoEspacamento.sp8,
                    children: [
                      for (final item in itens)
                        switch (item) {
                          ItemDeCapitulo(:final faixa) =>
                            TabernaculoBotaoDeFaixa(faixa: faixa, dia: dia),
                          ItemDeDevocional(:final tipo, :final chaveDoDia) =>
                            TabernaculoBotaoDeDevocional(
                              tipo: tipo,
                              chaveDoDia: chaveDoDia,
                            ),
                        },
                    ],
                  ),
                  const SizedBox(height: TabernaculoEspacamento.sp4),
                  if (somenteLeitura)
                    // A mesma altura lido ou não, para a lista do ano não
                    // ondular conforme os dias lidos.
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: TabernaculoEspacamento.sp8,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 20),
                        child: lido
                            ? ExcludeSemantics(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ExcludeSemantics(
                                      child: FaIcon(
                                        FontAwesomeIcons.circleCheck,
                                        size: 14,
                                        color: cor.secondary,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: TabernaculoEspacamento.sp8,
                                    ),
                                    Text(
                                      'Dia lido',
                                      style: tema.labelLarge?.copyWith(
                                        color: cor.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                      ),
                    )
                  else
                    Tooltip(
                      message: lido
                          ? 'Desmarcar $rotulo'
                          : 'Marcar $rotulo como lido',
                      child: TabernaculoBotaoTerciario.icon(
                        onPressed: aoAlternar,
                        icon: FaIcon(
                          lido
                              ? FontAwesomeIcons.circleCheck
                              : FontAwesomeIcons.circle,
                          size: 14,
                          color: lido ? cor.secondary : null,
                        ),
                        label: Text(
                          lido ? 'Dia lido' : 'Marcar como lido',
                          style: lido ? TextStyle(color: cor.secondary) : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
