import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

import '../dados/dia_da_leitura.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/nuvem.dart';
import '../dados/planos.dart';
import '../dados/planos_nuvem.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/conclusao_do_plano.dart';
import 'botao.dart';
import 'cartao.dart';
import 'faixa.dart';
import 'filete.dart';
import 'progresso_fino.dart';

/// Os planos personalizados que o usuário já começou e ainda não terminou,
/// para a Hoje: cada um com o próximo dia por ler. Nenhum: não mostra nada.
/// Um só: o cartão. Mais de um: lista horizontal, como em
/// [TabernaculoLivrosEmLeitura].
class TabernaculoPlanosEmAndamento extends StatefulWidget {
  const TabernaculoPlanosEmAndamento({super.key, required this.estado});

  final Estado estado;

  @override
  State<TabernaculoPlanosEmAndamento> createState() =>
      _PlanosEmAndamentoState();
}

class _PlanosEmAndamentoState extends State<TabernaculoPlanosEmAndamento> {
  static const _larguraDoCartao = 320.0;

  final _rolagem = ScrollController();

  @override
  void initState() {
    super.initState();
    // Sem o índice, os devocionais dos planos que os incluem não aparecem.
    unawaited(
      Conteudo.instancia.aquecerIndiceDeDevocionais().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planos = [
      for (final plano in widget.estado.planosParaExibir)
        if (_emAndamento(plano)) plano,
    ];
    if (planos.isEmpty) return const SizedBox.shrink();
    final cartoes = [
      for (final plano in planos)
        _CartaoDoPlanoDeHoje(plano: plano, estado: widget.estado),
    ];
    if (cartoes.length == 1) return cartoes.first;
    // Na web o mouse não arrasta uma rolagem por padrão, e sem a barra nada
    // indica que há mais cartões ao lado.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(dragDevices: {...PointerDeviceKind.values}),
      child: Scrollbar(
        controller: _rolagem,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _rolagem,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: TabernaculoEspacamento.sp12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (indice, cartao) in cartoes.indexed) ...[
                  if (indice > 0)
                    const SizedBox(width: TabernaculoEspacamento.sp8),
                  SizedBox(width: _larguraDoCartao, child: cartao),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  bool _emAndamento(PlanoDoUsuario plano) {
    final lidos = widget.estado.diasLidosDoPlano(plano.id);
    return lidos > 0 && lidos < plano.diasDoPlano.length;
  }
}

class _CartaoDoPlanoDeHoje extends StatelessWidget {
  const _CartaoDoPlanoDeHoje({required this.plano, required this.estado});

  final PlanoDoUsuario plano;
  final Estado estado;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final dias = plano.diasDoPlano;
    final proximo = dias.firstWhere(
      (dia) => !estado.foiLidoNoPlano(plano.id, dia.numero),
      orElse: () => dias.last,
    );
    final lidos = estado.diasLidosDoPlano(plano.id);

    return TabernaculoCartao(
      padding: const EdgeInsets.all(TabernaculoEspacamento.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TabernaculoFilete(),
                    const SizedBox(height: TabernaculoEspacamento.sp12),
                    Text(plano.titulo, style: tema.titleLarge),
                  ],
                ),
              ),
              TabernaculoBotaoDeLido(
                lido: estado.foiLidoNoPlano(plano.id, proximo.numero),
                rotulo: proximo.rotulo,
                aoAlternar: () => _alternar(context, proximo.numero),
              ),
            ],
          ),
          const SizedBox(height: TabernaculoEspacamento.sp8),
          Text(proximo.rotulo, style: tema.bodyLarge),
          const SizedBox(height: TabernaculoEspacamento.sp12),
          Wrap(
            spacing: TabernaculoEspacamento.sp8,
            runSpacing: TabernaculoEspacamento.sp8,
            children: [
              for (final item in proximo.itens)
                switch (item) {
                  ItemDeCapitulo(:final faixa) => TabernaculoBotaoDeFaixa(
                    faixa: faixa,
                    dia: DiaDaLeitura.doPlano(
                      plano.id,
                      proximo.numero,
                      proximo.itens,
                    ),
                  ),
                  ItemDeDevocional(:final tipo, :final chaveDoDia) =>
                    TabernaculoBotaoDeDevocional(
                      tipo: tipo,
                      chaveDoDia: chaveDoDia,
                    ),
                },
            ],
          ),
          const SizedBox(height: TabernaculoEspacamento.sp20),
          const TabernaculoFilete(),
          const SizedBox(height: TabernaculoEspacamento.sp14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TabernaculoEspacamento.sp8,
            runSpacing: TabernaculoEspacamento.sp4,
            children: [
              Text('Progresso do plano', style: tema.labelMedium),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$lidos',
                    style: tema.titleMedium?.copyWith(color: cor.primary),
                  ),
                  const SizedBox(width: TabernaculoEspacamento.sp6),
                  Text('de ${dias.length} dias', style: tema.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: TabernaculoEspacamento.sp8),
          TabernaculoProgressoFino(
            valor: dias.isEmpty ? 0 : (lidos / dias.length).clamp(0.0, 1.0),
          ),
        ],
      ),
    );
  }

  /// Num plano compartilhado o documento da nuvem é a verdade, então marcar
  /// também grava lá — e desfaz o espelho se a gravação falhar, como em
  /// `PlanoControlador.alternarDia`.
  Future<void> _alternar(BuildContext context, int dia) async {
    // Os planos são da conta: sem ela, nada grava (a Hoje nem mostra isto).
    if (!Nuvem.instancia.logado) return;
    // Capturado antes dos awaits: ao marcar o último dia, o cartão sai da Hoje
    // (o plano deixa de estar em andamento) e o contexto deixa de existir.
    final mensageiro = ScaffoldMessenger.of(context);
    void avisarSeConcluiu(bool marcou) {
      if (marcou && planoConcluido(estado, plano)) {
        // O cartão sai da Hoje junto com o foco: mais tempo para o aviso.
        mostrarAvisoNo(
          mensageiro,
          avisoDePlanoConcluido(plano),
          duracao: duracaoDeAvisoAutomatico,
        );
      }
    }

    if (!plano.compartilhado) {
      final marcou = !estado.foiLidoNoPlano(plano.id, dia);
      await estado.alternarLidoNoPlano(plano.id, dia);
      avisarSeConcluiu(marcou);
      return;
    }
    final atual = {
      for (final d in plano.diasDoPlano)
        if (estado.foiLidoNoPlano(plano.id, d.numero)) d.numero,
    };
    final novo = {...atual};
    final marcou = !novo.remove(dia);
    if (marcou) novo.add(dia);
    await estado.substituirLidosDoPlano(plano.id, novo);
    try {
      await PlanosNaNuvem.instancia.gravarDias(plano.id, dia, marcou);
      avisarSeConcluiu(marcou);
    } on PlanosNaNuvemExcecao catch (erro) {
      await estado.substituirLidosDoPlano(plano.id, atual);
      mostrarErroNo(mensageiro, erro.mensagem);
    }
  }
}
