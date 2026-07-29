import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'busca.dart';
import 'comuns.dart';
import 'introducao.dart';

/// Leitor da Bíblia. Abre em Gênesis 1 ou onde a leitura parou.
class TelaBiblia extends StatefulWidget {
  const TelaBiblia({super.key, this.livroInicial, this.capituloInicial, this.destacar});

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
  bool _restaurou = false;

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
    // Só retoma a última leitura quando a tela abriu sem destino explícito.
    if (_restaurou || widget.livroInicial != null) return;
    _restaurou = true;
    final ultima = EscopoDoEstado.de(context).ultimaLeitura;
    if (ultima != null) {
      _livro = ultima.$1;
      _capitulo = ultima.$2;
    }
  }

  Livro get _livroAtual => livroPorSlug(_livro) ?? canon.first;

  void _irPara(String livro, int capitulo) {
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

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    return Scaffold(
      appBar: AppBar(
        title: TextButton(
          onPressed: _abrirSeletor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_livroAtual.nome} $_capitulo',
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
              const Icon(Icons.expand_more, color: Cores.dourado, size: 20),
            ],
          ),
        ),
        actions: [
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaBusca()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _AlternadorDeVersao(
            atual: estado.versao,
            ao: (v) => estado.definirVersao(v),
          ),
          Expanded(
            child: CarregaUmaVez<Capitulo>(
              // A chave inclui a versão para que alternar BKJ e NVT recarregue o
              // mesmo capítulo, mantendo livro e número.
              chave: '${estado.versao.pasta}/$_livro/$_capitulo',
              carregar: () =>
                  Conteudo.instancia.capitulo(estado.versao, _livro, _capitulo),
              construir: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final capitulo = snap.data!;
                if (capitulo.versiculos.isEmpty) {
                  return const AvisoVazio(
                    icone: Icons.menu_book_outlined,
                    titulo: 'Capítulo não encontrado',
                  );
                }
                return _Leitor(
                  capitulo: capitulo,
                  rolagem: _rolagem,
                  destacar: widget.destacar,
                );
              },
            ),
          ),
          _BarraDeCapitulo(
            podeVoltar: !(_livro == canon.first.slug && _capitulo == 1),
            podeAvancar: !(_livro == canon.last.slug &&
                _capitulo == canon.last.capitulos),
            aoVoltar: () => _passarCapitulo(-1),
            aoAvancar: () => _passarCapitulo(1),
          ),
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

class _AlternadorDeVersao extends StatelessWidget {
  const _AlternadorDeVersao({required this.atual, required this.ao});

