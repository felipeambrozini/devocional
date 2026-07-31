import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/localizacao.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'biblia.dart';
import 'comuns.dart';
import 'devocional.dart';
import 'faixa.dart';

/// Tela de abertura: quem sou, o devocional da hora, a leitura do dia e o progresso.
class TelaHoje extends StatefulWidget {
  const TelaHoje({super.key});

  @override
  State<TelaHoje> createState() => _TelaHojeState();
}

class _TelaHojeState extends State<TelaHoje> {
  @override
  void initState() {
    super.initState();
    // Sem await: a tela abre com o último lugar conhecido, ou com o horário
    // fixo, e se redesenha sozinha se o GPS trouxer algo diferente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) atualizarLugar(EscopoDoEstado.de(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final estado = EscopoDoEstado.de(context);
    final periodo = Periodo.peloSol(agora, estado.lugar);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Cabecalho(periodo: periodo, data: agora),
            const SizedBox(height: 20),
            _PreviaDaLeitura(
              data: agora,
              leitura: periodo == Periodo.manha ? Leitura.manha : Leitura.noite,
            ),
            const SizedBox(height: 16),
            _PreviaDaLeitura(data: agora, leitura: Leitura.promessas),
            const SizedBox(height: 16),
            _LeituraDeHoje(data: agora),
            const SizedBox(height: 16),
            _Progresso(estado: estado, ano: agora.year),
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
        // Na web o app fica público; sem foto nem nome, só a saudação.
        if (!kIsWeb) ...[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Cores.dourado, width: 2),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: SizedBox(
                width: 60,
                height: 60,
                child: Image.asset(
                  'assets/images/felipe.png',
                  fit: BoxFit.cover,
                  // A foto é mais alta que larga; o corte automático centralizado do
                  // BoxFit.cover cortava o topo da cabeça. Alinhando quase ao topo, o
                  // corte sobra todo embaixo, no peito, em vez do cabelo.
                  alignment: const Alignment(0, -0.85),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Cores.superficieAlta,
                    alignment: Alignment.center,
                    child: const Text(
                      'F',
                      style: TextStyle(color: Cores.dourado, fontSize: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kIsWeb ? saudacao : '$saudacao, Felipe', style: tema.headlineMedium),
              const SizedBox(height: 4),
              Text(dataLonga(data), style: tema.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Prévia de uma das três leituras do dia, com atalho para a tela inteira.
///
/// Serve às três porque só o que muda é de onde o texto vem e se há título e
/// versículo em destaque: Promessas de Deus tem os dois, Manhã e Noite não.
class _PreviaDaLeitura extends StatelessWidget {
  const _PreviaDaLeitura({required this.data, required this.leitura});

  final DateTime data;
  final Leitura leitura;

  String get _titulo => leitura == Leitura.promessas
      ? leitura.rotulo
      : 'Devocional da ${leitura.rotulo.toLowerCase()}';

  IconData get _icone => switch (leitura) {
        Leitura.manha => Icons.wb_sunny_outlined,
        Leitura.noite => Icons.nightlight_outlined,
        Leitura.promessas => Icons.auto_awesome_outlined,
      };

  Future<Devocional?> _futuro(Versao versao) {
    final periodo = leitura.periodo;
    return periodo == null
        ? Conteudo.instancia.promessa(data, versao: versao)
        : Conteudo.instancia.devocional(data, periodo, versao: versao);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final versao = EscopoDoEstado.de(context).versao;
    return CarregaUmaVez<Devocional?>(
      // A versão entra na chave para a prévia recarregar ao alternar BKJ/NVT
      // no Devocional, do mesmo jeito que o leitor da Bíblia já faz.
      chave: '${leitura.name}/${versao.pasta}/${Conteudo.chaveDoDia(data)}',
      carregar: () => _futuro(versao),
      construir: (context, snap) {
        final dev = snap.data;
        final spans = dev == null
            ? const <InlineSpan>[]
            : spansDeCitacao(
                dev,
                estiloCitacao: tema.bodyMedium?.copyWith(
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                  color: Cores.douradoClaro,
                ),
                estiloReferencia: tema.titleSmall?.copyWith(color: Cores.douradoClaro),
              );
        return Cartao(
          titulo: _titulo,
          acessorio: Icon(_icone, color: Cores.dourado, size: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dev == null)
                const Text('Carregando...')
              else ...[
                if (dev.titulo.isNotEmpty)
                  Text(
                    dev.titulo,
                    style: tema.titleMedium?.copyWith(color: Cores.dourado),
                  ),
                const SizedBox(height: 8),
                // A citação vem antes do nome do livro, e o nome do livro fica
                // ao lado do fim da citação, não numa linha própria embaixo.
                // Mais de uma linha no raro dia com mais de um versículo-base.
                if (spans.isNotEmpty) ...[
                  Text.rich(TextSpan(children: spans)),
                  const SizedBox(height: 8),
                ],
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
                          leituraInicial: leitura,
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
    return CarregaUmaVez<DiaDoPlano?>(
      chave: Conteudo.chaveDoDia(data),
      carregar: () => Conteudo.instancia.diaDoPlano(data),
      construir: (context, snap) {
        // Sem este guard o primeiro frame, que sempre chega sem dado porque a
        // leitura é assíncrona, cairia no aviso de 29 de fevereiro abaixo e o
        // mostraria em qualquer dia comum até o cronograma carregar.
        if (snap.connectionState != ConnectionState.done) {
          return const Cartao(titulo: 'Leitura de hoje', child: Text('Carregando...'));
        }
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
  const _Progresso({required this.estado, required this.ano});

  final Estado estado;

  /// O ano decide o total: 366 dias em ano bissexto.
  final int ano;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final total = Conteudo.diasDoAno(ano);
    final progresso = estado.progressoDoAno(total);
    final porcento = (progresso * 100).round();
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
              Text('de $total dias', style: tema.bodySmall),
              const Spacer(),
              Text('$porcento%', style: tema.headlineSmall),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progresso.clamp(0.0, 1.0),
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
