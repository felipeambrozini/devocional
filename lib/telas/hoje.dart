import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/nuvem.dart';
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
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final estado = EscopoDoEstado.de(context);
    final periodo = Periodo.pelaHora(agora.hour);

    return Scaffold(
      body: SafeArea(
        child: LarguraDeLeitura(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Cabecalho(data: agora),
              const SizedBox(height: 20),
              if (estado.ultimaLeitura != null) ...[
                // Retomar uma leitura interrompida é a ação de maior intenção
                // de quem abre o app, por isso vem antes das prévias do dia,
                // não depois das estatísticas de progresso.
                _Continuar(ultima: estado.ultimaLeitura!),
                const SizedBox(height: 16),
              ],
              _PreviaDaLeitura(
                data: agora,
                leitura: periodo == Periodo.manha
                    ? Leitura.manha
                    : Leitura.noite,
              ),
              const SizedBox(height: 16),
              _PreviaDaLeitura(data: agora, leitura: Leitura.promessas),
              const SizedBox(height: 16),
              _LeituraDeHoje(data: agora),
              const SizedBox(height: 16),
              _Progresso(estado: estado, ano: agora.year),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bom dia, boa tarde ou boa noite, só para a saudação — separado de
/// [Periodo], que decide qual devocional (Manhã ou Noite) aparece na
/// prévia. O conteúdo é binário porque Spurgeon só escreveu duas partes por
/// dia; a saudação não precisa seguir a mesma régua.
String _saudacaoPelaHora(int hora) {
  if (hora < 6) return 'Boa noite';
  if (hora < 12) return 'Bom dia';
  if (hora < 18) return 'Boa tarde';
  return 'Boa noite';
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final saudacao = _saudacaoPelaHora(data.hour);

    return Row(
      children: [
        // Na web o app fica público; sem foto nem nome, só a saudação.
        if (!kIsWeb) ...[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cor.primary, width: 2),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: SizedBox(
                width: 60,
                height: 60,
                child: Image.asset(
                  'assets/images/felipe.webp',
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto de Felipe',
                  // A foto é mais alta que larga; o corte automático centralizado do
                  // BoxFit.cover cortava o topo da cabeça. Alinhando quase ao topo, o
                  // corte sobra todo embaixo, no peito, em vez do cabelo.
                  alignment: const Alignment(0, -0.85),
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: cor.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(
                      'F',
                      style: TextStyle(color: cor.primary, fontSize: 24),
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
              // Na web, quem entrou com a conta Google ganha o próprio nome
              // na saudação; sem conta, um convite compacto ao lado dela —
              // login escondido na folha de ajustes não se acha numa versão
              // pública. Fora da web é sempre "Felipe", sem conta nenhuma.
              kIsWeb
                  ? ListenableBuilder(
                      listenable: Nuvem.instancia,
                      builder: (context, _) {
                        final nome = Nuvem.instancia.primeiroNome;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                nome == null ? saudacao : '$saudacao, $nome',
                                style: tema.headlineMedium,
                              ),
                            ),
                            if (nome == null) ...[
                              const SizedBox(width: 8),
                              const _BotaoDeEntrarCompacto(),
                            ],
                          ],
                        );
                      },
                    )
                  : Text('$saudacao, Felipe', style: tema.headlineMedium),
              const SizedBox(height: 4),
              Text(dataLonga(data), style: tema.bodySmall),
            ],
          ),
        ),
        // Hoje não tem AppBar onde pendurar a ação, e sem isto os ajustes só
        // seriam alcançáveis de duas das cinco abas.
        BotaoDeAjustes(estado: EscopoDoEstado.de(context)),
      ],
    );
  }
}

/// Convite de login compacto, ao lado da saudação. `entrarNaConta` é de
/// `comuns.dart` — a mesma função por trás do botão da seção "Conta" na
/// folha de ajustes, que continua lá para quem já entrou (e-mail, Sair).
class _BotaoDeEntrarCompacto extends StatelessWidget {
  const _BotaoDeEntrarCompacto();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () => entrarNaConta(context, Nuvem.instancia),
      icon: Image.asset('assets/images/google_g.png', width: 16, height: 16),
      label: const Text('Entrar'),
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

