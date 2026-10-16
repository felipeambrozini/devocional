import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../controladores/leitor_de_livro_controlador.dart';
import '../dados/biblioteca.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/dialogos.dart';
import '../widgets/widgets.dart';

/// Um capítulo de um livro da biblioteca. [capitulo] vem da URL, a partir de 1.
class TelaLeitorDeLivro extends StatelessWidget {
  const TelaLeitorDeLivro({
    super.key,
    required this.slug,
    required this.capitulo,
  });

  final String slug;
  final int capitulo;

  @override
  Widget build(BuildContext context) {
    final obra = obraPorSlug(slug);
    final estado = EscopoDoEstado.de(context);

    Widget aviso(String titulo, [Widget? corpo]) => Scaffold(
      appBar: DevocionalAppBar(
        title: Text(obra?.titulo ?? 'Biblioteca'),
        actions: [DevocionalBotaoDeAjustes(estado: estado)],
      ),
      body:
          corpo ??
          DevocionalAvisoVazio(icone: FontAwesomeIcons.book, titulo: titulo),
    );

    if (obra == null) return aviso('Livro não encontrado');

    return DevocionalCarregaUmaVez<List<CapituloDoLivro>?>(
      chave: slug,
      carregar: () => Biblioteca.instancia.capitulos(slug),
      construir: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return aviso('', const Center(child: CircularProgressIndicator()));
        }
        final capitulos = snap.data;
        if (capitulos == null || capitulos.isEmpty) {
          return aviso('', const DevocionalAvisoDeErro());
        }
        final indice = capitulo - 1;
        if (indice < 0 || indice >= capitulos.length) {
          return aviso('Capítulo não encontrado');
        }
        // A chave leva o capítulo junto: o go_router pode reaproveitar a
        // página ao trocar só o parâmetro, e a rolagem do capítulo anterior
        // não pode sobrar no próximo.
        return _CapituloAberto(
          key: ValueKey('$slug/$indice'),
          estado: estado,
          obra: obra,
          capitulos: capitulos,
          indice: indice,
        );
      },
    );
  }
}

class _CapituloAberto extends StatefulWidget {
  const _CapituloAberto({
    super.key,
    required this.estado,
    required this.obra,
    required this.capitulos,
    required this.indice,
  });

  /// Vem do pai porque o `initState` não pode ler o escopo herdado.
  final Estado estado;
  final ObraDaBiblioteca obra;
  final List<CapituloDoLivro> capitulos;
  final int indice;

  @override
  State<_CapituloAberto> createState() => _CapituloAbertoState();
}

class _CapituloAbertoState extends State<_CapituloAberto> {
  late final LeitorDeLivroControlador _controlador;

  CapituloDoLivro get _capitulo => widget.capitulos[widget.indice];
  String get _slug => widget.obra.slug;
  bool get _ehUltimo => widget.indice == widget.capitulos.length - 1;

  @override
  void initState() {
    super.initState();
    _controlador = LeitorDeLivroControlador(
      estado: widget.estado,
      slug: _slug,
      capitulo: widget.indice,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controlador.iniciar();
    });
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  /// Troca de capítulo no lugar da tela atual, para o voltar continuar
  /// levando ao sumário e não ao capítulo anterior.
  void _irPara(int indice) =>
      context.pushReplacement('/biblioteca/$_slug/${indice + 1}');

  /// Passa [passo] capítulos (1 ou -1). Antes do primeiro não faz nada; depois
  /// do último, termina a leitura (ver [_terminarLeitura]).
  void _passar(int passo) {
    final destino = widget.indice + passo;
    if (destino < 0) return;
    if (destino >= widget.capitulos.length) {
      _terminarLeitura();
      return;
    }
    _irPara(destino);
  }

