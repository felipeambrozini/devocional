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
import '../estilo/tema.dart';
import '../funcoes/aviso.dart';
import '../funcoes/cartao_imagem.dart';
import '../funcoes/dialogos.dart';
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
        child: _Leitor(
          capitulo: capitulo,
          rolagem: _controller.rolagem,
          destacar: widget.destacar,
          alvoDeRolagem: widget.destacar?.$1,
          chaveDoAlvoDeRolagem: widget.destacar == null
              ? null
              : _controller.chaveDoAlvoDeRolagem,
          aoAbrirCapitulos: () => _controller.abrirGradeDeCapitulos(context),
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
            _BarraDaSelecao(
              capitulo: capitulo,
              selecionados: _controller.selecionados,
              aoFechar: _controller.limparSelecao,
            ),
        ],
      ),
    );
  }
}

class _Leitor extends StatelessWidget {
  const _Leitor({
    required this.capitulo,
    required this.rolagem,
    this.destacar,
    this.alvoDeRolagem,
    this.chaveDoAlvoDeRolagem,
    this.aoAbrirCapitulos,
    required this.selecionados,
    required this.aoAlternarSelecao,
  });

  final Capitulo capitulo;

  /// Versículos marcados para copiar ou compartilhar juntos; ver
  /// [BibliaControlador.selecionados].
  final Set<int> selecionados;
  final ValueChanged<int> aoAlternarSelecao;
  final ScrollController rolagem;
  final (int, int)? destacar;

  /// Versículo para onde rolar ao abrir (o primeiro da faixa pedida). Sempre
  /// nulo no uso comum; só link, nota e busca pedem um versículo exato.
  final int? alvoDeRolagem;
  final GlobalKey? chaveDoAlvoDeRolagem;

  /// Sem o deslize (que é invisível), o título do capítulo no corpo abre a
  /// grade de capítulos num toque.
  final VoidCallback? aoAbrirCapitulos;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;

    return ListView.builder(
      controller: rolagem,
      padding: const EdgeInsets.fromLTRB(
        DevocionalEspacamento.sp20,
        DevocionalEspacamento.sp8,
        DevocionalEspacamento.sp20,
        DevocionalEspacamento.sp32,
      ),
      itemCount: capitulo.versiculos.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O cartão é o único caminho para a introdução, então fica
              // disponível em todo capítulo, não só antes do primeiro.
              DevocionalAberturaDeLivro(slug: capitulo.livro),
              // O título completo do livro só aparece no capítulo 1: é a
              // abertura do livro, não algo para repetir a cada capítulo.
              if (capitulo.numero == 1) ...[
                Text(
                  livroPorSlug(capitulo.livro)!.tituloFormal,
                  style: tema.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cor.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DevocionalEspacamento.sp4),
              ],
              Semantics(
                header: true,
                button: aoAbrirCapitulos != null,
                child: aoAbrirCapitulos == null
                    ? Text(capitulo.referencia, style: tema.displayMedium)
                    : Tooltip(
                        // O mesmo atalho da AppBar: a referência no corpo
                        // também abre a grade, e só a AppBar tinha a dica.
                        message: 'Toque para escolher o capítulo',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: aoAbrirCapitulos,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: DevocionalEspacamento.sp4,
                              horizontal: DevocionalEspacamento.sp2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  capitulo.referencia,
                                  style: tema.displayMedium,
                                ),
                                const SizedBox(
                                  width: DevocionalEspacamento.sp8,
                                ),
                                // Grade, não chevron: este título abre a grade
                                // de capítulos do livro, enquanto o da AppBar
                                // (chevron) troca de livro.
                                FaIcon(
                                  FontAwesomeIcons.tableCells,
                                  size: 20,
                                  color: cor.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: DevocionalEspacamento.sp8),
              const DevocionalFilete(),
              // A voz de Spurgeon lê o capítulo inteiro, do título ao último
              // versículo; tocar de novo para a leitura.
              const SizedBox(height: DevocionalEspacamento.sp14),
              DevocionalBotaoDeVoz(
                chave: chaveDeCapitulo(capitulo.livro, capitulo.numero),
              ),
              if (capitulo.titulo.isNotEmpty) ...[
                const SizedBox(height: DevocionalEspacamento.sp12),
                Text(
                  capitulo.titulo,
                  style: tema.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cor.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: DevocionalEspacamento.sp16),
            ],
          );
        }

