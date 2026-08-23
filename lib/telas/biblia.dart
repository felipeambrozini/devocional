import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/voz.dart';
import '../spacing.dart';
import 'busca.dart';
import 'comuns.dart';
import 'introducao.dart';

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
      builder: (_) => _FolhaDeCapitulos(livro: livro),
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
                  // Flexible com reticências porque a barra ganhou três ações e um
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
              tooltip: 'Tamanho do texto e aparência',
              icon: const Icon(Icons.tune),
              onPressed: () => ajustesDeLeitura(context, estado),
            ),
            IconButton(
              tooltip: 'Introdução de Spurgeon',
              icon: const Icon(Icons.article_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TelaIntroducao(slug: _livro)),
              ),
            ),
            IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.search),
              onPressed: _abrirBusca,
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
                    carregar: () => Conteudo.instancia.capitulo(
                      Versao.bkj,
                      _livro,
                      _capitulo,
                    ),
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
        versao: Versao.bkj,
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
      builder: (_) => _SeletorDeLivro(livroAtual: _livro),
    );
    if (destino != null && mounted) _irPara(destino.$1, destino.$2);
  }
}

class _Leitor extends StatelessWidget {
  const _Leitor({
    required this.capitulo,
    required this.versao,
    required this.rolagem,
    this.destacar,
    this.alvoDeRolagem,
    this.chaveDoAlvoDeRolagem,
    this.aoAbrirCapitulos,
  });

  final Capitulo capitulo;

  /// A marcação é ligada explicitamente à tradução interna.
  final Versao versao;
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
              // A introdução do livro fica disponível em todo capítulo, não só
              // antes do primeiro, para não depender de abrir a tela pela AppBar.
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
                texto: textoDeCapitulo(capitulo),
                tipo: TipoConteudoAudio.biblia,
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
          versao: versao,
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
/// de uma coluna quanto por cada lado do leitor duplo — [versao] é sempre
/// explícito porque no leitor duplo as duas colunas aparecem juntas, sem uma
/// "versão atual" só.
class _LinhaDeVersiculo extends StatelessWidget {
  const _LinhaDeVersiculo({
    super.key,
    required this.versao,
    required this.livro,
    required this.capituloNumero,
    required this.referencia,
    required this.numero,
    required this.texto,
    required this.noRecorte,
  });

  final Versao versao;
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
    final marcacao = estado.marcacaoDe(versao, livro, capituloNumero, numero);

    return Semantics(
      hint: 'Toque para favoritar, anotar ou copiar',
      child: InkWell(
        onTap: () => _abrirAcoesDoVersiculo(
          context,
          estado,
          versao: versao,
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
    required this.versao,
    required this.livro,
    required this.capituloNumero,
    required this.referencia,
    required this.numero,
    required this.texto,
    required this.marcacao,
  });

  final Estado estado;
  final Versao versao;
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$referencia:$numero',
                          style: Theme.of(
                            contextoDaFolha,
                          ).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: Spacing.sp8),
                        Text(
                          texto,
                          style: Theme.of(contextoDaFolha).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // "Tela cheia" é a ação de quem está ao vivo, não uma das
                  // rotinas do dia; mora no cabeçalho, e não na lista de
                  // ações com o mesmo peso de Favoritar e Copiar.
                  IconButton(
                    tooltip: 'Tela cheia',
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      Navigator.pop(contextoDaFolha);
                      Navigator.push(
                        contextoDaFolha,
                        MaterialPageRoute(
                          builder: (_) => TelaApresentacao(
                            texto: texto,
                            referencia: '$referencia:$numero',
                          ),
                        ),
                      );
                    },
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
        estado.alternarFavorito(versao, livro, capituloNumero, numero);
        Navigator.pop(folha);
        // Remover é a única ação da folha sem volta, e o mesmo toque que
        // remove oferece o "Desfazer" (o padrão do deslize de capítulo). Com
        // nota o alternarFavorito se recusa a remover (a nota manda, ver
        // estado.dart), e nesse caso não há o que desfazer.
        if (eraFavorito &&
            !estado.ehFavorito(versao, livro, capituloNumero, numero)) {
          final mensageiro = ScaffoldMessenger.of(folha);
          mostrarAvisoNo(
            mensageiro,
            'Removido dos favoritos.',
            rotuloDeAcao: 'Desfazer',
            aoAgir: () =>
                estado.alternarFavorito(versao, livro, capituloNumero, numero),
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
          await estado.definirNota(versao, livro, capituloNumero, numero, nota);
        }
        if (folha.mounted) Navigator.pop(folha);
      },
    );
  }