  /// Do último capítulo para a frente: termina o livro, zera a leitura e volta
  /// à estante. Abrir o capítulo 1 aqui marcaria o livro como "em leitura" de
  /// novo (é o `iniciar` do capítulo que grava a posição), desfazendo o
  /// recomeço. Pede confirmação porque zera o progresso, e um deslize
  /// acidental não pode custar os capítulos marcados.
  Future<void> _terminarLeitura() async {
    final confirmou = await confirmar(
      context,
      titulo: 'Terminar a leitura?',
      conteudo:
          '${widget.obra.titulo} será dado como lido e a leitura recomeça do '
          'primeiro capítulo. Seus destaques e notas continuam guardados.',
      rotuloDaAcao: 'Terminar',
    );
    if (!confirmou || !mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    final roteador = GoRouter.of(context);
    _controlador.encerrar();
    await widget.estado.leituraDeLivros.concluir(_slug);
    roteador.go('/biblioteca');
    mostrarAvisoNo(
      mensageiro,
      'Você terminou ${widget.obra.titulo}. Ao abrir o livro de novo, a '
      'leitura recomeça do primeiro capítulo.',
    );
  }

  /// Arrastar na horizontal passa de capítulo, com as regras da Bíblia: o
  /// corpo é um detector horizontal em volta de uma rolagem vertical, então o
  /// horizontal precisa vencer o vertical por 2,5x, senão um flick durante a
  /// rolagem trocaria de capítulo em silêncio. Oferece "Desfazer": o deslize é
  /// o único jeito de trocar no toque, e um acidente não pode custar o lugar.
  void _aoArrastar(DragEndDetails detalhe) {
    final horizontal = detalhe.primaryVelocity ?? 0;
    final vertical = detalhe.velocity.pixelsPerSecond.dy;
    if (horizontal.abs() < 250) return;
    if (vertical.abs() * 2.5 > horizontal.abs()) return;
    final destino = widget.indice + (horizontal < 0 ? 1 : -1);
    if (destino < 0) return;
    if (destino >= widget.capitulos.length) {
      _terminarLeitura();
      return;
    }

    final estado = widget.estado;
    if (!estado.swipeTooltipDispensado) estado.dispensarSwipeTooltip();
    // A tela atual sai de cena na troca: o aviso e o desfazer usam o que foi
    // pego antes dela.
    final mensageiro = ScaffoldMessenger.of(context);
    final roteador = GoRouter.of(context);
    final slug = _slug;
    final anterior = widget.indice;
    _irPara(destino);
    mostrarAvisoNo(
      mensageiro,
      widget.capitulos[destino].titulo,
      rotuloDeAcao: 'Desfazer',
      aoAgir: () =>
          roteador.pushReplacement('/biblioteca/$slug/${anterior + 1}'),
    );
  }

  void _voltarAoSumario() =>
      context.canPop() ? context.pop() : context.go('/biblioteca/$_slug');

  Future<void> _abrirAcoes(int paragrafo) async {
    final leitura = EscopoDoEstado.de(context).leituraDeLivros;
    final destaque = leitura.destaquesDe(_slug, widget.indice)[paragrafo];
    final temNota = destaque != null && destaque.nota.isNotEmpty;
    final cor = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      builder: (folha) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!temNota)
              ListTile(
                leading: FaIcon(
                  FontAwesomeIcons.highlighter,
                  color: cor.primary,
                ),
                title: Text(destaque == null ? 'Destacar' : 'Tirar destaque'),
                onTap: () async {
                  await leitura.alternarDestaque(
                    _slug,
                    widget.indice,
                    paragrafo,
                  );
                  if (folha.mounted) Navigator.pop(folha);
                },
              ),
            ListTile(
              leading: FaIcon(FontAwesomeIcons.penToSquare, color: cor.primary),
              title: Text(temNota ? 'Editar anotação' : 'Anotar'),
              onTap: () async {
                final nota = await editarNota(
                  folha,
                  referencia: '${_capitulo.titulo}, parágrafo ${paragrafo + 1}',
                  notaAtual: destaque?.nota ?? '',
                );
                if (nota != null) {
                  await leitura.definirNota(
                    _slug,
                    widget.indice,
                    paragrafo,
                    nota,
                  );
                }
                if (folha.mounted) Navigator.pop(folha);
              },
            ),
            ListTile(
              leading: FaIcon(FontAwesomeIcons.copy, color: cor.primary),
              title: const Text('Copiar'),
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(text: _capitulo.paragrafos[paragrafo]),
                );
                if (folha.mounted) Navigator.pop(folha);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    final leitura = estado.leituraDeLivros;
    final tema = Theme.of(context).textTheme;
    final destaques = leitura.destaquesDe(_slug, widget.indice);
    final lido = leitura.foiLido(_slug, widget.indice);
    // Só no toque o texto vira selecionável: na web a seleção por arrasto
    // disputaria a arena com o gesto de capítulo (e "Copiar" fica na folha do
    // parágrafo). A área de seleção envolve o detector de arrasto, e não o
    // contrário: o reconhecedor mais fundo da árvore ganha a disputa, como na
    // Bíblia.
    Widget comSelecao(Widget filho) =>
        kIsWeb ? filho : DevocionalAreaDeSelecaoComCompartilhar(child: filho);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _passar(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _passar(-1),
      },
      child: Scaffold(
        appBar: DevocionalAppBar(
          title: Text(widget.obra.titulo, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Capítulos',
              icon: const FaIcon(FontAwesomeIcons.listUl),
              onPressed: _voltarAoSumario,
            ),
            DevocionalBotaoDeAjustes(estado: estado),
          ],
        ),
        body: DevocionalLarguraDeLeitura(
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                comSelecao(
                  GestureDetector(
                    onHorizontalDragEnd: _aoArrastar,
                    child: NotificationListener<ScrollEndNotification>(
                      onNotification: (_) {
                        _controlador.guardarPosicao();
                        return false;
                      },
                      child: SingleChildScrollView(
                        controller: _controlador.rolagem,
                        padding: const EdgeInsets.fromLTRB(
                          DevocionalEspacamento.sp16,
                          DevocionalEspacamento.sp8,
                          DevocionalEspacamento.sp16,
                          DevocionalEspacamento.sp32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Capítulo ${widget.indice + 1} de ${widget.capitulos.length}',
                              style: tema.labelMedium,
                            ),
                            const SizedBox(height: DevocionalEspacamento.sp4),
                            Text(_capitulo.titulo, style: tema.headlineMedium),
                            const SizedBox(height: DevocionalEspacamento.sp14),
                            const DevocionalFilete(),
                            const SizedBox(height: DevocionalEspacamento.sp16),
                            KeyedSubtree(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final (n, paragrafo)
                                      in _capitulo.paragrafos.indexed)
                                    _Paragrafo(
                                      texto: paragrafo,
                                      destaque: destaques[n],
                                      aoTocar: () => _abrirAcoes(n),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: DevocionalEspacamento.sp16),
                            if (_ehUltimo) ...[
                              Center(
                                child: DevocionalBotaoPrimario.icon(
                                  onPressed: _terminarLeitura,
                                  icon: const FaIcon(
                                    FontAwesomeIcons.flagCheckered,
                                    size: 16,
                                  ),
                                  label: const Text('Terminar a leitura'),
                                ),
                              ),
                              const SizedBox(height: DevocionalEspacamento.sp8),
                            ],
                            Center(
                              child: DevocionalBotaoTerciario.icon(
                                onPressed: () =>
                                    leitura.alternarLido(_slug, widget.indice),
                                icon: FaIcon(
                                  lido
                                      ? FontAwesomeIcons.circleCheck
                                      : FontAwesomeIcons.circle,
                                  size: 14,
                                ),
                                label: Text(
                                  lido ? 'Capítulo lido' : 'Marcar como lido',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // A alça é um indício de que dá para deslizar, não um controle.
                if (!kIsWeb)
                  DevocionalAlcaDeDeslize(
                    primeiraVez: !estado.swipeTooltipDispensado,
                  ),
              ],
            ),
          ),
        ),
        // Como na Bíblia: no celular o deslize já troca de capítulo, e a barra
        // só existe na web, se a opção das setas estiver ligada nos ajustes.
        bottomNavigationBar: kIsWeb && estado.setasDoRodape
            ? DevocionalBarraDeCapitulo(
                podeVoltar: widget.indice > 0,
                podeAvancar: true,
                aoVoltar: () => _passar(-1),
                aoAvancar: () => _passar(1),
              )
            : null,
      ),
    );
  }
}

/// Um parágrafo do livro. Grifado, ganha o fundo de citação e o fio do metal à
/// esquerda; com nota, a nota aparece embaixo. A faixa à esquerda existe sempre
/// (transparente) para o texto não pular de lugar quando o grifo liga.
class _Paragrafo extends StatelessWidget {
  const _Paragrafo({
    required this.texto,
    required this.destaque,
    required this.aoTocar,
  });

  final String texto;
  final DestaqueDeLivro? destaque;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final grifado = destaque != null;
    final nota = destaque?.nota ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: DevocionalEspacamento.sp12),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: aoTocar,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            DevocionalEspacamento.sp10,
            DevocionalEspacamento.sp4,
            DevocionalEspacamento.sp4,
            DevocionalEspacamento.sp4,
          ),
          decoration: BoxDecoration(
            color: grifado ? cor.surfaceContainerHighest : null,
            border: Border(
              left: BorderSide(
                color: grifado
                    ? cor.secondary.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texto, style: tema.bodyLarge?.copyWith(height: 1.7)),
              if (nota.isNotEmpty) ...[
                const SizedBox(height: DevocionalEspacamento.sp8),
                Text(
                  nota,
                  style: tema.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cor.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