        final (numero, texto) = capitulo.versiculos[i - 1];
        final noRecorte =
            destacar == null ||
            (numero >= destacar!.$1 && numero <= destacar!.$2);

        return _LinhaDeVersiculo(
          key: chaveDoAlvoDeRolagem != null && numero == alvoDeRolagem
              ? chaveDoAlvoDeRolagem
              : null,
          livro: capitulo.livro,
          capituloNumero: capitulo.numero,
          referencia: capitulo.referencia,
          numero: numero,
          texto: texto,
          noRecorte: noRecorte,
          selecionando: selecionados.isNotEmpty,
          selecionado: selecionados.contains(numero),
          aoAlternarSelecao: () => aoAlternarSelecao(numero),
        );
      },
    );
  }
}

/// Um versículo: número, texto e, se houver, a nota. Usado tanto pelo leitor
/// de uma coluna quanto por cada lado do leitor duplo.
class _LinhaDeVersiculo extends StatelessWidget {
  const _LinhaDeVersiculo({
    super.key,
    required this.livro,
    required this.capituloNumero,
    required this.referencia,
    required this.numero,
    required this.texto,
    required this.noRecorte,
    required this.selecionando,
    required this.selecionado,
    required this.aoAlternarSelecao,
  });

  final String livro;
  final int capituloNumero;
  final String referencia;
  final int numero;
  final String texto;
  final bool noRecorte;

