import 'dart:async';

import 'package:flutter/material.dart';

import '../data/audio_offline.dart';
import '../data/personas.dart';
import '../data/recursos.dart';
import '../data/voz.dart';
import '../estilo/spacing.dart';
import '../funcoes/aviso.dart';
import 'retrato_de_persona.dart';

/// Botão de ouvir na voz de Spurgeon: o retrato dele no chat, num comprimido
/// que toca o áudio de [chave] e, enquanto toca, mostra a leitura acontecendo.
///
/// [chave] identifica o que se ouve ("introducao:joao", "capitulo:joao.3"): a
/// voz é de app inteiro, então o botão da introdução e o do capítulo mostram
/// o mesmo estado para o mesmo áudio, e ouvir um para o outro. [referencia]
/// nomeia o que terminou no aviso ("João 3"), para o fim da leitura não ser
/// um "Leitura concluída." genérico.
///
/// O botão escuta o fim da própria leitura para fechar o ciclo com a
/// confirmação "Leitura concluída.": parar no meio não é um fim, e não avisa.
class BotaoDeVoz extends StatefulWidget {
  const BotaoDeVoz({super.key, required this.chave, this.referencia});

  final String chave;
  final String? referencia;

  @override
  State<BotaoDeVoz> createState() => _BotaoDeVozState();
}

class _BotaoDeVozState extends State<BotaoDeVoz> {
  StreamSubscription<String>? _conclusoes;

  // Null enquanto ainda não sabe se o áudio existe: o botão fica escondido
  // até a resposta chegar, nunca mostra um "Ouvir" que falharia ao tocar.
  bool? _disponivel;

  @override
  void initState() {
    super.initState();
    _conclusoes = Voz.instancia.conclusoes.listen((chave) {
      if (chave != widget.chave || !mounted) return;
      final referencia = widget.referencia;
      mostrarAviso(
        context,
        referencia == null
            ? 'Leitura concluída.'
            : 'Leitura concluída: $referencia.',
      );
    });
    _checarDisponibilidade();
  }

  Future<void> _checarDisponibilidade() async {
    // Local e remoto são checados um sem depender do outro: uma exceção de
    // plataforma num (ex: path_provider sem registro em teste de widget) não
    // pode esconder a resposta do outro.
    var offline = false;
    try {
      offline = await AudioOffline.instancia.temOffline(widget.chave);
    } catch (_) {}
    var disponivel = offline;
    if (!disponivel) {
      try {
        disponivel = await Voz.instancia.arquivoDisponivelRemoto(widget.chave);
      } catch (_) {}
    }
    if (mounted) setState(() => _disponivel = disponivel);
  }

  @override
  void didUpdateWidget(covariant BotaoDeVoz oldWidget) {
    super.didUpdateWidget(oldWidget);
    // O mesmo State pode ser reaproveitado com outra chave (ex: navegação
    // entre capítulos sem remontar o widget) — sem isso o botão continuaria
    // mostrando a disponibilidade do capítulo anterior.
    if (widget.chave != oldWidget.chave) {
      _disponivel = null;
      _checarDisponibilidade();
    }
  }

