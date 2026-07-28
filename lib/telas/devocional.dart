import 'package:flutter/material.dart';

import '../data/conteudo.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'comuns.dart';
import 'faixa.dart';

/// Manhã e Noite, mais a Promessa do dia.
///
/// Abre no período conforme o relógio, com botão para alternar, e permite escolher
/// qualquer data pelo calendário.
class TelaDevocional extends StatefulWidget {
  const TelaDevocional({super.key, this.dataInicial, this.periodoInicial});

  final DateTime? dataInicial;
  final Periodo? periodoInicial;

  @override
  State<TelaDevocional> createState() => _TelaDevocionalState();
}

class _TelaDevocionalState extends State<TelaDevocional> {
  late DateTime _data;
  late Periodo _periodo;

  @override
  void initState() {
    super.initState();
    _data = widget.dataInicial ?? DateTime.now();
    _periodo = widget.periodoInicial ?? Periodo.pelaHora(DateTime.now().hour);
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      // O devocional é anual e se repete, então a janela é só um intervalo
      // confortável para navegar, não um limite de conteúdo.
      firstDate: DateTime(_data.year - 5),
      lastDate: DateTime(_data.year + 5, 12, 31),
      helpText: 'Escolha a data do devocional',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final ehHoje = _data.month == hoje.month && _data.day == hoje.day;

    return Scaffold(
      appBar: AppBar(
        title: Text(ehHoje ? 'Hoje, ${dataLonga(_data)}' : dataLonga(_data)),
        actions: [
          IconButton(
            tooltip: 'Escolher data',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _escolherData,
          ),
          if (!ehHoje)
            IconButton(
              tooltip: 'Voltar para hoje',
              icon: const Icon(Icons.today_outlined),
              onPressed: () => setState(() => _data = DateTime.now()),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<Periodo>(
            segments: [
              for (final p in Periodo.values)
                ButtonSegment(
                  value: p,
                  label: Text(p.nome),
                  icon: Icon(p == Periodo.manha
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_outlined),
                ),
            ],
            selected: {_periodo},
            onSelectionChanged: (s) => setState(() => _periodo = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          FutureBuilder<Devocional?>(
            key: ValueKey('me/${_data.month}/${_data.day}/${_periodo.chave}'),
            future: Conteudo.instancia.devocional(_data, _periodo),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final dev = snap.data;
              if (dev == null) {
                return const Cartao(
                  child: AvisoVazio(
                    icone: Icons.auto_stories_outlined,
                    titulo: 'Sem devocional para esta data',
                  ),
                );
              }
              return _CartaoDeLeitura(
                titulo: '${_periodo.nome}, ${dataLonga(_data)}',
                referencia: dev.referencia,
                texto: dev.texto,
                capa: 'assets/images/capa_manha_e_noite.png',
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<Devocional?>(
            key: ValueKey('pr/${_data.month}/${_data.day}'),
            future: Conteudo.instancia.promessa(_data),
            builder: (context, snap) {
              final promessa = snap.data;
              if (promessa == null) {
                return const Cartao(
                  titulo: 'Promessas de Deus',
                  child: Text(
                    'O texto de Promessas de Deus ainda não foi carregado. '
                    'Assim que o arquivo entrar em assets/devotional/promises.json, '
                    'a promessa do dia aparece aqui.',
                  ),
                );
              }
              return _CartaoDeLeitura(
                titulo: 'Promessa do dia',
                referencia: promessa.referencia,
                texto: promessa.texto,
                capa: 'assets/images/capa_promessas_de_deus.png',
              );
            },
          ),
          const SizedBox(height: 16),
          _LeituraDoDia(data: _data),
        ],
      ),
    );
  }
}

class _CartaoDeLeitura extends StatelessWidget {
  const _CartaoDeLeitura({
    required this.titulo,
    required this.referencia,
    required this.texto,
    this.capa,
  });

  final String titulo;
  final String referencia;
  final String texto;

  /// Capa do livro de onde a leitura vem, para dar identidade ao cartão.
  final String? capa;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Cartao(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (capa != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(capa!, height: 62, fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: tema.headlineMedium),
                    if (referencia.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        referencia,
                        style: tema.titleSmall?.copyWith(color: Cores.douradoClaro),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Filete(),
          const SizedBox(height: 14),
          Text(texto, style: tema.bodyLarge?.copyWith(height: 1.7)),
        ],
      ),
    );
  }
}

/// Atalho para a leitura do cronograma na data escolhida.
class _LeituraDoDia extends StatelessWidget {
  const _LeituraDoDia({required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DiaDoPlano?>(
      key: ValueKey('plano/${data.month}/${data.day}'),
      future: Conteudo.instancia.diaDoPlano(data),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final dia = snap.data;
        if (dia == null) {
          return const Cartao(
            titulo: 'Leitura do dia',
            child: Text(
              'O cronograma tem 365 dias e não prevê 29 de fevereiro. '
              'Hoje é dia de recuperação: aproveite para colocar em dia alguma '
              'leitura atrasada.',
            ),
          );
        }
        return Cartao(
          titulo: 'Leitura do dia',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dia.rotulo, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final faixa in dia.faixas) BotaoDeFaixa(faixa: faixa)],
              ),
            ],
          ),
        );
      },
    );
  }
}
