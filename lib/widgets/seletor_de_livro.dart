import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/audio_offline.dart';
import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../estilo/espacamento.dart';
import 'widgets.dart';

/// Seletor em duas etapas: escolhe o livro, depois o capítulo numa grade.
///
/// Abre já na grade do livro aberto, com "Todos os livros" para trocar de
/// livro: é o único seletor da Bíblia. Antes havia dois (o título da barra
/// trocava o livro, o título no corpo abria a grade de capítulos), e quem
/// chegava não sabia qual tocar.
class TabernaculoSeletorDeLivro extends StatefulWidget {
  const TabernaculoSeletorDeLivro({
    super.key,
    required this.livroAtual,
    this.capituloAtual,
  });

  final String livroAtual;

  /// O capítulo aberto, marcado na grade do livro atual como o chip
  /// escolhido.
  final int? capituloAtual;

  @override
  State<TabernaculoSeletorDeLivro> createState() => _SeletorDeLivroState();
}

class _SeletorDeLivroState extends State<TabernaculoSeletorDeLivro> {
  late Livro? _escolhido = livroPorSlug(widget.livroAtual);
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
                const SizedBox(height: TabernaculoEspacamento.sp12),
                // liveRegion: trocar da grade para a lista (e de volta) muda
                // a folha inteira, e o leitor de tela precisa ouvir isso.
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    escolhido == null ? 'Escolha o livro' : escolhido.nome,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: TabernaculoEspacamento.sp8),
                const TabernaculoFilete(),
                // Busca só na etapa de livros: na grade de capítulos o texto
                // já é o que se procura.
                if (escolhido == null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TabernaculoEspacamento.sp16,
                      TabernaculoEspacamento.sp10,
                      TabernaculoEspacamento.sp16,
                      TabernaculoEspacamento.sp4,
                    ),
                    child: TabernaculoBusca(
                      controller: _controle,
                      hintText: 'Buscar livro',
                      // Na web, quem tocou "Todos os livros" pelo teclado perde
                      // o botão, que sai da tela; o foco vai para a busca em
                      // vez de cair no começo da folha. No celular abriria o
                      // teclado por cima da lista.
                      autofocus: kIsWeb,
                      onChanged: (v) => setState(() => _filtro = v.trim()),
                    ),
                  ),
                ],
                if (escolhido != null)
                  Padding(
                    padding: const EdgeInsets.all(TabernaculoEspacamento.sp8),
                    child: TabernaculoBotaoTerciario.icon(
                      onPressed: () => setState(() => _escolhido = null),
                      icon: const FaIcon(FontAwesomeIcons.arrowLeft),
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
                    atual: escolhido.slug == widget.livroAtual
                        ? widget.capituloAtual
                        : null,
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
        padding: const EdgeInsets.symmetric(
          horizontal: TabernaculoEspacamento.sp16,
        ),
        children: [
          if (achados.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TabernaculoEspacamento.sp4,
                TabernaculoEspacamento.sp24,
                TabernaculoEspacamento.sp4,
                TabernaculoEspacamento.sp8,
              ),
              child: Text(
                'Nenhum livro com "$filtro"',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            _grade(achados),
          const SizedBox(height: TabernaculoEspacamento.sp16),
        ],
      );
    }

    final antigo = canon
        .where((l) => l.testamento == Testamento.antigo)
        .toList();
    final novo = canon.where((l) => l.testamento == Testamento.novo).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: TabernaculoEspacamento.sp16,
      ),
      children: [
        _tituloDeSecao(context, 'Antigo Testamento'),
        _grade(antigo),
        _tituloDeSecao(context, 'Novo Testamento'),
        _grade(novo),
        const SizedBox(height: TabernaculoEspacamento.sp16),
      ],
    );
  }

  Widget _tituloDeSecao(BuildContext context, String texto) => Padding(
    padding: const EdgeInsets.fromLTRB(
      TabernaculoEspacamento.sp4,
      TabernaculoEspacamento.sp12,
      TabernaculoEspacamento.sp4,
      TabernaculoEspacamento.sp8,
    ),
    child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _grade(List<Livro> livros) => Wrap(
    spacing: TabernaculoEspacamento.sp8,
    runSpacing: TabernaculoEspacamento.sp8,
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

class _GradeDeCapitulos extends StatelessWidget {
  const _GradeDeCapitulos({required this.livro, required this.ao, this.atual});

  final Livro livro;
  final ValueChanged<int> ao;
  final int? atual;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // O seletor é o que a Bíblia tem de página do livro: baixar o áudio
        // dele mora aqui, fora da leitura, e só aparece quando o áudio do
        // livro já está no Storage. Fica na área que rola, e não no cabeçalho
        // fixo: com o celular deitado ou letra a 2×, o cabeçalho com o botão
        // tomava a folha e a grade de capítulos sumia.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TabernaculoEspacamento.sp16,
              0,
              TabernaculoEspacamento.sp16,
              0,
            ),
            child: TabernaculoBaixarLivro(
              key: ValueKey(livro.slug),
              livro: LivroParaBaixar.daBiblia(livro),
              alinhamento: Alignment.center,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(TabernaculoEspacamento.sp16),
          sliver: _grade(context),
        ),
      ],
    );
  }

  Widget _grade(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        childAspectRatio: 1,
        crossAxisSpacing: TabernaculoEspacamento.sp8,
        mainAxisSpacing: TabernaculoEspacamento.sp8,
      ),
      itemCount: livro.capitulos,
      itemBuilder: (context, i) {
        final cor = Theme.of(context).colorScheme;
        final numero = i + 1;
        // O capítulo aberto segue o chip escolhido: metal cheio com a letra
        // do contrário por cima.
        final eAtual = numero == atual;
        // O rótulo "Capítulo N" mora dentro do botão, que funde a semântica
        // do filho: assim o nó do botão leva o rótulo, o selecionado e as
        // marcas de foco e toque dele. O número desenhado sai da semântica.
        return OutlinedButton(
          onPressed: () => ao(numero),
          // Fundo tonal: o fio a 50% sozinho mal separava as células na folha.
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: eAtual ? cor.primary : cor.surfaceContainerHighest,
            foregroundColor: eAtual ? cor.onPrimary : null,
          ),
          child: Semantics(
            label: 'Capítulo $numero',
            selected: eAtual,
            child: ExcludeSemantics(
              // Na escala de leitura máxima o "150" de Salmos não cabia na
              // célula.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$numero',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: eAtual ? cor.onPrimary : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