  /// Há versículos marcados no capítulo: o toque marca em vez de abrir a folha.
  final bool selecionando;
  final bool selecionado;
  final VoidCallback aoAlternarSelecao;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);
    final marcacao = estado.marcacaoDe(livro, capituloNumero, numero);
    final temNota = marcacao != null && marcacao.nota.trim().isNotEmpty;

    // A marcação era só visual (fundo a 18%): quem usa leitor de tela não
    // sabia o que já marcou. O estado vai no rótulo, não só na cor.
    return Semantics(
      label:
          '$referencia:$numero'
          '${marcacao == null ? '' : ', favoritado'}'
          '${temNota ? ', com anotação' : ''}',
      selected: selecionando ? selecionado : marcacao != null,
      hint: selecionando
          ? 'Toque para marcar ou desmarcar'
          : 'Toque para favoritar, anotar ou copiar; toque longo para '
                'selecionar vários',
      child: InkWell(
        // Toque longo é a entrada do modo de seleção; dentro dele, marcar e
        // desmarcar é o toque simples.
        onLongPress: selecionando ? null : aoAlternarSelecao,
        onTap: selecionando
            ? aoAlternarSelecao
            : () => _abrirAcoesDoVersiculo(
                context,
                estado,
                livro: livro,
                capituloNumero: capituloNumero,
                referencia: referencia,
                numero: numero,
                texto: texto,
              ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // 12 e não 7: com bodyLarge em 17 e altura 1.6, um versículo de uma
          // linha ficava em cerca de 41 dp de alvo, abaixo dos 48 dp mínimos.
          // Os curtos são justamente os mais marcados.
          padding: const EdgeInsets.symmetric(
            vertical: DevocionalEspacamento.sp12,
            horizontal: DevocionalEspacamento.sp6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selecionado
                ? cor.primary.withValues(alpha: 0.18)
                : marcacao != null
                ? cor.outline.withValues(alpha: 0.18)
                : null,
            border: selecionado
                ? Border.all(color: cor.primary, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$numero ',
                      style: tema.labelMedium
                          ?.copyWith(color: cor.primary)
                          .comPeso(FontWeight.w700),
                    ),
                    if (marcacao != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: DevocionalEspacamento.sp6,
                          ),
                          child: FaIcon(
                            FontAwesomeIcons.solidBookmark,
                            size: 11,
                            color: cor.primary,
                          ),
                        ),
                      ),
                    TextSpan(
                      text: texto,
                      // Fora da faixa pedida pelo cronograma o texto continua
                      // legível, apenas recuado, para o contexto não se perder.
                      //
                      // onSurface a 0.75 e não onSurfaceVariant a 0.7: este
                      // dava cerca de 3,1:1 no tema claro, abaixo do 4,5:1 que
                      // a WCAG AA pede para texto corrido, e isto aqui é
                      // Escritura, não legenda.
                      style: noRecorte
                          ? tema.bodyLarge?.copyWith(height: 1.6)
                          : tema.bodyLarge?.copyWith(
                              height: 1.6,
                              color: cor.onSurface.withValues(alpha: 0.75),
                            ),
                    ),
                  ],
                ),
              ),
              if (marcacao != null && marcacao.nota.isNotEmpty) ...[
                const SizedBox(height: DevocionalEspacamento.sp6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.penToSquare,
                      size: 15,
                      color: cor.primary,
                    ),
                    const SizedBox(width: DevocionalEspacamento.sp6),
                    Expanded(
                      child: Text(
                        marcacao.nota,
                        style: tema.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A folha de ações de um versículo: favoritar (com desfazer), copiar,
/// compartilhar e anotar, mais o "Tela cheia" no cabeçalho. Um objeto por
/// abertura: os closures das ações leem o snapshot da marcação feito antes da
/// folha abrir — recalcular dentro dos itens mudaria o que se vê ao tocar.
class _AcoesDoVersiculo {
  const _AcoesDoVersiculo({
    required this.estado,
    required this.livro,
    required this.capituloNumero,
    required this.referencia,
    required this.numero,
    required this.texto,
    required this.marcacao,
    required this.comentario,
  });

  final Estado estado;
  final String livro;
  final int capituloNumero;

  /// Referência do capítulo ("João 3"), sem o número do versículo.
  final String referencia;
  final int numero;
  final String texto;

  /// A marcação como estava na hora em que a folha abriu.
  final Marcacao? marcacao;

  /// Comentário de Spurgeon sobre este versículo, se já escrito. Criado uma
  /// vez antes da folha abrir, para os redesenhos não refazerem o pedido.
  final Future<String?> comentario;

  Widget folha(BuildContext contextoDaFolha) {
    final cor = Theme.of(contextoDaFolha).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DevocionalEspacamento.sp20,
                DevocionalEspacamento.sp20,
                DevocionalEspacamento.sp8,
                DevocionalEspacamento.sp20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$referencia:$numero',
                    style: Theme.of(contextoDaFolha).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp8),
                  Text(
                    texto,
                    style: Theme.of(contextoDaFolha).textTheme.bodyMedium,
                  ),
                  FutureBuilder<String?>(
                    future: comentario,
                    builder: (context, snap) => _comentario(context, cor, snap),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _itemFavoritar(contextoDaFolha, cor),
            // Copiar é o que mais se faz com um versículo, e não existia. Vem
            // antes de anotar porque é a ação sem consequência das três.
            _itemCopiar(contextoDaFolha, cor),
            _itemCompartilhar(contextoDaFolha, cor),
            _itemAnotar(contextoDaFolha),
          ],
        ),
      ),
    );
  }

  Widget _comentario(
    BuildContext context,
    ColorScheme cor,
    AsyncSnapshot<String?> snap,
  ) {
    if (snap.connectionState != ConnectionState.done) {
      return const Padding(
        padding: EdgeInsets.only(top: DevocionalEspacamento.sp16),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: 'Carregando',
          ),
        ),
      );
    }
    final texto = snap.data;
    if (texto == null || texto.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: DevocionalEspacamento.sp16),
        Text(
          'Comentário de Charles Spurgeon',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: cor.primary)
              .comPeso(FontWeight.w700),
        ),
        const SizedBox(height: DevocionalEspacamento.sp8),
        DevocionalBotaoDeVoz(
          chave: chaveDoComentario(livro, capituloNumero, numero),
          referencia: '$referencia:$numero, comentário',
        ),
        const SizedBox(height: DevocionalEspacamento.sp8),
        Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  ListTile _itemFavoritar(BuildContext folha, ColorScheme cor) {
    return ListTile(
      leading: FaIcon(
        marcacao != null
            ? FontAwesomeIcons.solidBookmark
            : FontAwesomeIcons.bookmark,
        color: cor.primary,
      ),
      title: Text(marcacao != null ? 'Remover dos favoritos' : 'Favoritar'),
      onTap: () {
        final eraFavorito = marcacao != null;
        estado.alternarFavorito(livro, capituloNumero, numero);
        Navigator.pop(folha);
        // Remover é a única ação da folha sem volta, e o mesmo toque que
        // remove oferece o "Desfazer" (o padrão do deslize de capítulo). Com
        // nota o alternarFavorito se recusa a remover (a nota manda, ver
        // estado.dart), e nesse caso não há o que desfazer.
        if (eraFavorito && !estado.ehFavorito(livro, capituloNumero, numero)) {
          final mensageiro = ScaffoldMessenger.of(folha);
          mostrarAvisoNo(
            mensageiro,
            'Removido dos favoritos.',
            rotuloDeAcao: 'Desfazer',
            aoAgir: () =>
                estado.alternarFavorito(livro, capituloNumero, numero),
          );
        }
      },
    );
  }

  ListTile _itemCopiar(BuildContext folha, ColorScheme cor) {
    return ListTile(
      leading: FaIcon(FontAwesomeIcons.copy, color: cor.primary),
      title: const Text('Copiar'),
      onTap: () async {
        final mensageiro = ScaffoldMessenger.of(folha);
        final navegador = Navigator.of(folha);
        await Clipboard.setData(ClipboardData(text: _textoDoVersiculo));
        navegador.pop();
        mostrarAvisoNo(mensageiro, 'Versículo copiado.');
      },
    );
  }

  ListTile _itemCompartilhar(BuildContext folha, ColorScheme cor) {
    return ListTile(
      leading: FaIcon(FontAwesomeIcons.arrowUpFromBracket, color: cor.primary),
      title: const Text('Compartilhar'),
      onTap: () async {
        final navegador = Navigator.of(folha);
        final mensageiro = ScaffoldMessenger.of(folha);
        try {
          // Cartão-imagem com o texto junto: rende no WhatsApp e no
          // Instagram, onde texto puro morre sem rosto. O texto que acompanha
          // é o mesmo de Copiar, com o link que reabre o versículo.
          await compartilharCartao(
            texto: '"$texto"',
            referencia: '$referencia:$numero',
            link: linkDoVersiculo(livro, capituloNumero, numero),
            textoParaAcompanhar: _textoDoVersiculo,
          );
        } catch (_) {
          mostrarErroNo(mensageiro, 'Não foi possível compartilhar.');
        }
        navegador.pop();
      },
    );
  }

  ListTile _itemAnotar(BuildContext folha) {
    return ListTile(
      leading: FaIcon(
        FontAwesomeIcons.penToSquare,
        color: Theme.of(folha).colorScheme.primary,
      ),
      title: Text(
        marcacao?.nota.isNotEmpty == true ? 'Editar anotação' : 'Anotar',
      ),
      onTap: () async {
        final nota = await editarNota(
          folha,
          referencia: '$referencia:$numero',
          notaAtual: marcacao?.nota ?? '',
        );
        if (nota != null) {
          await estado.definirNota(livro, capituloNumero, numero, nota);
        }
        if (folha.mounted) Navigator.pop(folha);
      },
    );
  }

  /// O mesmo texto para Copiar e Compartilhar. O link vale em qualquer
  /// plataforma, não só na web: é assim que quem recebe chega direto ao
  /// versículo, mesmo copiado ou compartilhado do celular numa live.
  String get _textoDoVersiculo => _textoCitado(
    texto: texto,
    referencia: '$referencia:$numero',
    link: linkDoVersiculo(livro, capituloNumero, numero),
  );
}

