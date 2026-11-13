import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controladores/biblia_controlador.dart';
import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/voz.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// Leitor da Bíblia. Abre em Gênesis 1 ou onde a leitura parou.
class TelaBiblia extends StatefulWidget {
  const TelaBiblia({
    super.key,
    this.livroInicial,
    this.capituloInicial,
    this.destacar,
  });

  final String? livroInicial;
  final int? capituloInicial;

  /// Faixa de versículos a destacar, para quando o cronograma pede
  /// "Salmos 119:1 a 56" e não o capítulo inteiro.
  final (int, int)? destacar;

  @override
  State<TelaBiblia> createState() => _TelaBibliaState();
}

class _TelaBibliaState extends State<TelaBiblia> {
  late final _controller = BibliaControlador(
    livroInicial: widget.livroInicial,
    capituloInicial: widget.capituloInicial,
  );

  /// A reprodução contínua mora no controller; a assinatura mora aqui porque
  /// precisa do ciclo de vida da tela (cancela no dispose) e do context da
  /// rota da frente (ver `aoConcluirAudio`).
  StreamSubscription<String>? _assinaturaConclusoes;

  /// Muda a chave do carregamento para refazer o pedido que falhou.
  int _tentativa = 0;

  void _tentarDeNovo() {
    Conteudo.instancia.esquecerFalhas();
    setState(() => _tentativa++);
  }

  @override
  void initState() {
    super.initState();
    _assinaturaConclusoes = Voz.instancia.conclusoes.listen((chave) {
      if (!mounted) return;
      _controller.aoConcluirAudio(context, chave);
    });
  }

