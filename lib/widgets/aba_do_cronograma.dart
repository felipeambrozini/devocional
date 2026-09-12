import 'dart:async';

import 'package:flutter/material.dart';
// ScrollCacheExtent ainda não é reexportado por material.dart nesta versão.
import 'package:flutter/rendering.dart';

import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/eventos.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/datas.dart';
import '../widgets/widgets.dart';

/// O cronograma anual: a régua de meses e a lista de dias.
///
/// Vive com `AutomaticKeepAliveClientMixin` porque o TabBarView desmonta a
/// aba que sai da tela: sem isto, trocar para Meus Planos e voltar
/// recomeçaria o mês em janeiro e perderia a rolagem.
class DevocionalAbaDoCronograma extends StatefulWidget {
  const DevocionalAbaDoCronograma({super.key, required this.hoje});

  final DateTime? hoje;

  @override
  State<DevocionalAbaDoCronograma> createState() =>
      _DevocionalAbaDoCronogramaState();
}

class _DevocionalAbaDoCronogramaState
    extends State<DevocionalAbaDoCronograma> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Getter, não `late final`: o IndexedStack da moldura mantém esta tela viva
  // indefinidamente (ver main.dart), e um valor fixado na primeira leitura
  // travaria "hoje" no dia em que a tela foi aberta, inclusive na virada do
  // ano. Mesmo raciocínio de `_semGestoDeToque` em `lib/telas/biblia.dart`.
  DateTime get _hoje => widget.hoje ?? DateTime.now();
  late int _mes = _hoje.month;

  final _rolagem = ScrollController();

  /// Uma chave por mês, para a régua rolar até o chip do mês escolhido
  /// (espelho do que `_rolarAteHoje` faz com a lista).
  final _chavesDeMes = List.generate(12, (_) => GlobalKey());

  final _chaveDeHoje = GlobalKey();

  /// Em qual mês a rolagem automática já aconteceu, para não refazê-la a cada
  /// redesenho nem roubar a posição de quem já rolou a lista com a mão.
  int? _mesJaCentralizado;

  @override
  void initState() {
    super.initState();
    // Na abertura, o mês corrente precisa estar à vista na régua: em agosto,
    // o chip de agosto começava fora da tela enquanto a lista já mostrava
    // agosto (a régua sempre abria em janeiro).
    WidgetsBinding.instance.addPostFrameCallback((_) => _centralizarMes());
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  /// Traz o chip do mês selecionado para o centro da régua. A régua é um
  /// SingleChildScrollView próprio, que não rola junto com a lista: sem isto,
  /// escolher dezembro deixava o chip de dezembro fora da tela.
  void _centralizarMes() {
    if (!mounted) return;
    final contexto = _chavesDeMes[_mes - 1].currentContext;
    if (contexto == null) return;
    Scrollable.ensureVisible(
      contexto,
      alignment: 0.5,
      duration: MediaQuery.disableAnimationsOf(contexto)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// A borda dourada acha o dia de hoje de relance, mas no dia 28 ainda são
  /// vinte e sete cartões de rolagem até chegar nele. Aqui a lista abre já
  /// mostrando o dia, e só no mês corrente: nos outros o topo é o certo.
  void _rolarAteHoje() {
    if (_mes != _hoje.month || _mesJaCentralizado == _mes) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alvo = _chaveDeHoje.currentContext;
      if (!mounted || alvo == null) return;
      _mesJaCentralizado = _mes;
      Scrollable.ensureVisible(
        alvo,
        alignment: 0.15,
        duration: MediaQuery.disableAnimationsOf(alvo)
            ? Duration.zero
            : const Duration(milliseconds: 350),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final estado = EscopoDoEstado.de(context);
    final hoje = _hoje;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: DevocionalEspacamento.sp12,
            vertical: DevocionalEspacamento.sp8,
          ),
          child: Row(
            children: [
              for (var m = 1; m <= 12; m++)
                Padding(
                  key: _chavesDeMes[m - 1],
                  padding: const EdgeInsets.only(right: DevocionalEspacamento.sp8),
                  child: ChoiceChip(
                    label: Text(meses[m - 1]),
                    selected: m == _mes,
                    onSelected: (_) {
                      setState(() => _mes = m);
                      _centralizarMes();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: DevocionalLarguraDeLeitura(
            child: DevocionalCarregaUmaVez<List<DiaDoPlano>>(
              // A tela mostra o cronograma do ano corrente, então segue a mesma variante
              // que o resto do app: em ano bissexto, a de 366 dias, com 29 de fevereiro
              // como dia próprio. Sem isto, esta tela mostrava sempre a de 365 e
              // discordava de Hoje e do Devocional a partir de março de um ano bissexto.
              //
              // A chave leva o ano porque é ele que escolhe o arquivo; o mês não, porque a
              // filtragem por mês é feita sobre a lista já carregada.
              chave: 'plano/${hoje.year}',
              carregar: () => Conteudo.instancia.plano(
                bissexto: Conteudo.ehBissexto(hoje.year),
              ),
              construir: (context, snap) {
                if (snap.hasError) return const DevocionalAvisoDeErro();
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final dias = snap.data!.where((d) => d.mes == _mes).toList();
                final lidosNoMes =
                    dias.where((d) => estado.foiLido(d.data)).length;
                _rolarAteHoje();

                return ListView.separated(
                  controller: _rolagem,
                  padding: const EdgeInsets.fromLTRB(
                    DevocionalEspacamento.sp16,
                    DevocionalEspacamento.sp12,
                    DevocionalEspacamento.sp16,
                    DevocionalEspacamento.sp32,
                  ),
                  // Monta o mês inteiro de uma vez em vez de só o visível.
                  // São no máximo 31 cartões leves, e é o que faz o cartão de hoje já
                  // existir na árvore quando _rolarAteHoje procura por ele; sem isso o
                  // GlobalKey de um dia lá embaixo ainda não tem contexto. Se um dia a
                  // lista crescer, o caminho é scrollable_positioned_list.
                  scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
                  itemCount: dias.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: DevocionalEspacamento.sp10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: DevocionalEspacamento.sp6),
                        child: Text(
                          '$lidosNoMes de ${dias.length} dias concluídos em '
                          '${meses[_mes - 1]}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      );
                    }
                    final dia = dias[i - 1];
                    final ehHoje =
                        dia.mes == hoje.month && dia.dia == hoje.day;
                    return DevocionalCartaoDeDia(
                      key: ehHoje ? _chaveDeHoje : null,
                      numero: dia.dia,
                      rotulo: dia.rotulo,
                      itens: [for (final f in dia.faixas) ItemDeCapitulo(f)],
                      lido: estado.foiLido(dia.data),
                      destacar: ehHoje,
                      aoAlternar: () {
                        final estavaLido = estado.foiLido(dia.data);
                        estado.alternarLido(dia.data);
                        if (!estavaLido) unawaited(registrarDiaMarcado());
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
