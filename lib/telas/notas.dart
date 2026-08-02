import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import 'biblia.dart';
import 'comuns.dart';

/// Favoritos e anotações, em duas abas.
class TelaNotas extends StatelessWidget {
  const TelaNotas({super.key});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final estado = EscopoDoEstado.de(context);
    final favoritos = estado.marcacoes;
    final notas = estado.comNota;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marcações'),
          actions: [
            PopupMenuButton<void Function()>(
              tooltip: 'Cópia de segurança',
              icon: const Icon(Icons.more_vert),
              onSelected: (acao) => acao(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: () => _exportar(context, estado),
                  child: const ListTile(
                    leading: Icon(Icons.upload_outlined),
                    title: Text('Exportar cópia'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: () => _importar(context, estado),
                  child: const ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Importar cópia'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            labelColor: cor.secondary,
            unselectedLabelColor: cor.onSurfaceVariant,
            indicatorColor: cor.primary,
            tabs: [
              Tab(text: 'Favoritos (${favoritos.length})'),
              Tab(text: 'Anotações (${notas.length})'),
            ],
          ),
        ),
        body: LarguraDeLeitura(
          child: TabBarView(
            children: [
              _Lista(
                itens: favoritos,
                vazio: const AvisoVazio(
                  icone: Icons.bookmark_outline,
                  titulo: 'Nenhum favorito',
                  detalhe: 'Toque num versículo na Bíblia para favoritá-lo.',
                ),
              ),
              _Lista(
                itens: notas,
                mostrarNota: true,
                vazio: const AvisoVazio(
                  icone: Icons.edit_note,
                  titulo: 'Nenhuma anotação',
                  detalhe: 'Toque num versículo na Bíblia para anotar.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Joga a cópia na área de transferência.
///
/// ponytail: área de transferência, não arquivo. Favoritos, notas e progresso
/// vivem no SharedPreferences, que na web é o localStorage e o navegador limpa
/// sozinho sob pressão de espaço; texto escrito à mão não pode existir num lugar
/// só. Salvar arquivo de verdade exigiria ramificar por plataforma, que é
/// justamente o que este app evitou até aqui. Se um dia precisar, o caminho é
/// `share_plus`, que resolve mobile, desktop e download na web de uma vez.
Future<void> _exportar(BuildContext context, Estado estado) async {
  final mensageiro = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: estado.exportar()));
  mensageiro.showSnackBar(
    const SnackBar(
      content: Text('Cópia copiada. Cole num arquivo de texto e guarde.'),
    ),
  );
}

/// Pede a cópia colada e funde com o que já existe.
Future<void> _importar(BuildContext context, Estado estado) async {
  final controle = TextEditingController();
  final texto = await showDialog<String>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Importar cópia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cole aqui o texto exportado. Nada é apagado: a cópia se junta ao '
            'que já está no aparelho.',
            style: Theme.of(dialogo).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controle,
            autofocus: true,
            maxLines: 6,
            minLines: 4,
            decoration: const InputDecoration(hintText: '{ "versao": 1, ... }'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogo),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogo, controle.text),
          child: const Text('Importar'),
        ),
      ],
    ),
  );
  if (texto == null || texto.trim().isEmpty || !context.mounted) return;

  final mensageiro = ScaffoldMessenger.of(context);
  try {
    final (marcacoes, dias) = await estado.importar(texto);
    mensageiro.showSnackBar(
      SnackBar(
        content: Text(
          marcacoes == 0 && dias == 0
              ? 'Nada de novo na cópia; tudo já estava aqui.'
              : 'Importado: $marcacoes marcações, $dias dias de leitura.',
        ),
      ),
    );
  } on FormatException catch (erro) {
    mensageiro.showSnackBar(
      SnackBar(content: Text('Cópia não reconhecida. ${erro.message}')),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    required this.itens,
    required this.vazio,
    this.mostrarNota = false,
  });

  final List<Marcacao> itens;
  final Widget vazio;
  final bool mostrarNota;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return vazio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: itens.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) =>
          _CartaoDeMarcacao(marcacao: itens[i], mostrarNota: mostrarNota),
    );
  }
}

class _CartaoDeMarcacao extends StatelessWidget {
  const _CartaoDeMarcacao({required this.marcacao, required this.mostrarNota});

  final Marcacao marcacao;
  final bool mostrarNota;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final estado = EscopoDoEstado.de(context);
    final tema = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelaBiblia(
              livroInicial: marcacao.livro,
              capituloInicial: marcacao.capitulo,
              destacar: (marcacao.versiculo, marcacao.versiculo),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${marcacao.referencia}  ·  ${marcacao.versao.sigla}',
                      style: tema.titleSmall?.copyWith(color: cor.secondary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar anotação',
                    icon: const Icon(Icons.edit_note, size: 20),
                    onPressed: () async {
                      final nota = await editarNota(
                        context,
                        referencia: marcacao.referencia,
                        notaAtual: marcacao.nota,
                      );
                      if (nota != null) {
                        await estado.definirNota(
                          marcacao.versao,
                          marcacao.livro,
                          marcacao.capitulo,
                          marcacao.versiculo,
                          nota,
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      final confirmou = await confirmarRemocao(
                        context,
                        referencia: marcacao.referencia,
                        comNota: marcacao.nota.isNotEmpty,
                      );
                      if (confirmou) estado.removerMarcacao(marcacao);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // O texto do versículo não é guardado junto da marcação: fica sempre
              // na versão salva, e assim uma correção no asset se reflete aqui.
              CarregaUmaVez<String>(
                chave: marcacao.chave,
                carregar: () => Conteudo.instancia.versiculo(
                  marcacao.versao,
                  marcacao.livro,
                  marcacao.capitulo,
                  marcacao.versiculo,
                ),
                // Falhar aqui deixava o cartão com o texto do versículo em branco,
                // sem dizer nada. A referência e a nota continuam visíveis, então
                // basta uma linha no lugar do versículo.
                construir: (context, snap) => Text(
                  snap.hasError
                      ? 'Não foi possível carregar o texto deste versículo.'
                      : snap.data ?? '',
                  style: tema.bodyMedium?.copyWith(
                    height: 1.55,
                    fontStyle: snap.hasError ? FontStyle.italic : null,
                    color: snap.hasError ? cor.onSurfaceVariant : null,
                  ),
                ),
              ),
              if (mostrarNota && marcacao.nota.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cor.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: cor.primary, width: 3),
                    ),
                  ),
                  child: Text(
                    marcacao.nota,
                    style: tema.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
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
