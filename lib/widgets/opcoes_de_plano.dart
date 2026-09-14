import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../estilo/espacamento.dart';
import '../funcoes/dialogos.dart';
import 'botao.dart';
import 'filete.dart';

/// Os trechos iguais dos formulários de plano novo e de edição: os livros
/// escolhidos e a opção de incluir devocionais. Um lugar só, para os dois
/// formulários não vestirem o mesmo Material cru cada um à sua maneira.
///
/// Não inclui o botão "Escolher livros" nem os campos de nome e dias: esses
/// falam com o controlador de cada tela, e só a lista e a opção se repetem.
class DevocionalLivrosEscolhidos extends StatefulWidget {
  const DevocionalLivrosEscolhidos({
    super.key,
    required this.livros,
    required this.aoRemover,
    this.aoReordenar,
    this.aoRestaurar,
  });

  final List<String> livros;
  final ValueChanged<String> aoRemover;

  /// Chamado com a nova ordem quando quem cria/edita confirma a reordenação.
  /// Nulo esconde o botão de ordenar — só aparece com 2+ livros de todo modo.
  final ValueChanged<List<String>>? aoReordenar;

  /// Recoloca livros que o Desfazer do snackbar traz de volta, no ponto de
  /// onde saíram. Nulo esconde o Desfazer (a remoção segue valendo).
  final void Function(List<String> slugs, int indice)? aoRestaurar;

  @override
  State<DevocionalLivrosEscolhidos> createState() =>
      _DevocionalLivrosEscolhidosState();
}

class _DevocionalLivrosEscolhidosState
    extends State<DevocionalLivrosEscolhidos> {
  /// Acima disto os chips colapsam no resumo, para a lista não empurrar o
  /// resto do formulário para baixo do fold.
  static const _limiteVisivel = 6;

  bool _expandido = false;

  void _remover(BuildContext context, String slug) {
    final indice = widget.livros.indexOf(slug);
    widget.aoRemover(slug);
    final restaurar = widget.aoRestaurar;
    if (restaurar == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${nomeDoLivro(slug)} removido.'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () => restaurar([slug], indice < 0 ? 0 : indice),
          ),
        ),
      );
  }

  void _limpar(BuildContext context) {
    final backup = List<String>.from(widget.livros);
    for (final slug in backup) {
      widget.aoRemover(slug);
    }
    final restaurar = widget.aoRestaurar;
    if (restaurar == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${backup.length} livros removidos.'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () => restaurar(backup, 0),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final livros = widget.livros;
    final reordenar = widget.aoReordenar;
    final colapsado = livros.length > _limiteVisivel && !_expandido;
    final visiveis = colapsado ? livros.take(_limiteVisivel).toList() : livros;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (colapsado)
          Text(
            '${livros.length} livros: '
            '${nomeDoLivro(livros.first)}…${nomeDoLivro(livros.last)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        if (colapsado) const SizedBox(height: DevocionalEspacamento.sp8),
        Wrap(
          spacing: DevocionalEspacamento.sp8,
          runSpacing: DevocionalEspacamento.sp8,
          children: [
            for (var i = 0; i < visiveis.length; i++)
              InputChip(
                // A posição conta: a ordem dos livros decide o que cai em
                // cada dia, então o chip já mostra onde cada um está.
                label: Text(
                  livros.length > 1
                      ? '${i + 1} · ${nomeDoLivro(visiveis[i])}'
                      : nomeDoLivro(visiveis[i]),
                ),
                // Sem o tique do Material: neste sistema chip não carrega
                // checkmark (ver o alternador de leitura).
                showCheckmark: false,
                onDeleted: () => _remover(context, visiveis[i]),
              ),
          ],
        ),
        const SizedBox(height: DevocionalEspacamento.sp4),
        Wrap(
          spacing: DevocionalEspacamento.sp8,
          runSpacing: DevocionalEspacamento.sp4,
          children: [
            if (colapsado)
              DevocionalBotaoTerciario(
                onPressed: () => setState(() => _expandido = true),
                child: Text('Ver todos (${livros.length})'),
              )
            else if (livros.length > _limiteVisivel)
              DevocionalBotaoTerciario(
                onPressed: () => setState(() => _expandido = false),
                child: const Text('Ver menos'),
              ),
            if (livros.length > 1)
              DevocionalBotaoTerciario(
                onPressed: () => _limpar(context),
                child: const Text('Limpar'),
              ),
            if (reordenar != null && livros.length > 1)
              DevocionalBotaoTerciario.icon(
                onPressed: () async {
                  final novaOrdem = await mostrarEditorDeOrdemDosLivros(
                    context,
                    livros: livros,
                  );
                  if (novaOrdem != null) reordenar(novaOrdem);
                },
                icon: const FaIcon(FontAwesomeIcons.listOl),
                label: const Text('Alterar ordem de leitura'),
              ),
          ],
        ),
      ],
    );
  }
}

