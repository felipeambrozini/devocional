import 'package:flutter/material.dart';
// ScrollCacheExtent ainda não é reexportado por material.dart nesta versão.
import 'package:flutter/rendering.dart';

import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import 'comuns.dart';
import 'faixa.dart';

/// Cronograma anual agrupado por mês, com marcação de lido. São 365 dias, ou 366
/// em ano bissexto, e a tela segue o ano corrente.
class TelaPlano extends StatefulWidget {
  const TelaPlano({super.key, this.hoje});

  /// Só o teste passa data: é o que permite verificar o cronograma bissexto sem
  /// esperar 2028. Em produção fica nulo e vale o relógio.
  final DateTime? hoje;

  @override
  State<TelaPlano> createState() => _TelaPlanoState();
}

class _TelaPlanoState extends State<TelaPlano> {
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

  /// Marca o cartão de hoje na lista, para poder rolar até ele.
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
      duration: const Duration(milliseconds: 300),
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
        duration: const Duration(milliseconds: 350),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    final hoje = _hoje;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de leitura'),
        actions: [
          IconButton(
            tooltip: 'Tamanho do texto e aparência',
            icon: const Icon(Icons.tune),
            onPressed: () => ajustesDeLeitura(context, estado),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (var m = 1; m <= 12; m++)
                  Padding(
                    key: _chavesDeMes[m - 1],
                    padding: const EdgeInsets.only(right: 8),
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
        ),
      ),
      body: LarguraDeLeitura(
        child: CarregaUmaVez<List<DiaDoPlano>>(
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
            if (snap.hasError) return const AvisoDeErro();
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final dias = snap.data!.where((d) => d.mes == _mes).toList();
            final lidosNoMes = dias.where((d) => estado.foiLido(d.data)).length;
            _rolarAteHoje();

            return ListView.separated(
              controller: _rolagem,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              // ponytail: monta o mês inteiro de uma vez em vez de só o visível.
              // São no máximo 31 cartões leves, e é o que faz o cartão de hoje já
              // existir na árvore quando _rolarAteHoje procura por ele; sem isso o
              // GlobalKey de um dia lá embaixo ainda não tem contexto. Se um dia a
              // lista crescer, o caminho é scrollable_positioned_list.
              scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
              itemCount: dias.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '$lidosNoMes de ${dias.length} dias concluídos em ${meses[_mes - 1]}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                }
                final dia = dias[i - 1];
                final ehHoje = dia.mes == hoje.month && dia.dia == hoje.day;
                return _CartaoDoDia(
                  key: ehHoje ? _chaveDeHoje : null,
                  dia: dia,
                  lido: estado.foiLido(dia.data),
                  ehHoje: ehHoje,
                  aoAlternar: () => estado.alternarLido(dia.data),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CartaoDoDia extends StatelessWidget {
  const _CartaoDoDia({
    super.key,
    required this.dia,
    required this.lido,
    required this.ehHoje,
    required this.aoAlternar,
  });

  final DiaDoPlano dia;
  final bool lido;
  final bool ehHoje;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          // O dia de hoje ganha borda dourada plena para se achar de relance
          // dentro de uma lista de trinta e um cartões parecidos.
          color: ehHoje ? cor.primary : cor.outline.withValues(alpha: 0.35),
          width: ehHoje ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${dia.dia}',
                style: tema.headlineSmall?.copyWith(
                  color: lido ? cor.secondary : cor.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dia.rotulo,
                    style: tema.bodyMedium?.copyWith(
                      decoration: lido ? TextDecoration.lineThrough : null,
                      color: lido ? cor.onSurfaceVariant : cor.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in dia.faixas) BotaoDeFaixa(faixa: f),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: lido ? 'Desmarcar' : 'Marcar como lido',
              icon: Icon(
                lido ? Icons.check_circle : Icons.radio_button_unchecked,
                color: lido ? cor.secondary : cor.onSurfaceVariant,
              ),
              onPressed: aoAlternar,
            ),
          ],
        ),
      ),
    );
  }
}