  @override
  void dispose() {
    _conclusoes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Recursos.ouvirTextos) return const SizedBox.shrink();
    if (_disponivel != true) return const SizedBox.shrink();
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Voz.instancia,
      builder: (context, _) {
        final voz = Voz.instancia;
        // O carregando fica ligado a leitura inteira (só se desliga no fim do
        // play): o preparo é "carregando sem tocar" — sem o !tocando, o
        // tooltip diria "Cancelar o preparo" com o áudio tocando.
        final preparando =
            voz.carregando && !voz.tocando && voz.tocandoChave == widget.chave;
        final ativo = voz.tocando && voz.tocandoChave == widget.chave;
        final pausado = voz.pausado && voz.tocandoChave == widget.chave;
        // A leitura fala como o pregador, não como painel de controle: quem
        // está lendo é uma pessoa, e o aviso completo vai no Semantics (o
        // rótulo visível é curto para caber na pílula em escala 2x).
        final rotulo = ativo
            ? 'O pregador está lendo. Toque para pausar a leitura.'
            : pausado
            ? 'A leitura foi pausada. Toque para retomar.'
            : preparando
            ? 'Preparando a voz de Spurgeon. Toque para cancelar.'
            : 'Ouvir na voz de Spurgeon';
        final visivel = ativo
            ? 'O pregador está lendo…'
            : pausado
            ? 'Pausado. Toque para retomar.'
            : preparando
            ? 'Preparando a voz…'
            : 'Ouvir';
        return Tooltip(
          message: preparando
              ? 'Cancelar o preparo'
              : ativo
              ? 'Pausar a leitura'
              : pausado
              ? 'Retomar a leitura'
              : 'Ouvir na voz de Spurgeon',
          child: Semantics(
            button: true,
            label: rotulo,
            child: Material(
              color: cor.surfaceContainerHighest,
              // Ativo, o comprimido usa o anel do metal em vez do metal cheio:
              // a pílula do metal cheio sobre o dourado da página empilhava
              // dourado sobre dourado, e o anel reserva o fill para o chip
              // escolhido, que é o alternador de leitura e de mês.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                // O anel acompanha a sessão viva: tocando ou pausada, a pílula
                // ainda pertence ao metal do tema.
                side: ativo || pausado
                    ? BorderSide(color: cor.primary, width: 1.5)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(30),
                    // Durante o preparo o botão continua vivo: o toque cancela
                    // em vez de prender quem tocou o capítulo errado num
                    // relógio de até 90 segundos. Tocando, o toque pausa (o
                    // parar de vez mora no X ao lado); pausada, a pílula é o
                    // próprio retomar: o toque volta à leitura de onde parou
                    // sem recarregar da rede (seek+play).
                    onTap: preparando
                        ? voz.parar
                        : ativo
                        ? () => _pausar(context, voz)
                        : pausado
                        ? () => _retomar(context, voz)
                        : () => _alternar(context, voz),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.sp6,
                        Spacing.sp6,
                        Spacing.sp16,
                        Spacing.sp6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // O retrato é o convite: quem já ouve (ou está
                          // pausado no meio) não precisa do rosto de novo ao
                          // lado do rótulo — a leitura em andamento é ação,
                          // não apresentação, e um sinal a menos deixa o
                          // estado falar mais alto.
                          if (!preparando && !ativo && !pausado) ...[
                            // O mesmo retrato das entradas de conversa
                            // ([RetratoDePersona]): aro dourado, e o cabelo,
                            // que encosta na borda de cima da foto, preservado
                            // pelo corte alinhado ao topo.
                            RetratoDePersona(
                              persona: personaSpurgeon,
                              folga: Spacing.sp3,
                              decorativo: true,
                            ),
                            const SizedBox(width: Spacing.sp10),
                          ],
                          Icon(
                            ativo
                                ? Icons.pause_rounded
                                : preparando
                                ? Icons.hourglass_top_rounded
                                : Icons.play_arrow_rounded,
                            size: 20,
                            color: cor.primary,
                          ),
                          const SizedBox(width: Spacing.sp6),
                          // Flexible com reticências: em escala de texto 2x um
                          // rótulo comprido ("O pregador está lendo…") não
                          // pode estourar a largura da tela. Semantics: o
                          // rótulo completo já vive no Semantics acima, e o
                          // texto visível repetido faria o leitor de tela ler
                          // a frase duas vezes.
                          Flexible(
                            child: ExcludeSemantics(
                              child: Text(
                                visivel,
                                overflow: TextOverflow.ellipsis,
                                style: tema.labelLarge?.copyWith(
                                  color: ativo || pausado
                                      ? cor.primary
                                      : cor.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          // Tocando ou pausada, a sessão precisa de um jeito
                          // de ser encerrada de vez sem trocar de página.
                          if (ativo || pausado)
                            _BotaoDeEncerrar(voz: voz, pausado: pausado),
                        ],
                      ),
                    ),
                  ),
                  // A linha fina de progresso, na borda de baixo da pílula:
                  // quem ouve um capítulo de vinte minutos sabe quanto falta.
                  // Pausada, ela mostra onde a leitura parou. Durante o
                  // preparo ela é indeterminada (o valor é nulo até a duração
                  // chegar): até 90 segundos de espera não podem parecer um
                  // botão morto, e sem a duração não há o que preencher.
                  if (preparando || ativo || pausado)
                    ExcludeSemantics(child: _ProgressoDeLeitura(voz: voz)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _alternar(BuildContext context, Voz voz) async {
    try {
      await voz.alternar(widget.chave);
    } on VozException catch (erro) {
      if (context.mounted) _avisarErro(context, voz, erro);
    }
  }

  Future<void> _pausar(BuildContext context, Voz voz) async {
    try {
      await voz.pausar();
    } on VozException catch (erro) {
      if (context.mounted) _avisarErro(context, voz, erro);
    }
  }

  Future<void> _retomar(BuildContext context, Voz voz) async {
    try {
      // Pausado tem caminho sem recarregar: seek+play quando a source ainda
      // está carregada (arquivo) ou da cache (TTS em memória).
      final retomou = await voz.retomarDaPausa();
      if (!retomou) {
        await voz.alternar(widget.chave);
      }
    } on VozException catch (erro) {
      if (context.mounted) _avisarErro(context, voz, erro);
    }
  }

  /// O aviso de erro com um "Tentar de novo" à mão: um erro de rede ou de
  /// serviço é momentâneo na maioria das vezes, e sem a ação o usuário teria
  /// de descobrir sozinho que tocar de novo é o caminho.
  void _avisarErro(BuildContext context, Voz voz, VozException erro) {
    mostrarErro(
      context,
      erro.mensagem,
      rotuloDeAcao: 'Tentar de novo',
      aoAgir: () => _alternar(context, voz),
    );
  }
}

/// Fração da leitura decorrida (0,0 a 1,0), ou nulo enquanto a duração total
/// ainda não é conhecida — é o nulo que deixa anel e faixa no modo
/// indeterminado, o que se move é o que se espera.
double? fracaoDeProgresso(Duration agora, Duration? total) =>
    total == null || total.inMilliseconds == 0
    ? null
    : (agora.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

/// O X da pílula de voz: encerra a sessão de vez sem trocar de página. Sem
/// ele, pausar (ou uma pausa já em curso) vira um beco sem saída — e uma
/// leitura que não se pode fechar é uma gaiola. O X mata a sessão; o corpo da
/// pílula continua pausando ou retomando.
class _BotaoDeEncerrar extends StatelessWidget {
  const _BotaoDeEncerrar({required this.voz, required this.pausado});

  final Voz voz;
  final bool pausado;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Tooltip(
        message: pausado ? 'Encerrar a leitura pausada' : 'Encerrar a leitura',
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: voz.parar,
          // Alvo de toque cheio de 48dp: o X encerra uma sessão de leitura de
          // vinte minutos, e um alvo de 26dp no topo da tela pedia mira.
          // O ícone continua pequeno dentro do quadrado centrado.
          child: SizedBox.square(
            dimension: Spacing.sp48,
            child: Center(
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: cor.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// O indicador "há leitura no ar" na barra de cima: aparece quando a chave
/// desta tela está tocando ou se preparando, para quem rolou para longe do
/// botão ainda poder pausar, retomar, encerrar (ou cancelar o preparo) sem
/// voltar ao topo. A mesma peça na Bíblia, na introdução e em Sobre: uma
/// leitura não pode ficar sem os controles à vista.
class IndicadorDeVozNaBarra extends StatelessWidget {
  const IndicadorDeVozNaBarra({super.key, required this.chave});

  /// A chave de voz desta tela ("capitulo:joao.3", "introducao:joao"): só o
  /// áudio dela aparece aqui; o de outra tela não rouba a barra.
  final String chave;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Voz.instancia,
      builder: (context, _) {
        final voz = Voz.instancia;
        final aqui =
            (voz.tocando || voz.carregando || voz.pausado) &&
            voz.tocandoChave == chave;
        if (!aqui) return const SizedBox.shrink();
        // Preparando, o indicador mostra o preparo em curso: quem espera
        // ainda pode cancelar. O carregando continua ligado durante a
        // leitura (só se desliga no fim do play), por isso o preparo é
        // "carregando sem tocar".
        final preparando = voz.carregando && !voz.tocando;
        if (preparando) {
          // O anel gira enquanto o áudio não chegou — o que está parado no
          // "Cancelar" é a página, não a barra de cima: quem rolou para longe
          // ainda vê o preparo em andamento, e não um ícone congelado.
          return ExcludeSemantics(
            child: IconButton(
              tooltip: 'Cancelar o preparo',
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      value: null,
                      strokeWidth: 2,
                      color: cor.primary,
                      backgroundColor: cor.surfaceContainerHighest,
                    ),
                  ),
                  Icon(Icons.hourglass_top_rounded, size: 18),
                ],
              ),
              onPressed: voz.parar,
            ),
          );
        }
        // Pausada de fora, o anel é o retomar: quem rolou para longe da
        // pílula não pode ter de voltar ao topo para continuar a leitura, e
        // um toque que "encerrasse" aqui jogaria fora a posição da pausa.
        final retomar = voz.pausado && !voz.tocando;
        // Tocando ou pausada, o ícone ganha um anel de progresso: quem rolou
        // para longe do botão continua sabendo quanto falta (ou onde a
        // leitura parou) sem voltar ao topo. Tocando, um segundo ícone sem
        // anel encerra de vez — o mesmo par pausar/parar da pílula, só que
        // aqui pausar é o anel (a ação mais comum) e parar é o extra.
        return ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<Duration>(
                stream: voz.posicao,
                builder: (context, posicao) {
                  final agora = posicao.data ?? Duration.zero;
                  return StreamBuilder<Duration?>(
                    stream: voz.duracao,
                    builder: (context, duracao) {
                      final total = duracao.data;
                      // Sem duração conhecida o anel fica indeterminado (o
                      // CircularProgressIndicator anima sozinho).
                      final fracao = fracaoDeProgresso(agora, total);
                      return IconButton(
                        tooltip: retomar
                            ? 'Retomar a leitura'
                            : 'Pausar a leitura',
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                value: fracao,
                                strokeWidth: 2,
                                color: cor.primary,
                                backgroundColor: cor.surfaceContainerHighest,
                              ),
                            ),
                            Icon(
                              retomar
                                  ? Icons.play_circle_outline
                                  : Icons.pause_circle_outline,
                              size: 18,
                            ),
                          ],
                        ),
                        onPressed: retomar ? voz.retomarDaPausa : voz.pausar,
                      );
                    },
                  );
                },
              ),
              if (!retomar)
                IconButton(
                  tooltip: 'Encerrar a leitura',
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  onPressed: voz.parar,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A linha fina de progresso da leitura: a posição do player sobre a duração
/// total. Só é montada enquanto toca ou prepara; sem player (testes) as
/// streams ficam vazias e nada é desenhado. Enquanto a duração não chega (o
/// preparo, o primeiro instante da leitura) o valor é nulo e a faixa vira a
/// indeterminada animada — o que se move é o que se espera.
class _ProgressoDeLeitura extends StatelessWidget {
  const _ProgressoDeLeitura({required this.voz});

  final Voz voz;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: voz.posicao,
      builder: (context, posicao) {
        final agora = posicao.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: voz.duracao,
          builder: (context, duracao) {
            final total = duracao.data;
            // Sem duração conhecida não há o que preencher: a faixa fica
            // indeterminada (o LinearProgressIndicator anima sozinho).
            final fracao = fracaoDeProgresso(agora, total);
            return LinearProgressIndicator(
              value: fracao,
              minHeight: 3,
              color: cor.primary,
              // O trilho na cor da página se destaca do comprimido e deixa o
              // fio dourado de progresso visível em vez de sumir no próprio
              // fundo da pílula.
              backgroundColor: cor.surface,
            );
          },
        );
      },
    );
  }
}