/// A caixa de incluir devocionais com o antes/depois: o mesmo bloco nos dois
/// formulários, com o texto único da opção.
class DevocionalOpcaoDeDevocionais extends StatelessWidget {
  const DevocionalOpcaoDeDevocionais({
    super.key,
    required this.incluir,
    required this.antes,
    required this.aoMudarIncluir,
    required this.aoMudarOrdem,
  });

  final bool incluir;
  final bool antes;
  final ValueChanged<bool?> aoMudarIncluir;
  final ValueChanged<bool> aoMudarOrdem;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          // Explícito em vez do padrão do Material: o metal do tema é a
          // única cor de destaque do sistema.
          activeColor: cor.primary,
          title: const Text('Incluir devocionais dos livros'),
          subtitle: const Text(
            'Junto de cada capítulo, os devocionais de Manhã, '
            'Noite e Promessas de Deus que citam aquele texto.',
          ),
          value: incluir,
          onChanged: aoMudarIncluir,
        ),
        if (incluir) ...[
          const SizedBox(height: DevocionalEspacamento.sp8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DevocionalEspacamento.sp12),
            decoration: BoxDecoration(
              border: Border.all(color: cor.outline.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: DevocionalEspacamento.sp8,
              runSpacing: DevocionalEspacamento.sp8,
              children: [
                ChoiceChip(
                  label: const Text('Antes do capítulo'),
                  selected: antes,
                  showCheckmark: false,
                  onSelected: (_) => aoMudarOrdem(true),
                ),
                ChoiceChip(
                  label: const Text('Depois do capítulo'),
                  selected: !antes,
                  showCheckmark: false,
                  onSelected: (_) => aoMudarOrdem(false),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Editor da ordem de leitura dos livros de um plano: a lista atual, que quem
/// cria/edita arrasta ou move com as setas. Devolve a nova ordem, ou nulo se
/// cancelado.
///
/// A ordem importa: [montarPlanoDeLeitura] lê do primeiro capítulo do
/// primeiro livro ao último do último, então trocar a ordem remonta os dias.
Future<List<String>?> mostrarEditorDeOrdemDosLivros(
  BuildContext context, {
  required List<String> livros,
}) {
  final ordem = [...livros];
  return showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        void mover(int de, int para) {
          setDialogState(() {
            final slug = ordem.removeAt(de);
            ordem.insert(para, slug);
          });
        }

        return AlertDialog(
          title: Text(
            'Ordem de leitura',
            style: Theme.of(dialogContext).textTheme.headlineSmall,
          ),
          content: SizedBox(
            width: larguraDeDialogo(dialogContext, 420),
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DevocionalFilete(largura: 48),
                const SizedBox(height: DevocionalEspacamento.sp8),
                Text(
                  'Quem lê começa pelo primeiro livro: a ordem decide o que cai em cada dia.',
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DevocionalEspacamento.sp12),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: ordem.length,
                    onReorderItem: (antigo, novo) {
                      setDialogState(() {
                        final slug = ordem.removeAt(antigo);
                        ordem.insert(novo, slug);
                      });
                    },
                    itemBuilder: (context, i) {
                      final slug = ordem[i];
                      final capitulos = livroPorSlug(slug)?.capitulos ?? 0;
                      return ListTile(
                        key: ValueKey(slug),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text('${i + 1}º · ${nomeDoLivro(slug)}'),
                        subtitle: Text(
                          '$capitulos ${capitulos == 1 ? 'capítulo' : 'capítulos'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Mover para cima',
                              icon: const Icon(Icons.arrow_upward),
                              onPressed: i == 0 ? null : () => mover(i, i - 1),
                            ),
                            IconButton(
                              tooltip: 'Mover para baixo',
                              icon: const Icon(Icons.arrow_downward),
                              onPressed: i == ordem.length - 1
                                  ? null
                                  : () => mover(i, i + 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            DevocionalBotaoTerciario(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            DevocionalBotaoPrimario(
              onPressed: () =>
                  Navigator.pop(dialogContext, List<String>.from(ordem)),
              child: const Text('Salvar ordem'),
            ),
          ],
        );
      },
    ),
  );
}
