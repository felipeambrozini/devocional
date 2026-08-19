import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/nuvem.dart';
import '../spacing.dart';
import 'biblia.dart';
import 'comuns.dart';

/// Favoritos e anotações, em duas abas, com busca.
class TelaNotas extends StatefulWidget {
  const TelaNotas({super.key});

  @override
  State<TelaNotas> createState() => _TelaNotasState();
}

class _TelaNotasState extends State<TelaNotas> {
  final _controle = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  /// Filtra por referência (ex. "João 3:16") e pelo texto da própria nota.
  ///
  /// Não pelo corpo do versículo: ele é carregado sob demanda, um por cartão
  /// (ver `Conteudo.instancia.versiculo` abaixo), e trazer todos para buscar
  /// no corpo derrubaria exatamente o carregamento tardio que o app inteiro
  /// foi desenhado para ter.
  List<Marcacao> _filtrar(List<Marcacao> itens) {
    if (_busca.isEmpty) return itens;
    final alvo = Conteudo.normalizar(_busca);
    return itens
        .where(
          (m) =>
              Conteudo.normalizar(m.referencia).contains(alvo) ||
              Conteudo.normalizar(m.nota).contains(alvo),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final estado = EscopoDoEstado.de(context);
    final favoritos = _filtrar(estado.marcacoes);
    final notas = _filtrar(estado.comNota);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favoritos e notas'),
          actions: [
            IconButton(
              tooltip: 'Tamanho do texto e aparência',
              icon: const Icon(Icons.tune),
              onPressed: () => ajustesDeLeitura(context, estado),
            ),
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
          child: Column(
            children: [
              // Só na web: o navegador pode limpar o localStorage sem aviso,
              // e ninguém além de quem já leu o README sabe disso. Sem
              // Dismissible de propósito — o risco não desaparece porque a
              // pessoa fechou o aviso uma vez. E só avisa quando já há o que
              // perder: quem chega sem favorito nem dia lido ouviria do risco
              // antes de ter algo para guardar (medo antes do valor).
              if (kIsWeb &&
                  (estado.marcacoes.isNotEmpty || estado.diasLidos > 0))
                _AvisoDePerda(onExportar: () => _exportar(context, estado)),
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.sp16, Spacing.sp12, Spacing.sp16, Spacing.sp4),
                child: TextField(
                  controller: _controle,
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar por referência ou anotação',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busca.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Limpar busca',
                            onPressed: () => setState(() {
                              _controle.clear();
                              _busca = '';
                            }),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _Lista(
                      itens: favoritos,
                      vazio: _busca.isEmpty
                          ? const AvisoVazio(
                              icone: Icons.bookmark_outline,
                              titulo: 'Nenhum favorito',
                              detalhe:
                                  'Toque num versículo na Bíblia para favoritá-lo.',
                            )
                          : const AvisoVazio(
                              icone: Icons.search_off,
                              titulo: 'Nada encontrado',
                            ),
                    ),
                    _Lista(
                      itens: notas,
                      mostrarNota: true,
                      vazio: _busca.isEmpty
                          ? const AvisoVazio(
                              icone: Icons.edit_note,
                              titulo: 'Nenhuma anotação',
                              detalhe:
                                  'Toque num versículo na Bíblia para anotar.',
                            )
                          : const AvisoVazio(
                              icone: Icons.search_off,
                              titulo: 'Nada encontrado',
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faixa fixa, só na web: quem usa o app pelo navegador não tem como saber
/// que o localStorage pode ser limpo sem aviso (ver `_exportar` abaixo).
///
/// Logado, o risco de perder continua existindo — o navegador ainda pode
/// limpar — mas deixa de ser uma perda de verdade, porque agora tem de onde
/// voltar. Por isso só o texto muda com `Nuvem.instancia.logado`; o botão
/// "Exportar" fica, porque é a saída que não depende de conta nem de servidor.
class _AvisoDePerda extends StatelessWidget {
  const _AvisoDePerda({required this.onExportar});

  final VoidCallback onExportar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cor.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(Spacing.sp16, Spacing.sp10, Spacing.sp8, Spacing.sp10),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cor.onSurfaceVariant, size: 20),
          const SizedBox(width: Spacing.sp12),
          Expanded(
            child: ListenableBuilder(
              listenable: Nuvem.instancia,
              builder: (context, _) => Text(
                Nuvem.instancia.logado
                    ? 'Suas notas também estão salvas na sua conta Google.'
                    : 'Na web, o navegador pode apagar suas notas sem aviso.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          TextButton(onPressed: onExportar, child: const Text('Exportar')),
        ],
      ),
    );
  }
}

/// Joga a cópia na área de transferência.
///
/// ponytail: área de transferência, não arquivo. Favoritos, notas e progresso
/// vivem no SharedPreferences, que na web é o localStorage e o navegador limpa
/// sozinho sob pressão de espaço; texto escrito à mão não pode existir num lugar
/// só. `share_plus` já é dependência do app (usado para compartilhar um
/// versículo, em `biblia.dart`), mas exportar por arquivo trocaria o
/// "importar" por escolher um arquivo em vez de colar, e o de colar continua
/// sendo o caminho simétrico: mesma caixa de texto serve para exportar e para
/// importar. Se um dia precisar de arquivo de verdade, o caminho é
/// `SharePlus.instance.share(ShareParams(files: [...]))`.
Future<void> _exportar(BuildContext context, Estado estado) async {
  final mensageiro = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: estado.exportar()));
  mensageiro.showSnackBar(
    const SnackBar(content: Text('Copiado. Guarde num arquivo de texto.')),
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
          const SizedBox(height: Spacing.sp12),
          TextField(
            controller: controle,
            autofocus: true,
            maxLines: 6,
            minLines: 4,
            decoration: const InputDecoration(),
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
              : 'Importado: $marcacoes favoritos, $dias dias de leitura.',
        ),
      ),
    );
  } on FormatException {
    mensageiro.showSnackBar(
      const SnackBar(
        content: Text(
          'Cópia não reconhecida. Verifique se colou o texto inteiro exportado '
          'e tente de novo.',
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(Spacing.sp16, Spacing.sp16, Spacing.sp16, Spacing.sp32),
      itemCount: itens.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sp10),
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
          padding: const EdgeInsets.fromLTRB(Spacing.sp16, Spacing.sp12, Spacing.sp8, Spacing.sp12),
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
              const SizedBox(height: Spacing.sp4),
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
                const SizedBox(height: Spacing.sp12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Spacing.sp12),
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
