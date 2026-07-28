import 'package:flutter/material.dart';

import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'comuns.dart';
import 'faixa.dart';

/// Cronograma anual: os 365 dias, agrupados por mês, com marcação de lido.
class TelaPlano extends StatefulWidget {
  const TelaPlano({super.key});

  @override
  State<TelaPlano> createState() => _TelaPlanoState();
}

class _TelaPlanoState extends State<TelaPlano> {
  int _mes = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    final hoje = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de leitura'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (var m = 1; m <= 12; m++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(meses[m - 1]),
                      selected: m == _mes,
                      onSelected: (_) => setState(() => _mes = m),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<DiaDoPlano>>(
        future: Conteudo.instancia.plano(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dias = snap.data!.where((d) => d.mes == _mes).toList();
          final lidosNoMes = dias.where((d) => estado.foiLido(d.data)).length;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: dias.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                dia: dia,
                lido: estado.foiLido(dia.data),
                ehHoje: ehHoje,
                aoAlternar: () => estado.alternarLido(dia.data),
              );
            },
          );
        },
      ),
    );
  }
}

class _CartaoDoDia extends StatelessWidget {
  const _CartaoDoDia({
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
    final tema = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          // O dia de hoje ganha borda dourada plena para se achar de relance
          // dentro de uma lista de trinta e um cartões parecidos.
          color: ehHoje ? Cores.dourado : Cores.douradoEscuro.withValues(alpha: 0.35),
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
                  color: lido ? Cores.douradoClaro : Cores.dourado,
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
                      color: lido ? Cores.begeSuave : Cores.bege,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final f in dia.faixas) BotaoDeFaixa(faixa: f)],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: lido ? 'Desmarcar' : 'Marcar como lido',
              icon: Icon(
                lido ? Icons.check_circle : Icons.radio_button_unchecked,
                color: lido ? Cores.douradoClaro : Cores.begeSuave,
              ),
              onPressed: aoAlternar,
            ),
          ],
        ),
      ),
    );
  }
}
