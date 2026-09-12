import 'package:flutter/material.dart';

import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/alternar_lido.dart';
import 'cartao.dart';
import 'botao.dart';
import 'faixa.dart';
import 'filete.dart';
import 'progresso_fino.dart';

/// Cartão unificado: leitura de hoje + progresso do ano, no estilo devocional.
class DevocionalCartaoLeituraProgresso extends StatelessWidget {
  const DevocionalCartaoLeituraProgresso({
    super.key,
    required this.dia,
    required this.estado,
    required this.ano,
  });

  final DiaDoPlano dia;
  final Estado estado;
  final int ano;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final lido = estado.foiLido(dia.data);
    final total = Conteudo.diasDoAno(ano);
    final progresso = estado.progressoDoAno(total);

    return DevocionalCartao(
      padding: const EdgeInsets.all(DevocionalEspacamento.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com título e ação de marcar como lido
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DevocionalFilete(),
                    const SizedBox(height: DevocionalEspacamento.sp12),
                    Text('Leitura de hoje', style: tema.titleLarge),
                  ],
                ),
              ),
              DevocionalBotaoDeLido(
                lido: lido,
                aoAlternar: () =>
                    alternarLidoComDesfazer(context, estado, dia.data),
              ),
            ],
          ),
          const SizedBox(height: DevocionalEspacamento.sp8),
          // Rótulo do dia (ex: "Dia 1 — Gênesis 1–2")
          Text(dia.rotulo, style: tema.bodyLarge),
          const SizedBox(height: DevocionalEspacamento.sp12),
          // Faixas do dia
          Wrap(
            spacing: DevocionalEspacamento.sp8,
            runSpacing: DevocionalEspacamento.sp8,
            children: [for (final f in dia.faixas) DevocionalBotaoDeFaixa(faixa: f)],
          ),
          const SizedBox(height: DevocionalEspacamento.sp20),
          // DevocionalFilete separador antes do progresso
          const DevocionalFilete(),
          const SizedBox(height: DevocionalEspacamento.sp14),
          // Progresso do ano. Wrap, não Row com Spacer: em largura curta
          // (ou fonte grande, ver a escala de leitura) o contador cai para a
          // linha de baixo em vez de estourar a linha — o Row exigia que
          // rótulo + número + total coubessem lado a lado sempre.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: DevocionalEspacamento.sp8,
            runSpacing: DevocionalEspacamento.sp4,
            children: [
              Text('Progresso do ano', style: tema.labelMedium),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${estado.diasLidos}',
                    style: tema.titleMedium?.copyWith(color: cor.primary),
                  ),
                  const SizedBox(width: DevocionalEspacamento.sp6),
                  Text('de $total dias', style: tema.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: DevocionalEspacamento.sp8),
          // Trilho do tema, fio do metal por cima: o mesmo DevocionalProgressoFino do
          // plano e do cronograma. O `outline` que vivia aqui era papel de
          // borda, não de trilho.
          DevocionalProgressoFino(valor: progresso.clamp(0.0, 1.0)),
        ],
      ),
    );
  }
}
