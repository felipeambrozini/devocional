import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../controladores/leitor_de_livro_controlador.dart';
import '../dados/biblioteca.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
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
  bool get _temProximo => widget.indice < widget.capitulos.length - 1;

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

    return Scaffold(
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
                DevocionalAreaDeSelecaoComCompartilhar(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (n, paragrafo) in _capitulo.paragrafos.indexed)
                        _Paragrafo(
                          texto: paragrafo,
                          destaque: destaques[n],
                          aoTocar: () => _abrirAcoes(n),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: DevocionalEspacamento.sp16),
                Center(
                  child: DevocionalBotaoTerciario.icon(
                    onPressed: () => leitura.alternarLido(_slug, widget.indice),
                    icon: FaIcon(
                      lido
                          ? FontAwesomeIcons.circleCheck
                          : FontAwesomeIcons.circle,
                      size: 14,
                    ),
                    label: Text(lido ? 'Capítulo lido' : 'Marcar como lido'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DevocionalBarraDeCapitulo(
        podeVoltar: widget.indice > 0,
        podeAvancar: _temProximo,
        aoVoltar: () => _irPara(widget.indice - 1),
        aoAvancar: () => _irPara(widget.indice + 1),
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
