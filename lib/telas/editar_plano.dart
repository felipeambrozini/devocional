import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/planos.dart';
import '../estilo/spacing.dart';
import '../funcoes/aviso.dart';
import 'novo_plano.dart' show mostrarSeletorDeLivros;

/// O que [mostrarEditorDePlano] devolve quando confirmado.
typedef EdicaoDePlano = ({
  String titulo,
  List<String> livros,
  int dias,
  bool incluirDevocionais,
  bool devocionalAntes,
});

/// Diálogo para editar um plano já criado: os mesmos campos de
/// `novo_plano.dart` (nome, livros, dias, devocionais), pré-preenchidos.
/// Devolve nulo se cancelado.
///
/// Mudar livros ou dias remonta os dias do plano — o dia 5 de hoje pode
/// virar outro trecho da Bíblia amanhã — então o botão de salvar confirma
/// isso à parte quando é o caso: ver [_confirmarSeMudouODiaADia].
Future<EdicaoDePlano?> mostrarEditorDePlano(
  BuildContext context,
  PlanoDoUsuario plano,
) {
  final titulo = TextEditingController(text: plano.titulo);
  final dias = TextEditingController(text: '${plano.dias}');
  final livros = [...plano.livros];
  var incluirDevocionais = plano.incluirDevocionais;
  var devocionalAntes = plano.devocionalAntes;
  final form = GlobalKey<FormState>();

  int totalDeCapitulos() {
    var total = 0;
    for (final slug in livros) {
      total += livroPorSlug(slug)?.capitulos ?? 0;
    }
    return total;
  }

  String? validarDias(String? valor) {
    final numero = int.tryParse(valor ?? '');
    if (numero == null || numero < 1) {
      return 'Informe em quantos dias o plano acontece.';
    }
    final total = totalDeCapitulos();
    if (total > 0 && numero > total) {
      return 'Os livros têm $total capítulos; o máximo é $total dias.';
    }
    return null;
  }

  return showDialog<EdicaoDePlano>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> escolherLivros() async {
          final escolhidos = await mostrarSeletorDeLivros(
            dialogContext,
            jaEscolhidos: livros,
          );
          if (escolhidos == null) return;
          setDialogState(() {
            livros
              ..clear()
              ..addAll(escolhidos);
          });
        }

        Future<void> salvar() async {
          if (livros.isEmpty) {
            mostrarAviso(dialogContext, 'Escolha pelo menos um livro.');
            return;
          }
          if (!(form.currentState?.validate() ?? false)) return;
          final novoTotalDeDias = int.parse(dias.text);
          final mudouODiaADia =
              novoTotalDeDias != plano.dias ||
              livros.length != plano.livros.length ||
              !livros.asMap().entries.every(
                (e) => e.value == plano.livros[e.key],
              );
          if (mudouODiaADia) {
            final confirmou = await confirmar(
              dialogContext,
              titulo: 'Reiniciar o progresso?',
              conteudo:
                  'Mudar os livros ou os dias remonta o plano: o progresso '
                  'já marcado deste aparelho será apagado, porque o dia 5 de '
                  'hoje pode virar outro trecho da Bíblia.',
              rotuloDaAcao: 'Mudar e reiniciar',
            );
            if (!confirmou) return;
          }
          if (!dialogContext.mounted) return;
          Navigator.pop(dialogContext, (
            titulo: titulo.text,
            livros: List<String>.from(livros),
            dias: novoTotalDeDias,
            incluirDevocionais: incluirDevocionais,
            devocionalAntes: devocionalAntes,
          ));
        }

        return AlertDialog(
          title: const Text('Editar plano'),
          content: SizedBox(
            width: 420,
            height: 520,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titulo,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome do plano',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Spacing.sp20),
                    Text(
                      'Quais livros?',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: Spacing.sp8),
                    OutlinedButton.icon(
                      onPressed: escolherLivros,
                      icon: const Icon(Icons.library_books_outlined),
                      label: Text(
                        '${livros.length} '
                        '${livros.length == 1 ? 'livro' : 'livros'} '
                        'escolhidos',
                      ),
                    ),
                    if (livros.isNotEmpty) ...[
                      const SizedBox(height: Spacing.sp10),
                      Wrap(
                        spacing: Spacing.sp8,
                        runSpacing: Spacing.sp8,
                        children: [
                          for (final slug in livros)
                            InputChip(
                              label: Text(nomeDoLivro(slug)),
                              onDeleted: () => setDialogState(
                                () => livros.remove(slug),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Spacing.sp20),
                    Text(
                      'Em quantos dias?',
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: Spacing.sp8),
                    TextFormField(
                      controller: dias,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      validator: validarDias,
                      decoration: InputDecoration(
                        helperText: totalDeCapitulos() == 0
                            ? 'Escolha os livros para ver o tamanho do plano.'
                            : 'O plano terá ${totalDeCapitulos()} '
                                  '${totalDeCapitulos() == 1 ? 'capítulo' : 'capítulos'}.',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Spacing.sp20),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Incluir devocionais dos livros'),
                      subtitle: const Text(
                        'Junto de cada capítulo, os devocionais de Manhã, '
                        'Noite e Promessas de Deus que citam aquele texto.',
                      ),
                      value: incluirDevocionais,
                      onChanged: (marcado) => setDialogState(
                        () => incluirDevocionais = marcado ?? false,
                      ),
                    ),
                    if (incluirDevocionais) ...[
                      const SizedBox(height: Spacing.sp8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Antes do capítulo'),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Depois do capítulo'),
                          ),
                        ],
                        selected: {devocionalAntes},
                        onSelectionChanged: (novo) =>
                            setDialogState(() => devocionalAntes = novo.first),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(onPressed: salvar, child: const Text('Salvar')),
          ],
        );
      },
    ),
  );
}