  /// O mesmo texto para Copiar e Compartilhar. O link vale em qualquer
  /// plataforma, não só na web: é assim que quem recebe chega direto ao
  /// versículo, mesmo copiado ou compartilhado do celular numa live.
  String get _textoDoVersiculo =>
      '"$texto"\n$referencia:$numero (${versao.sigla})\n'
      '${linkDoVersiculo(livro, capituloNumero, numero)}';
}

Future<void> _abrirAcoesDoVersiculo(
  BuildContext context,
  Estado estado, {
  required Versao versao,
  required String livro,
  required int capituloNumero,
  required String referencia,
  required int numero,
  required String texto,
}) async {
  final marcacao = estado.marcacaoDe(versao, livro, capituloNumero, numero);
  final acoes = _AcoesDoVersiculo(
    estado: estado,
    versao: versao,
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
    // comuns.dart: isScrollControlled deixa a folha crescer, e o
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

/// Tela cheia para compartilhar a tela numa live: o teto de 1,5x de
/// [escalasDeLeitura] é pensado para ler no próprio aparelho, pequeno demais
/// numa transmissão. Por isso não usa `Estado.escalaDeLeitura`: o
/// `FittedBox` ocupa o espaço disponível sozinho, sem precisar de um
/// controle de tamanho novo.
///
/// Fecha só pelo botão de fechar, não por qualquer toque: durante uma
/// transmissão, um toque acidental encerraria um momento deliberado de
/// leitura.
class TelaApresentacao extends StatelessWidget {
  const TelaApresentacao({
    super.key,
    required this.texto,
    required this.referencia,
  });

  final String texto;
  final String referencia;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cor.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.sp32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        texto,
                        textAlign: TextAlign.center,
                        style: tema.displayLarge?.copyWith(
                          color: cor.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sp24),
                  Text(
                    referencia,
                    style: tema.headlineSmall?.copyWith(color: cor.secondary),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close),
                color: cor.primary,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seletor em duas etapas: escolhe o livro, depois o capítulo numa grade.
class _SeletorDeLivro extends StatefulWidget {
  const _SeletorDeLivro({required this.livroAtual});

  final String livroAtual;

  @override
  State<_SeletorDeLivro> createState() => _SeletorDeLivroState();
}

class _SeletorDeLivroState extends State<_SeletorDeLivro> {
  Livro? _escolhido;
  final _controle = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.sizeOf(context).height * 0.75;
    final escolhido = _escolhido;

    return SizedBox(
      height: altura,
      child: Column(
        children: [
          // Cabeçalho com altura própria: num Column, um Flexible (flex 1)
          // dividiria o espaço da folha ao meio com a lista embaixo, e o
          // vão não usado pelo cabeçalho sobraria em branco no fim da folha.
          // Fora do flex, ele ocupa só o que precisa e a lista fica com todo
          // o resto.
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: Spacing.sp12),
                Text(
                  escolhido == null ? 'Escolha o livro' : escolhido.nome,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Spacing.sp8),
                const Filete(),
                // Busca só na etapa de livros: na grade de capítulos o texto
                // já é o que se procura.
                if (escolhido == null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.sp16,
                      Spacing.sp10,
                      Spacing.sp16,
                      Spacing.sp4,
                    ),
                    child: TextField(
                      controller: _controle,
                      onChanged: (v) => setState(() => _filtro = v.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Buscar livro',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
                if (escolhido != null)
                  Padding(
                    padding: const EdgeInsets.all(Spacing.sp8),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _escolhido = null),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Todos os livros'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: escolhido == null
                ? _ListaDeLivros(
                    atual: widget.livroAtual,
                    filtro: _filtro,
                    ao: (l) => l.capitulos == 1
                        ? Navigator.pop(context, (l.slug, 1))
                        : setState(() => _escolhido = l),
                  )
                : _GradeDeCapitulos(
                    livro: escolhido,
                    ao: (c) => Navigator.pop(context, (escolhido.slug, c)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ListaDeLivros extends StatelessWidget {
  const _ListaDeLivros({
    required this.atual,
    required this.ao,
    this.filtro = '',
  });

  final String atual;
  final ValueChanged<Livro> ao;
  final String filtro;

  @override
  Widget build(BuildContext context) {
    if (filtro.isNotEmpty) {
      // A busca é a porta de entrada para quem não quer escanear 66 chips:
      // Miqueias e Hebreus deixam de pedir duas telas de varredura. Nome e
      // abreviação, sem acento e sem caixa, como a busca de versículos.
      final alvo = Conteudo.normalizar(filtro);
      final achados = canon
          .where(
            (l) =>
                Conteudo.normalizar(l.nome).contains(alvo) ||
                Conteudo.normalizar(l.abrev).contains(alvo),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sp16),
        children: [
          if (achados.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sp4,
                Spacing.sp24,
                Spacing.sp4,
                Spacing.sp8,
              ),
              child: Text(
                'Nenhum livro com "$filtro".',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            _grade(achados),
          const SizedBox(height: Spacing.sp16),
        ],
      );
    }

    final antigo = canon
        .where((l) => l.testamento == Testamento.antigo)
        .toList();
    final novo = canon.where((l) => l.testamento == Testamento.novo).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sp16),
      children: [
        _tituloDeSecao(context, 'Antigo Testamento'),
        _grade(antigo),
        _tituloDeSecao(context, 'Novo Testamento'),
        _grade(novo),
        const SizedBox(height: Spacing.sp16),
      ],
    );
  }

  Widget _tituloDeSecao(BuildContext context, String texto) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Spacing.sp4,
      Spacing.sp12,
      Spacing.sp4,
      Spacing.sp8,
    ),
    child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _grade(List<Livro> livros) => Wrap(
    spacing: Spacing.sp8,
    runSpacing: Spacing.sp8,
    children: [
      for (final l in livros)
        ChoiceChip(
          label: Text(l.nome),
          selected: l.slug == atual,
          onSelected: (_) => ao(l),
        ),
    ],
  );
}

/// Folha com só a grade de capítulos do livro aberto: o atalho de um passo
/// para quem já está lendo. Ver `_abrirGradeDeCapitulos`.
class _FolhaDeCapitulos extends StatelessWidget {
  const _FolhaDeCapitulos({required this.livro});

  final Livro livro;

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.sizeOf(context).height * 0.55;
    return SizedBox(
      height: altura,
      child: Column(
        children: [
          const SizedBox(height: Spacing.sp12),
          Text(
            'Capítulo de ${livro.nome}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.sp8),
          const Filete(),
          const SizedBox(height: Spacing.sp8),
          Expanded(
            child: _GradeDeCapitulos(
              livro: livro,
              ao: (c) => Navigator.pop(context, c),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeDeCapitulos extends StatelessWidget {
  const _GradeDeCapitulos({required this.livro, required this.ao});

  final Livro livro;
  final ValueChanged<int> ao;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(Spacing.sp16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        childAspectRatio: 1,
        crossAxisSpacing: Spacing.sp8,
        mainAxisSpacing: Spacing.sp8,
      ),
      itemCount: livro.capitulos,
      itemBuilder: (context, i) => OutlinedButton(
        onPressed: () => ao(i + 1),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: cor.outline.withValues(alpha: 0.6)),
        ),
        child: Text('${i + 1}', style: Theme.of(context).textTheme.bodyMedium),
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