  @override
  void dispose() {
    _assinaturaConclusoes?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depender do TickerMode aqui é o que acorda este método quando a aba
    // Bíblia volta à frente: o go_router envolve cada aba em Offstage +
    // TickerMode, e a troca de aba liga e desliga o TickerMode.
    _controller.aoChangeDependencies(
      context: context,
      ativa: TickerMode.valuesOf(context).enabled,
      livroInicial: widget.livroInicial,
      capituloInicial: widget.capituloInicial,
      estado: EscopoDoEstado.de(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Teclado na web: as setas passam de capítulo e Ctrl+F abre a
    // busca, que antes só existiam como dois chevrons pequenos no rodapé e um
    // ícone na barra. Setas horizontais não rolam uma lista vertical, então não
    // há conflito com a rolagem do capítulo.
    //
    // Envolve a tela inteira, e não só o corpo: o evento de tecla sobe a partir
    // de quem tem o foco, e o foco pode estar num botão da AppBar. Com o
    // atalho só no corpo, a tecla passava por fora dele e nada acontecia. A
    // âncora de foco fica dentro dos atalhos: é nela que a troca de aba põe o
    // foco (ver DevocionalAncoraDeFoco).
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final cor = Theme.of(context).colorScheme;
        final estado = EscopoDoEstado.de(context);
        final livro = _controller.livro;
        final capitulo = _controller.capitulo;

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _controller.passarCapitulo(context, 1),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _controller.passarCapitulo(context, -1),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                _controller.abrirBusca(context),
          },
          // "Voltar" sai da seleção antes de sair da tela.
          child: DevocionalAncoraDeFoco(
            child: PopScope(
              canPop: !_controller.selecionando,
              onPopInvokedWithResult: (_, _) => _controller.limparSelecao(),
              child: Scaffold(
                appBar: DevocionalAppBar(
                  title: Tooltip(
                    message: 'Toque para escolher livro',
                    child: DevocionalBotaoTerciario(
                      onPressed: () => _controller.abrirSeletor(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Flexible com reticências porque a barra tem duas ações e um
                          // livro de nome longo em celular estreito estouraria a linha.
                          Flexible(
                            child: Text(
                              '${_controller.livroAtual.nome} $capitulo',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).appBarTheme.titleTextStyle,
                            ),
                          ),
                          const SizedBox(width: DevocionalEspacamento.sp8),
                          FaIcon(
                            FontAwesomeIcons.chevronDown,
                            color: cor.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    DevocionalIndicadorDeVozNaBarra(
                      chave: chaveDeCapitulo(livro, capitulo),
                    ),
                    DevocionalBotaoDeBusca(
                      aoBuscar: () => _controller.abrirBusca(context),
                    ),
                    const DevocionalBotaoDeNotas(),
                    DevocionalBotaoDeAjustes(estado: estado),
                  ],
                ),
                body: Focus(
                  autofocus: true,
                  child: DevocionalLarguraDeLeitura(
                    child: Column(
                      children: [
                        Expanded(
                          child: DevocionalCarregaUmaVez<Capitulo>(
                            chave: '$livro/$capitulo/$_tentativa',
                            carregar: () =>
                                Conteudo.instancia.capitulo(livro, capitulo),
                            construir: (context, snap) =>
                                _corpoDoCapitulo(context, estado, snap),
                          ),
                        ),
                        if (_controller.semGestoDeToque && estado.setasDoRodape)
                          DevocionalBarraDeCapitulo(
                            podeVoltar:
                                !(livro == canon.first.slug && capitulo == 1),
                            podeAvancar:
                                !(livro == canon.last.slug &&
                                    capitulo == canon.last.capitulos),
                            aoVoltar: () =>
                                _controller.passarCapitulo(context, -1),
                            aoAvancar: () =>
                                _controller.passarCapitulo(context, 1),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// O corpo do capítulo carregado: erro, espera, vazio, ou o leitor com o
  /// gesto de deslize e a alça de arraste. Extraído do [build] para cada caso
  /// ler direto, sem um método de duzentas linhas.
  Widget _corpoDoCapitulo(
    BuildContext context,
    Estado estado,
    AsyncSnapshot<Capitulo> snap,
  ) {
    if (snap.hasError) {
      return DevocionalAvisoDeErro(aoTentarDeNovo: _tentarDeNovo);
    }
    if (snap.connectionState != ConnectionState.done) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando'),
      );
    }
    final capitulo = snap.data!;
    // Os 66 livros estão completos e a navegação só pede capítulos do canon:
    // capítulo vazio é asset que não carregou (na web, quase sempre a rede).
    if (capitulo.versiculos.isEmpty) {
      return DevocionalAvisoDeErro(aoTentarDeNovo: _tentarDeNovo);
    }
    // Quem chegou por link, nota ou busca pediu um versículo exato; rolar até
    // ele precisa de um frame depois do capítulo montado.
    _controller.rolarAteOAlvoSePreciso(widget.destacar);
    // Arrastar na horizontal passa de capítulo. Vale na web também: arrasto
    // com o botão do mouse apertado dispara o mesmo reconhecedor. Só que
    // ninguém descobre isso sem um dedo na tela, e é por isso que os chevrons
    // continuam lá embaixo em quem não tem toque. Ver [BibliaControlador.semGestoDeToque].
    final leitor = Semantics(
      // Leitor de tela não faz o arrasto: o mesmo passo vira ação semântica.
      container: true,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Próximo capítulo'): () =>
            _controller.passarCapitulo(context, 1),
        const CustomSemanticsAction(label: 'Capítulo anterior'): () =>
            _controller.passarCapitulo(context, -1),
      },
      child: GestureDetector(
        onHorizontalDragEnd: (detalhe) =>
            _controller.aoArrastarCapitulo(context, detalhe),
        child: DevocionalLeitorDaBiblia(
          capitulo: capitulo,
          rolagem: _controller.rolagem,
          destacar: widget.destacar,
          alvoDeRolagem: widget.destacar?.$1,
          chaveDoAlvoDeRolagem: widget.destacar == null
              ? null
              : _controller.chaveDoAlvoDeRolagem,
          aoAbrirCapitulos: () => _controller.abrirGradeDeCapitulos(context),
          aoCarregarComentarios: widget.destacar == null
              ? null
              : () => _controller.rolarAteOAlvo(widget.destacar!.$1),
          selecionados: _controller.selecionados,
          aoAlternarSelecao: _controller.alternarSelecao,
        ),
      ),
    );
    // O texto não é selecionável (SelectionArea): no toque, o toque longo é a
    // entrada do modo de seleção de versículos, e a seleção de palavras
    // brigaria com ele. Copiar vive na folha do versículo e na barra da
    // seleção.
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) => Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                leitor,
                // A alça é um indício de que dá para deslizar, não um
                // controle: quem desliza usa a tela inteira como alvo de toque.
                if (!kIsWeb)
                  DevocionalAlcaDeDeslize(
                    primeiraVez: !estado.swipeTooltipDispensado,
                  ),
              ],
            ),
          ),
          if (_controller.selecionando)
            DevocionalBarraDaSelecao(
              capitulo: capitulo,
              selecionados: _controller.selecionados,
              aoFechar: _controller.limparSelecao,
            ),
        ],
      ),
    );
  }
}
