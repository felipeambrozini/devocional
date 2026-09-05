import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/planos.dart';
import '../estilo/spacing.dart';
import '../funcoes/aviso.dart';
import '../widgets/widgets.dart';

/// Formulário de um novo plano de leitura: nome opcional, um ou mais livros
/// e em quantos dias. Monta o plano na hora ([montarPlanoDeLeitura]) e mostra
/// uma prévia dos primeiros dias, para quem cria ver o resultado antes de
/// confirmar.
class TelaNovoPlano extends StatefulWidget {
  const TelaNovoPlano({super.key, required this.estado});

  final Estado estado;

  @override
  State<TelaNovoPlano> createState() => _TelaNovoPlanoState();
}

class _TelaNovoPlanoState extends State<TelaNovoPlano> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _dias = TextEditingController(text: '30');

  /// Slugs escolhidos, na ordem canônica (a ordem do seletor).
  final List<String> _livros = [];
  bool _incluirDevocionais = false;
  bool _devocionalAntes = true;

  @override
  void initState() {
    super.initState();
    Conteudo.instancia.aquecerIndiceDeDevocionais().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _titulo.dispose();
    _dias.dispose();
    super.dispose();
  }

  int get _totalDeCapitulos {
    var total = 0;
    for (final slug in _livros) {
      total += livroPorSlug(slug)?.capitulos ?? 0;
    }
    return total;
  }

  List<DiaDePlanoDoUsuario> get _previa => montarPlanoDeLeitura(
    livros: _livros,
    dias: int.tryParse(_dias.text) ?? 0,
    incluirDevocionais: _incluirDevocionais,
    devocionalAntes: _devocionalAntes,
  );

  Future<void> _escolherLivros() async {
    final escolhidos = await mostrarSeletorDeLivros(context, jaEscolhidos: _livros);
    if (escolhidos == null) return;
    setState(() {
      _livros
        ..clear()
        ..addAll(escolhidos);
    });
  }

  Future<void> _criar() async {
    if (_livros.isEmpty) {
      mostrarAviso(context, 'Escolha pelo menos um livro.');
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    final plano = await widget.estado.criarPlano(
      titulo: _titulo.text,
      livros: _livros,
      dias: int.parse(_dias.text),
      incluirDevocionais: _incluirDevocionais,
      devocionalAntes: _devocionalAntes,
    );
    if (!mounted) return;
    context.pop(plano);
  }

  String? _validarDias(String? valor) {
    final dias = int.tryParse(valor ?? '');
    if (dias == null || dias < 1) {
      return 'Informe em quantos dias o plano acontece.';
    }
    final total = _totalDeCapitulos;
    if (total > 0 && dias > total) {
      return 'Os livros têm $total capítulos; o máximo é $total dias.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final dias = int.tryParse(_dias.text) ?? 0;
    final previa = _previa;

    return Scaffold(
      appBar: AppBar(title: const Text('Novo plano de leitura')),
      body: LarguraDeLeitura(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sp16,
              Spacing.sp12,
              Spacing.sp16,
              Spacing.sp32,
            ),
            children: [
              TextFormField(
                controller: _titulo,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Nome do plano (opcional)',
                  hintText: _livros.isEmpty
                      ? 'Ex.: Ler os Evangelhos'
                      : tituloDePlano(_livros, dias),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.sp20),
              Text('Quais livros?', style: tema.titleMedium),
              const SizedBox(height: Spacing.sp8),
              OutlinedButton.icon(
                onPressed: _escolherLivros,
                icon: const Icon(Icons.library_books_outlined),
                label: Text(
                  _livros.isEmpty
                      ? 'Escolher livros'
                      : '${_livros.length} '
                            '${_livros.length == 1 ? 'livro' : 'livros'} '
                            'escolhidos',
                ),
              ),
              if (_livros.isNotEmpty) ...[
                const SizedBox(height: Spacing.sp10),
                Wrap(
                  spacing: Spacing.sp8,
                  runSpacing: Spacing.sp8,
                  children: [
                    for (final slug in _livros)
                      InputChip(
                        label: Text(nomeDoLivro(slug)),
                        onDeleted: () => setState(() => _livros.remove(slug)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Spacing.sp20),
              Text('Em quantos dias?', style: tema.titleMedium),
              const SizedBox(height: Spacing.sp8),
              TextFormField(
                controller: _dias,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: _validarDias,
                decoration: InputDecoration(
                  helperText: _totalDeCapitulos == 0
                      ? 'Escolha os livros para ver o tamanho do plano.'
                      : 'O plano terá $_totalDeCapitulos '
                            '${_totalDeCapitulos == 1 ? 'capítulo' : 'capítulos'}.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.sp20),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Incluir devocionais dos livros'),
                subtitle: const Text(
                  'Junto de cada capítulo, os devocionais de Manhã, Noite e '
                  'Promessas de Deus que citam aquele texto.',
                ),
                value: _incluirDevocionais,
                onChanged: (marcado) =>
                    setState(() => _incluirDevocionais = marcado ?? false),
              ),
              if (_incluirDevocionais) ...[
                const SizedBox(height: Spacing.sp8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Antes do capítulo')),
                    ButtonSegment(value: false, label: Text('Depois do capítulo')),
                  ],
                  selected: {_devocionalAntes},
                  onSelectionChanged: (novo) =>
                      setState(() => _devocionalAntes = novo.first),
                ),
              ],
              if (_previa.isNotEmpty) ...[
                const SizedBox(height: Spacing.sp20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.sp14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Prévia', style: tema.titleSmall),
                        const SizedBox(height: Spacing.sp8),
                        for (final dia in previa.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: Spacing.sp4),
                            child: Text(
                              'Dia ${dia.numero} · ${dia.rotulo}',
                              style: tema.bodySmall,
                            ),
                          ),
                        if (previa.length > 3)
                          Text(
                            '… e mais ${previa.length - 3} dias',
                            style: tema.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.sp24),
              FilledButton.icon(
                onPressed: _criar,
                icon: const Icon(Icons.check),
                label: const Text('Criar plano'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seletor de livros com busca: a lista do canon com uma caixa de marcar
/// para cada livro. Devolve os slugs escolhidos na ordem canônica, ou nulo
/// se cancelado.
///
/// Dialog e não bottom sheet: são 66 livros, e a busca + a lista rolável
/// precisam da janela inteira no celular.
Future<List<String>?> mostrarSeletorDeLivros(
  BuildContext context, {
  required List<String> jaEscolhidos,
}) {
  final busca = TextEditingController();
  final selecionados = <String>{...jaEscolhidos};
  return showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final termo = Conteudo.normalizar(busca.text);
        final livros = [
          for (final livro in canon)
            if (termo.isEmpty || Conteudo.normalizar(livro.nome).contains(termo))
              livro,
        ];
        return AlertDialog(
          title: const Text('Escolher livros'),
          content: SizedBox(
            width: 460,
            height: 480,
            child: Column(
              children: [
                TextField(
                  controller: busca,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Buscar livro',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Spacing.sp12),
                Expanded(
                  child: livros.isEmpty
                      ? const Center(child: Text('Nenhum livro encontrado.'))
                      : ListView.builder(
                          itemCount: livros.length,
                          itemBuilder: (context, i) {
                            final livro = livros[i];
                            return CheckboxListTile(
                              dense: true,
                              title: Text(livro.nome),
                              subtitle: Text(
                                '${livro.capitulos} '
                                '${livro.capitulos == 1 ? 'capítulo' : 'capítulos'}',
                              ),
                              value: selecionados.contains(livro.slug),
                              onChanged: (marcado) {
                                setDialogState(() {
                                  if (marcado == true) {
                                    selecionados.add(livro.slug);
                                  } else {
                                    selecionados.remove(livro.slug);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                selecionados.toList(),
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    ),
  );
}