  /// Cartão de uma linha só, para quando ainda não há texto para mostrar.
  Widget _aviso(BuildContext context, String texto) => Cartao(
    titulo: _titulo,
    acessorio: Icon(
      _icone,
      color: Theme.of(context).colorScheme.primary,
      size: 20,
    ),
    child: Text(texto),
  );

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final versao = EscopoDoEstado.de(context).versao;
    return CarregaUmaVez<Devocional?>(
      // A versão entra na chave para a prévia recarregar ao alternar BKJ/NVT
      // no Devocional, do mesmo jeito que o leitor da Bíblia já faz.
      chave: '${leitura.name}/${versao.pasta}/${Conteudo.chaveDoDia(data)}',
      carregar: () => _futuro(versao),
      construir: (context, snap) {
        // Os três casos precisam ser separados. `snap.data` é nulo tanto enquanto
        // carrega quanto quando não existe leitura para a data, e tratar os dois
        // como um só deixava o cartão dizendo "Carregando..." para sempre num dia
        // sem devocional. É o mesmo guard que _LeituraDeHoje já usa logo abaixo.
        if (snap.hasError) {
          return _aviso(context, 'Não foi possível carregar esta leitura.');
        }
        if (snap.connectionState != ConnectionState.done) {
          return _aviso(context, 'Carregando...');
        }
        final dev = snap.data;
        if (dev == null) return _aviso(context, 'Sem leitura para esta data.');

        final spans = spansDeCitacao(
          dev,
          estiloCitacao: tema.bodyMedium?.copyWith(
            height: 1.6,
            fontStyle: FontStyle.italic,
            color: cor.secondary,
          ),
          estiloReferencia: tema.titleSmall?.copyWith(color: cor.secondary),
        );
        return Cartao(
          titulo: _titulo,
          acessorio: Icon(_icone, color: cor.primary, size: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dev.titulo.isNotEmpty)
                Text(
                  dev.titulo,
                  style: tema.titleMedium?.copyWith(color: cor.primary),
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
    final cor = Theme.of(context).colorScheme;
    final estado = EscopoDoEstado.de(context);
    return CarregaUmaVez<DiaDoPlano?>(
      chave: Conteudo.chaveDoDia(data),
      carregar: () => Conteudo.instancia.diaDoPlano(data),
      construir: (context, snap) {
        // Sem este guard o primeiro frame, que sempre chega sem dado porque a
        // leitura é assíncrona, cairia no aviso de 29 de fevereiro abaixo e o
        // mostraria em qualquer dia comum até o cronograma carregar.
        // Erro (asset corrompido ou ausente) e "não há dia para esta data"
        // pareciam a mesma coisa antes: os dois chegam com snap.data == null,
        // e sem separar isso a tela sempre culpava 29 de fevereiro, mesmo
        // num erro de verdade em qualquer outro dia do ano.
        if (snap.hasError) {
          return const Cartao(
            titulo: 'Leitura de hoje',
            child: Text('Não foi possível carregar o cronograma.'),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Cartao(
            titulo: 'Leitura de hoje',
            child: Text('Carregando...'),
          );
        }
        final dia = snap.data;
        if (dia == null) {
          return const Cartao(
            titulo: 'Leitura de hoje',
            child: Text(
              'Dia de recuperação: o cronograma não prevê 29 de fevereiro.',
            ),
          );
        }
        final lido = estado.foiLido(dia.data);
        return Cartao(
          titulo: 'Leitura de hoje',
          acessorio: IconButton(
            tooltip: lido ? 'Desmarcar' : 'Marcar como lido',
            icon: Icon(
              lido ? Icons.check_circle : Icons.radio_button_unchecked,
              color: lido ? cor.secondary : cor.onSurfaceVariant,
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
    final cor = Theme.of(context).colorScheme;
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
              backgroundColor: cor.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(cor.primary),
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
              builder: (_) =>
                  TelaBiblia(livroInicial: livro, capituloInicial: capitulo),
            ),
          ),
        ),
      ),
    );
  }
}