String _textoCitado({
  required String texto,
  required String referencia,
  required String link,
}) => '"$texto"\n$referencia\n$link';

/// A barra de baixo do modo de seleção: quantos versículos estão marcados e
/// as ações que valem para todos eles. Copiar e Compartilhar usam o mesmo
/// texto da folha de um versículo só, com a referência em faixa
/// ("João 3:16-18") e o link do primeiro versículo marcado.
class _BarraDaSelecao extends StatelessWidget {
  const _BarraDaSelecao({
    required this.capitulo,
    required this.selecionados,
    required this.aoFechar,
  });

  final Capitulo capitulo;
  final Set<int> selecionados;
  final VoidCallback aoFechar;

  String get _referencia =>
      referenciaDeVersiculos(capitulo.referencia, selecionados);

  /// Os textos dos marcados na ordem do capítulo, não na ordem dos toques.
  String get _texto => capitulo.versiculos
      .where((v) => selecionados.contains(v.$1))
      .map((v) => v.$2)
      .join(' ');

  String get _link => linkDoVersiculo(
    capitulo.livro,
    capitulo.numero,
    (selecionados.toList()..sort()).first,
  );

  Future<void> _copiar(BuildContext context) async {
    final mensageiro = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(
        text: _textoCitado(texto: _texto, referencia: _referencia, link: _link),
      ),
    );
    aoFechar();
    mostrarAvisoNo(mensageiro, 'Versículos copiados.');
  }

  Future<void> _compartilhar(BuildContext context) async {
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      await compartilharCartao(
        texto: '"$_texto"',
        referencia: _referencia,
        link: _link,
        textoParaAcompanhar: _textoCitado(
          texto: _texto,
          referencia: _referencia,
          link: _link,
        ),
      );
    } catch (_) {
      mostrarErroNo(mensageiro, 'Não foi possível compartilhar.');
    }
    aoFechar();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Material(
      color: cor.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DevocionalEspacamento.sp8,
            vertical: DevocionalEspacamento.sp4,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancelar seleção',
                onPressed: aoFechar,
                icon: const FaIcon(FontAwesomeIcons.xmark),
              ),
              Expanded(
                child: Text(
                  selecionados.length == 1
                      ? '1 versículo'
                      : '${selecionados.length} versículos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Copiar',
                onPressed: () => _copiar(context),
                icon: FaIcon(FontAwesomeIcons.copy, color: cor.primary),
              ),
              IconButton(
                tooltip: 'Compartilhar',
                onPressed: () => _compartilhar(context),
                icon: FaIcon(
                  FontAwesomeIcons.arrowUpFromBracket,
                  color: cor.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _abrirAcoesDoVersiculo(
  BuildContext context,
  Estado estado, {
  required String livro,
  required int capituloNumero,
  required String referencia,
  required int numero,
  required String texto,
}) async {
  final marcacao = estado.marcacaoDe(livro, capituloNumero, numero);
  // A folha abre já e o comentário chega dentro dela: o primeiro toque num
  // livro baixa o arquivo de comentários inteiro (1 MB em Salmos), e esperar
  // por ele antes de abrir deixava o toque sem resposta na web.
  final comentario = Conteudo.instancia.comentario(
    livro,
    capituloNumero,
    numero,
  );
  final acoes = _AcoesDoVersiculo(
    estado: estado,
    livro: livro,
    capituloNumero: capituloNumero,
    referencia: referencia,
    numero: numero,
    texto: texto,
    marcacao: marcacao,
    comentario: comentario,
  );
  await showModalBottomSheet<void>(
    context: context,
    // Quatro ações mais o cabeçalho passam da altura em telas baixas ou em
    // paisagem — mesmo motivo e mesma solução de ajustesDeLeitura, em
    // widgets/folha_de_ajustes.dart: isScrollControlled deixa a folha crescer, e o
    // SingleChildScrollView rola o que não couber em vez de estourar.
    isScrollControlled: true,
    builder: acoes.folha,
  );
}
