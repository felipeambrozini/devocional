import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/voz.dart';
import '../estilo/spacing.dart';
import '../funcoes/aviso.dart';
import '../funcoes/dialogos.dart';
import '../widgets/widgets.dart';
import 'busca.dart';

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
  late String _livro;
  late int _capitulo;
  final _rolagem = ScrollController();

  /// Uma única vez por instância: a aba retoma a última leitura, e quem
  /// chegou com destino explícito registra esse destino como última leitura.
  bool _inicializada = false;

  /// Onde cai o versículo pedido por link, nota ou busca ([widget.destacar]).
  /// GlobalKey porque o `Scrollable.ensureVisible` precisa do item já
  /// construído; sem ele não há como achar o versículo dentro do capítulo.
  final _chaveDoAlvoDeRolagem = GlobalKey();
  bool _rolouAteOAlvo = false;

  @override
  void initState() {
    super.initState();
    _livro = widget.livroInicial ?? 'genesis';
    _capitulo = widget.capituloInicial ?? 1;
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depender do TickerMode aqui é o que acorda este método quando a aba
    // Bíblia volta à frente: o go_router envolve cada aba em Offstage +
    // TickerMode, e a troca de aba liga e desliga o TickerMode.
    final ativa = TickerMode.valuesOf(context).enabled;
    final estado = EscopoDoEstado.de(context);
    final ultima = estado.ultimaLeitura;

    if (widget.livroInicial != null) {
      // Quem chegou com destino explícito (link, busca, nota, faixa) também
      // está lendo: esse destino vira a última leitura, para a aba Bíblia
      // abrir nele na próxima vez.
      if (!_inicializada) {
        _inicializada = true;
        final livro = widget.livroInicial!;
        final capitulo = widget.capituloInicial ?? 1;
        // Depois do frame: registrarLeitura avisa a árvore, e avisar no meio
        // do ciclo de build é proibido.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) estado.registrarLeitura(livro, capitulo);
        });
      }
      return;
    }

    // A aba: na primeira vez retoma a última leitura; nas seguintes, reabre
    // o último livro quando ele mudou por fora (tela empurrada, link, toque
    // de lembrete) e a aba volta à frente.
    if (!_inicializada) {
      _inicializada = true;
      if (ultima != null) {
        _livro = ultima.$1;
        _capitulo = ultima.$2;
      }
    } else if (ativa &&
        ultima != null &&
        (ultima.$1 != _livro || ultima.$2 != _capitulo)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _irPara(ultima.$1, ultima.$2);
      });
    }
  }

  Livro get _livroAtual => livroPorSlug(_livro) ?? canon.first;

  void _irPara(String livro, int capitulo) {
    // Um áudio tocando do capítulo antigo não pode continuar: o botão de
    // parar dele saiu da tela, e a leitura nova começa do zero. Um preparo em
    // curso não para aqui: o áudio ainda não toca, e o "Desfazer" do deslize
    // devolve a voz que ficou pronta.
    if (Voz.instancia.tocando || Voz.instancia.pausado) {
      Voz.instancia.parar();
    }
    setState(() {
      _livro = livro;
      _capitulo = capitulo;
    });
    EscopoDoEstado.de(context).registrarLeitura(livro, capitulo);
    if (_rolagem.hasClients) _rolagem.jumpTo(0);
  }

  void _passarCapitulo(int passo) {
    final destino = _capitulo + passo;
    if (destino >= 1 && destino <= _livroAtual.capitulos) {
      _irPara(_livro, destino);
      return;
    }
    // Passa para o livro vizinho em vez de travar no fim do último capítulo.
    final ordem = canon.indexWhere((l) => l.slug == _livro);
    final vizinho = ordem + passo;
    if (vizinho < 0 || vizinho >= canon.length) return;
    final livro = canon[vizinho];
    _irPara(livro.slug, passo > 0 ? 1 : livro.capitulos);
  }

  void _abrirBusca() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const TelaBusca()),
  );

  /// Grade de capítulos do livro aberto, direto pelo título do capítulo no
  /// corpo: um passo em vez dos dois do seletor de livros, e o caminho que
  /// não depende do deslize (que é invisível para quem chegou agora).
  Future<void> _abrirGradeDeCapitulos() async {
    final livro = _livroAtual;
    final capitulo = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => FolhaDeCapitulos(livro: livro),
    );
    if (capitulo != null && mounted) _irPara(livro.slug, capitulo);
  }

  /// Depois do capítulo aberto por link, nota ou busca, rola até o versículo
  /// pedido: quem chega por `?ler=joao.3.16` quer o versículo, não o topo do
  /// capítulo. Roda uma vez por abertura.
  void _rolarAteOAlvoSePreciso() {
    final alvo = widget.destacar;
    if (alvo == null || _rolouAteOAlvo) return;
    _rolouAteOAlvo = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _rolarAteOAlvo(alvo.$1),
    );
  }

  void _rolarAteOAlvo(int versiculo) {
    var tentativas = 0;
    void tentar() {
      final contexto = _chaveDoAlvoDeRolagem.currentContext;
      if (contexto != null) {
        Scrollable.ensureVisible(
          contexto,
          alignment: 0.3,
          duration: MediaQuery.disableAnimationsOf(contexto)
              ? Duration.zero
              : const Duration(milliseconds: 350),
        );
        return;
      }
      if (!mounted || ++tentativas >= 90 || !_rolagem.hasClients) return;
      // Estimativa bruta primeiro: corpo em 17 com altura 1.6, mais o respiro
      // de 24 dp do versículo. Só precisa chegar perto do item; o
      // ensureVisible acima ajusta o resto.
      if (tentativas == 1) {
        _rolagem.jumpTo(
          ((versiculo - 1) * 51)
              .clamp(0.0, _rolagem.position.maxScrollExtent)
              .toDouble(),
        );
      } else if (tentativas > 3) {
        // A estimativa errou (uma introdução aberta, por exemplo): avança em
        // blocos até o item entrar na árvore.
        _rolagem.jumpTo(
          (_rolagem.offset + 400)
              .clamp(0.0, _rolagem.position.maxScrollExtent)
              .toDouble(),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => tentar());
    }

    tentar();
  }

  void _aoArrastarCapitulo(DragEndDetails detalhe) {
    final horizontal = detalhe.primaryVelocity ?? 0;
    final vertical = detalhe.velocity.pixelsPerSecond.dy;
    // O corpo inteiro é um detector de arrasto horizontal em volta de uma
    // lista vertical. Sem dominância clara, um flick horizontal durante a
    // rolagem trocava de capítulo em silêncio; aqui o horizontal precisa
    // vencer o vertical por 2,5x para valer.
    if (horizontal.abs() < 250) return;
    if (vertical.abs() * 2.5 > horizontal.abs()) return;
    _passarCapituloComDesfazer(horizontal < 0 ? 1 : -1);
  }

  /// Passa de capítulo pelo deslize e oferece voltar: o deslize é o único
  /// jeito de trocar de capítulo no toque, e um acidente não pode custar o
  /// lugar na Escritura sem um "Desfazer" à mão. Setas e chevrons não passam
  /// por aqui: são escolhas explícitas e não pedem volta.
  void _passarCapituloComDesfazer(int passo) {
    // O tooltip do deslize some quando o gesto acontece de verdade: um toque
    // distraído na alça não pode apagar o único aviso do gesto (o antigo
    // onPointerDown fazia isso); só o uso do gesto que ele ensina dispensa.
    final estado = EscopoDoEstado.de(context);
    if (!estado.swipeTooltipDispensado) {
      estado.dispensarSwipeTooltip();
    }
    final livroAnterior = _livro;
    final capituloAnterior = _capitulo;
    // A voz em curso (tocando, pausada ou no preparo) tem de voltar junto
    // com a página: desfazer o deslize sem devolver o áudio seria desfazer
    // pela metade.
    final chaveDaLeitura = Voz.instancia.tocandoChave;
    _passarCapitulo(passo);
    mostrarAviso(
      context,
      '${_livroAtual.nome} $_capitulo',
      rotuloDeAcao: 'Desfazer',
      aoAgir: () {
        if (!mounted) return;
        _irPara(livroAnterior, capituloAnterior);
        if (chaveDaLeitura != null) {
          Voz.instancia.retomar(
            chaveDeCapitulo(livroAnterior, capituloAnterior),
            de: Voz.instancia.desdeAParada,
          );
        }
      },
    );
  }

  /// Se vale a pena gastar uma faixa do rodapé com os chevrons de capítulo.
  ///
  /// No celular não vale: deslizar já passa a página, e a barra ficava logo
  /// acima da barra de navegação repetindo o que o dedo faz. Na web vale,
  /// porque ali quem usa só o mouse não tem gesto: arrastar com o botão
  /// apertado funciona, mas ninguém descobre isso, e as setas do teclado também
  /// não se anunciam. Mesmo lá é escolha: quem navega pelo teclado esconde os
  /// botões na folha de ajustes ([Estado.setasDoRodape]).
  ///
  /// É a única ramificação por plataforma do app, e existe porque a forma de
  /// apontar muda de verdade entre elas. A web pode estar num desktop sem
  /// toque, então entra pelo pior caso.
  bool get _semGestoDeToque => kIsWeb;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final estado = EscopoDoEstado.de(context);
    // Teclado na web: as setas passam de capítulo e Ctrl+F abre a
    // busca, que antes só existiam como dois chevrons pequenos no rodapé e um
    // ícone na barra. Setas horizontais não rolam uma lista vertical, então não
    // há conflito com a rolagem do capítulo.
    //
    // Envolve a tela inteira, e não só o corpo: o evento de tecla sobe a partir
    // de quem tem o foco, e dentro da moldura o foco costuma cair num botão da
    // AppBar. Com o atalho só no corpo, a tecla passava por fora dele e nada
    // acontecia.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _passarCapitulo(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _passarCapitulo(-1),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _abrirBusca,
      },
      child: Scaffold(
        appBar: AppBar(
          title: Tooltip(
            message: 'Toque para escolher capítulo',
            child: TextButton(
              onPressed: _abrirSeletor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible com reticências porque a barra tem duas ações e um
                  // livro de nome longo em celular estreito estouraria a linha.
                  Flexible(
                    child: Text(
                      '${_livroAtual.nome} $_capitulo',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).appBarTheme.titleTextStyle,
                    ),
                  ),
                  Icon(Icons.expand_more, color: cor.primary, size: 20),
                ],
              ),
            ),
          ),
          actions: [
            IndicadorDeVozNaBarra(chave: chaveDeCapitulo(_livro, _capitulo)),
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search),
              onPressed: _abrirBusca,
            ),
            IconButton(
              tooltip: 'Tamanho do texto e aparência',
              icon: const Icon(Icons.tune),
              onPressed: () => ajustesDeLeitura(context, estado),
            ),
          ],
        ),
        body: Focus(
          autofocus: true,
          child: LarguraDeLeitura(
            child: Column(
              children: [
                Expanded(
                  child: CarregaUmaVez<Capitulo>(
                    chave: '$_livro/$_capitulo',
                    carregar: () =>
                        Conteudo.instancia.capitulo(_livro, _capitulo),
                    construir: (context, snap) =>
                        _corpoDoCapitulo(context, estado, snap),
                  ),
                ),
                if (_semGestoDeToque && estado.setasDoRodape)
                  _BarraDeCapitulo(
                    podeVoltar: !(_livro == canon.first.slug && _capitulo == 1),
                    podeAvancar:
                        !(_livro == canon.last.slug &&
                            _capitulo == canon.last.capitulos),
                    aoVoltar: () => _passarCapitulo(-1),
                    aoAvancar: () => _passarCapitulo(1),
                  ),
              ],
            ),
          ),
        ),
      ),
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
    if (snap.hasError) return const AvisoDeErro();
    if (snap.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    final capitulo = snap.data!;
    if (capitulo.versiculos.isEmpty) {
      return const AvisoVazio(
        icone: Icons.menu_book_outlined,
        titulo: 'Capítulo não encontrado',
      );
    }
    // Quem chegou por link, nota ou busca pediu um versículo exato; rolar até
    // ele precisa de um frame depois do capítulo montado.
    _rolarAteOAlvoSePreciso();
    // Arrastar na horizontal passa de capítulo. Vale na web também: arrasto
    // com o botão do mouse apertado dispara o mesmo reconhecedor. Só que
    // ninguém descobre isso sem um dedo na tela, e é por isso que os chevrons
    // continuam lá embaixo em quem não tem toque. Ver [_semGestoDeToque].
    final leitor = GestureDetector(
      onHorizontalDragEnd: _aoArrastarCapitulo,
      child: _Leitor(
        capitulo: capitulo,
        rolagem: _rolagem,
        destacar: widget.destacar,
        alvoDeRolagem: widget.destacar?.$1,
        chaveDoAlvoDeRolagem: widget.destacar == null
            ? null
            : _chaveDoAlvoDeRolagem,
        aoAbrirCapitulos: _abrirGradeDeCapitulos,
      ),
    );
    // Só no toque o texto vira selecionável: por lá o dedo escolhe com um
    // toque e seleciona com pressão longa, sem brigar com o deslize de
    // capítulo. No mouse (web) a seleção por arrasto disputaria a arena com o
    // gesto de capítulo, então lá Copiar pela folha do versículo continua
    // sendo o caminho.
    final corpoLeitura = _semGestoDeToque
        ? leitor
        : SelectionArea(child: leitor);
    return ListenableBuilder(
      listenable: estado,
      builder: (context, _) => Stack(
        children: [
          corpoLeitura,
          // A alça é um indício de que dá para deslizar, não um controle:
          // quem desliza usa a tela inteira como alvo de toque.
          if (!kIsWeb)
            _AlcaDeDeslize(primeiraVez: !estado.swipeTooltipDispensado),
        ],
      ),
    );
  }

  Future<void> _abrirSeletor() async {
    final destino = await showModalBottomSheet<(String, int)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SeletorDeLivro(livroAtual: _livro),
    );
    if (destino != null && mounted) _irPara(destino.$1, destino.$2);
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
  });

  final Capitulo capitulo;
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
        Spacing.sp20,
        Spacing.sp8,
        Spacing.sp20,
        Spacing.sp32,
      ),
      itemCount: capitulo.versiculos.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O cartão é o único caminho para a introdução, então fica
              // disponível em todo capítulo, não só antes do primeiro.
              AberturaDeLivro(slug: capitulo.livro),
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
                const SizedBox(height: Spacing.sp4),
              ],
              Semantics(
                button: aoAbrirCapitulos != null,
                child: aoAbrirCapitulos == null
                    ? Text(capitulo.referencia, style: tema.displayMedium)
                    : Tooltip(
                        // O mesmo atalho da AppBar: a referência no corpo
                        // também abre a grade, e só a AppBar tinha a dica.
                        message: 'Toque para escolher o capítulo',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: aoAbrirCapitulos,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Spacing.sp4,
                              horizontal: Spacing.sp2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  capitulo.referencia,
                                  style: tema.displayMedium,
                                ),
                                const SizedBox(width: Spacing.sp8),
                                Icon(
                                  Icons.expand_more,
                                  size: 22,
                                  color: cor.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: Spacing.sp8),
              const Filete(),
              // A voz de Spurgeon lê o capítulo inteiro, do título ao último
              // versículo; tocar de novo para a leitura.
              const SizedBox(height: Spacing.sp14),
              BotaoDeVoz(
                chave: chaveDeCapitulo(capitulo.livro, capitulo.numero),
              ),
              if (capitulo.titulo.isNotEmpty) ...[
                const SizedBox(height: Spacing.sp12),
                Text(
                  capitulo.titulo,
                  style: tema.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cor.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: Spacing.sp16),
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
  });

  final String livro;
  final int capituloNumero;
  final String referencia;
  final int numero;
  final String texto;
  final bool noRecorte;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);
    final marcacao = estado.marcacaoDe(livro, capituloNumero, numero);

    return Semantics(
      hint: 'Toque para favoritar, anotar ou copiar',
      child: InkWell(
        onTap: () => _abrirAcoesDoVersiculo(
          context,
          estado,
          livro: livro,
          capituloNumero: capituloNumero,
          referencia: referencia,
          numero: numero,
          texto: texto,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          // 12 e não 7: com bodyLarge em 17 e altura 1.6, um versículo de uma
          // linha ficava em cerca de 41 dp de alvo, abaixo dos 48 dp mínimos.
          // Os curtos são justamente os mais marcados.
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.sp12,
            horizontal: Spacing.sp6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: marcacao != null
                ? cor.outline.withValues(alpha: 0.18)
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
                      style: tema.labelMedium?.copyWith(
                        color: cor.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: texto,
                      // Fora da faixa pedida pelo cronograma o texto continua
                      // legível, apenas recuado, para o contexto não se perder.
                      //
                      // 0.7 e não 0.55: sobre o fundo, 0.55 dava 3,5:1 de
                      // contraste, abaixo do 4,5:1 que a WCAG AA pede para
                      // texto corrido, e isto aqui é Escritura, não legenda.
                      // 0.7 chega a 4,9:1 e ainda se distingue do texto pedido.
                      style: noRecorte
                          ? tema.bodyLarge?.copyWith(height: 1.6)
                          : tema.bodyLarge?.copyWith(
                              height: 1.6,
                              color: cor.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              if (marcacao != null && marcacao.nota.isNotEmpty) ...[
                const SizedBox(height: Spacing.sp6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit_note, size: 15, color: cor.primary),
                    const SizedBox(width: Spacing.sp6),
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

  Widget folha(BuildContext contextoDaFolha) {
    final cor = Theme.of(contextoDaFolha).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sp20,
                Spacing.sp20,
                Spacing.sp8,
                Spacing.sp20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$referencia:$numero',
                    style: Theme.of(contextoDaFolha).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Spacing.sp8),
                  Text(
                    texto,
                    style: Theme.of(contextoDaFolha).textTheme.bodyMedium,
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

  ListTile _itemFavoritar(BuildContext folha, ColorScheme cor) {
    return ListTile(
      leading: Icon(
        marcacao != null ? Icons.bookmark : Icons.bookmark_outline,
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
        if (eraFavorito &&
            !estado.ehFavorito(livro, capituloNumero, numero)) {
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
      leading: Icon(Icons.content_copy_outlined, color: cor.primary),
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
      leading: Icon(Icons.ios_share_outlined, color: cor.primary),
      title: const Text('Compartilhar'),
      onTap: () async {
        final navegador = Navigator.of(folha);
        await SharePlus.instance.share(ShareParams(text: _textoDoVersiculo));
        navegador.pop();
      },
    );
  }

  ListTile _itemAnotar(BuildContext folha) {
    return ListTile(
      leading: Icon(
        Icons.edit_note,
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
  String get _textoDoVersiculo =>
      '"$texto"\n$referencia:$numero\n'
      '${linkDoVersiculo(livro, capituloNumero, numero)}';
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
  final acoes = _AcoesDoVersiculo(
    estado: estado,
    livro: livro,
    capituloNumero: capituloNumero,
    referencia: referencia,
    numero: numero,
    texto: texto,
    marcacao: marcacao,
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

/// A alça de arraste na borda esquerda do leitor (mobile): o gradiente e o
/// ícone indicam que deslizar horizontalmente troca de capítulo. O tooltip de
/// primeiro uso só some quando o gesto acontece de verdade (ver
/// `_passarCapituloComDesfazer`). Um toque nela não faz nada: quem desliza
/// usa a tela inteira como alvo, muito maior que os 48px mínimos.
class _AlcaDeDeslize extends StatelessWidget {
  const _AlcaDeDeslize({required this.primeiraVez});

  final bool primeiraVez;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 24,
      child: Tooltip(
        message: primeiraVez ? 'Arraste para trocar capítulo' : '',
        child: Semantics(
          label: primeiraVez ? 'Arraste para trocar capítulo' : '',
          child: Container(
            width: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  cor.primary.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: cor.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rodapé com os dois chevrons de capítulo.
///
/// Só é montado onde não há gesto de toque; ver `_semGestoDeToque` em
/// [_TelaBibliaState]. No celular deslizar já faz isso, e a barra custava uma
/// faixa do fim de toda tela, logo acima da barra de navegação.
class _BarraDeCapitulo extends StatelessWidget {
  const _BarraDeCapitulo({
    required this.podeVoltar,
    required this.podeAvancar,
    required this.aoVoltar,
    required this.aoAvancar,
  });

  final bool podeVoltar;
  final bool podeAvancar;
  final VoidCallback aoVoltar;
  final VoidCallback aoAvancar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp12,
          vertical: Spacing.sp4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Capítulo anterior',
              onPressed: podeVoltar ? aoVoltar : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Próximo capítulo',
              onPressed: podeAvancar ? aoAvancar : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
