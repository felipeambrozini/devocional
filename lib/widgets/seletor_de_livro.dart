import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../estilo/spacing.dart';
import 'widgets.dart';

/// Seletor em duas etapas: escolhe o livro, depois o capítulo numa grade.
class SeletorDeLivro extends StatefulWidget {
  const SeletorDeLivro({super.key, required this.livroAtual});

  final String livroAtual;

  @override
  State<SeletorDeLivro> createState() => _SeletorDeLivroState();
}

class _SeletorDeLivroState extends State<SeletorDeLivro> {
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
/// para quem já está lendo. Ver `_abrirGradeDeCapitulos` em `biblia.dart`.
class FolhaDeCapitulos extends StatelessWidget {
  const FolhaDeCapitulos({super.key, required this.livro});

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