  final Versao atual;
  final ValueChanged<Versao> ao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<Versao>(
        segments: [
          for (final v in Versao.values)
            ButtonSegment(value: v, label: Text(v.sigla), tooltip: v.nome),
        ],
        selected: {atual},
        onSelectionChanged: (s) => ao(s.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _Leitor extends StatelessWidget {
  const _Leitor({required this.capitulo, required this.rolagem, this.destacar});

  final Capitulo capitulo;
  final ScrollController rolagem;
  final (int, int)? destacar;

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    final tema = Theme.of(context).textTheme;

    return ListView.builder(
      controller: rolagem,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: capitulo.versiculos.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A introdução do livro abre o livro, antes do capítulo 1. Nos demais
              // capítulos ela não reaparece: continua acessível pela AppBar.
              if (capitulo.numero == 1) _AberturaDoLivro(slug: capitulo.livro),
              Text(capitulo.referencia, style: tema.displayMedium),
              const SizedBox(height: 8),
              const Filete(),
              if (capitulo.titulo.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  capitulo.titulo,
                  style: tema.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Cores.begeSuave,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          );
        }

        final (numero, texto) = capitulo.versiculos[i - 1];
        final marcacao = estado.marcacaoDe(
          estado.versao,
          capitulo.livro,
          capitulo.numero,
          numero,
        );
        final noRecorte = destacar == null ||
            (numero >= destacar!.$1 && numero <= destacar!.$2);

        return InkWell(
          onTap: () => _abrirAcoes(context, estado, numero, texto),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: marcacao != null
                  ? Cores.douradoEscuro.withValues(alpha: 0.18)
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
                          color: Cores.dourado,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: texto,
                        // Fora da faixa pedida pelo cronograma o texto continua
                        // legível, apenas recuado, para o contexto não se perder.
                        style: noRecorte
                            ? tema.bodyLarge?.copyWith(height: 1.6)
                            : tema.bodyLarge?.copyWith(
                                height: 1.6,
                                color: Cores.begeSuave.withValues(alpha: 0.55),
                              ),
                      ),
                    ],
                  ),
                ),
                if (marcacao != null && marcacao.nota.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.edit_note, size: 15, color: Cores.dourado),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          marcacao.nota,
                          style: tema.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirAcoes(
    BuildContext context,
    Estado estado,
    int numero,
    String texto,
  ) async {
    final marcacao = estado.marcacaoDe(
      estado.versao,
      capitulo.livro,
      capitulo.numero,
      numero,
    );
    await showModalBottomSheet<void>(
      context: context,
      builder: (folha) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${capitulo.referencia}:$numero',
                    style: Theme.of(folha).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(texto, style: Theme.of(folha).textTheme.bodyMedium),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                marcacao != null ? Icons.bookmark : Icons.bookmark_outline,
                color: Cores.dourado,
              ),
              title: Text(marcacao != null ? 'Remover dos favoritos' : 'Favoritar'),
              onTap: () {
                estado.alternarFavorito(
                  estado.versao,
                  capitulo.livro,
                  capitulo.numero,
                  numero,
                );
                Navigator.pop(folha);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: Cores.dourado),
              title: Text(
                marcacao?.nota.isNotEmpty == true ? 'Editar anotação' : 'Anotar',
              ),
              onTap: () async {
                final nota = await editarNota(
                  folha,
                  referencia: '${capitulo.referencia}:$numero',
                  notaAtual: marcacao?.nota ?? '',
                );
                if (nota != null) {
                  await estado.definirNota(
                    estado.versao,
                    capitulo.livro,
                    capitulo.numero,
                    numero,
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
}

/// Abertura do livro: a introdução de Spurgeon, recolhida por padrão.
///
/// Recolhida porque o texto é longo e quem já leu a introdução quer chegar ao
/// capítulo 1 sem rolar páginas. Expandida, lê inteira ali mesmo.
class _AberturaDoLivro extends StatefulWidget {
  const _AberturaDoLivro({required this.slug});

  final String slug;

  @override
  State<_AberturaDoLivro> createState() => _AberturaDoLivroState();
}

class _AberturaDoLivroState extends State<_AberturaDoLivro> {
  bool _aberta = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return CarregaUmaVez<Introducao?>(
      chave: widget.slug,
      carregar: () => Conteudo.instancia.introducao(widget.slug),
      construir: (context, snap) {
        final intro = snap.data;
        // Sem introdução escrita, nada é mostrado: o livro começa no capítulo 1.
        if (intro == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _aberta = !_aberta),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.asset(
                            'assets/images/capa_biblia_spurgeon.png',
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Introdução', style: tema.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                'Bíblia de Estudo Spurgeon',
                                style: tema.labelMedium,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _aberta ? Icons.expand_less : Icons.expand_more,
                          color: Cores.dourado,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_aberta)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Filete(),
                        const SizedBox(height: 16),
                        for (final (titulo, corpo) in intro.secoes) ...[
                          Text(titulo, style: tema.headlineSmall),
                          const SizedBox(height: 8),
                          for (final paragrafo in corpo.split('\n\n')) ...[
                            Text(
                              paragrafo,
                              style: tema.bodyMedium?.copyWith(height: 1.7),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 12),
                        ],
                        if (intro.frase.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Cores.superficieAlta,
                              borderRadius: BorderRadius.circular(10),
                              border: const Border(
                                left: BorderSide(color: Cores.dourado, width: 3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '"${intro.frase}"',
                                  style: tema.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Cores.douradoClaro,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(intro.atribuicao, style: tema.labelMedium),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

/// Seletor em duas etapas: escolhe o livro, depois o capítulo numa grade.
class _SeletorDeLivro extends StatefulWidget {
  const _SeletorDeLivro({required this.livroAtual});

  final String livroAtual;

  @override
  State<_SeletorDeLivro> createState() => _SeletorDeLivroState();
}

class _SeletorDeLivroState extends State<_SeletorDeLivro> {
  Livro? _escolhido;

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.sizeOf(context).height * 0.75;
    final escolhido = _escolhido;

    return SizedBox(
      height: altura,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            escolhido == null ? 'Escolha o livro' : escolhido.nome,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Filete(),
          const SizedBox(height: 8),
          Expanded(
            child: escolhido == null
                ? _ListaDeLivros(
                    atual: widget.livroAtual,
                    ao: (l) => l.capitulos == 1
                        ? Navigator.pop(context, (l.slug, 1))
                        : setState(() => _escolhido = l),
                  )
                : _GradeDeCapitulos(
                    livro: escolhido,
                    ao: (c) => Navigator.pop(context, (escolhido.slug, c)),
                  ),
          ),
          if (escolhido != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton.icon(
                onPressed: () => setState(() => _escolhido = null),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Todos os livros'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListaDeLivros extends StatelessWidget {
  const _ListaDeLivros({required this.atual, required this.ao});

  final String atual;
  final ValueChanged<Livro> ao;

  @override
  Widget build(BuildContext context) {
    final antigo = canon.where((l) => l.testamento == Testamento.antigo).toList();
    final novo = canon.where((l) => l.testamento == Testamento.novo).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _tituloDeSecao(context, 'Antigo Testamento'),
        _grade(antigo),
        _tituloDeSecao(context, 'Novo Testamento'),
        _grade(novo),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _tituloDeSecao(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _grade(List<Livro> livros) => Wrap(
        spacing: 8,
        runSpacing: 8,
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
  const _GradeDeCapitulos({required this.livro, required this.ao});

  final Livro livro;
  final ValueChanged<int> ao;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: livro.capitulos,
      itemBuilder: (context, i) => OutlinedButton(
        onPressed: () => ao(i + 1),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: Cores.douradoEscuro.withValues(alpha: 0.6)),
        ),
        child: Text('${i + 1}', style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
