import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'biblia.dart';
import 'comuns.dart';
import 'devocional.dart';
import 'faixa.dart';

/// Tela de abertura: quem sou, o devocional da hora, a leitura do dia e o progresso.
class TelaHoje extends StatelessWidget {
  const TelaHoje({super.key});

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final periodo = Periodo.pelaHora(agora.hour);
    final estado = EscopoDoEstado.de(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Cabecalho(periodo: periodo, data: agora),
            const SizedBox(height: 20),
            _DevocionalDaHora(data: agora, periodo: periodo),
            const SizedBox(height: 16),
            _LeituraDeHoje(data: agora),
            const SizedBox(height: 16),
            _Progresso(estado: estado),
            if (estado.ultimaLeitura != null) ...[
              const SizedBox(height: 16),
              _Continuar(ultima: estado.ultimaLeitura!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.periodo, required this.data});

  final Periodo periodo;
  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final saudacao = periodo == Periodo.manha ? 'Bom dia' : 'Boa noite';

    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Cores.dourado, width: 2),
          ),
          padding: const EdgeInsets.all(3),
          child: const CircleAvatar(
            radius: 30,
            backgroundColor: Cores.superficieAlta,
            // A foto entra em assets/images/felipe.png. Sem o arquivo, cai na inicial,
            // e o app abre normalmente em vez de estourar por asset ausente.
            foregroundImage: AssetImage('assets/images/felipe.png'),
            child: Text('F', style: TextStyle(color: Cores.dourado, fontSize: 24)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$saudacao, Felipe', style: tema.headlineMedium),
              const SizedBox(height: 4),
              Text(dataLonga(data), style: tema.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _DevocionalDaHora extends StatelessWidget {
  const _DevocionalDaHora({required this.data, required this.periodo});

  final DateTime data;
  final Periodo periodo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return FutureBuilder<Devocional?>(
      future: Conteudo.instancia.devocional(data, periodo),
      builder: (context, snap) {
        final dev = snap.data;
        return Cartao(
          titulo: 'Devocional da ${periodo == Periodo.manha ? 'manhã' : 'noite'}',
          acessorio: Icon(
            periodo == Periodo.manha
                ? Icons.wb_sunny_outlined
                : Icons.nightlight_outlined,
            color: Cores.dourado,
            size: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dev == null)
                const Text('Carregando...')
              else ...[
                if (dev.referencia.isNotEmpty)
                  Text(
                    dev.referencia,
                    style: tema.titleSmall?.copyWith(color: Cores.douradoClaro),
                  ),
                const SizedBox(height: 8),
                Text(
                  dev.texto,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: tema.bodyMedium?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TelaDevocional(
                          dataInicial: data,
                          periodoInicial: periodo,
                        ),
                      ),
                    ),
                    child: const Text('Ler tudo'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LeituraDeHoje extends StatelessWidget {
  const _LeituraDeHoje({required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    return FutureBuilder<DiaDoPlano?>(
      future: Conteudo.instancia.diaDoPlano(data),
      builder: (context, snap) {
        final dia = snap.data;
        if (dia == null) {
          return const Cartao(
            titulo: 'Leitura de hoje',
            child: Text('Dia de recuperação: o cronograma não prevê 29 de fevereiro.'),
          );
        }
        final lido = estado.foiLido(dia.data);
        return Cartao(
          titulo: 'Leitura de hoje',
          acessorio: IconButton(
            tooltip: lido ? 'Desmarcar' : 'Marcar como lido',
            icon: Icon(
              lido ? Icons.check_circle : Icons.radio_button_unchecked,
              color: lido ? Cores.douradoClaro : Cores.begeSuave,
            ),
            onPressed: () => estado.alternarLido(dia.data),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dia.rotulo, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final f in dia.faixas) BotaoDeFaixa(faixa: f)],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Progresso extends StatelessWidget {
  const _Progresso({required this.estado});

  final Estado estado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final porcento = (estado.progressoDoAno * 100).round();
    return Cartao(
      titulo: 'Progresso do ano',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${estado.diasLidos}', style: tema.displayLarge),
              const SizedBox(width: 6),
              Text('de 365 dias', style: tema.bodySmall),
              const Spacer(),
              Text('$porcento%', style: tema.headlineSmall),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: estado.progressoDoAno.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Cores.superficieAlta,
              valueColor: const AlwaysStoppedAnimation(Cores.dourado),
            ),
          ),
        ],
      ),
    );
  }
}

class _Continuar extends StatelessWidget {
  const _Continuar({required this.ultima});

  final (String, int) ultima;

  @override
  Widget build(BuildContext context) {
    final (livro, capitulo) = ultima;
    return Cartao(
      titulo: 'Continuar leitura',
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text('${nomeDoLivro(livro)} $capitulo'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaBiblia(
                livroInicial: livro,
                capituloInicial: capitulo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
