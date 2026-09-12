import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controladores/notas_controlador.dart';
import '../dados/estado.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../widgets/widgets.dart';

/// Favoritos e anotações, em duas abas, com busca.
class TelaNotas extends StatefulWidget {
  const TelaNotas({super.key});

  @override
  State<TelaNotas> createState() => _TelaNotasState();
}

class _TelaNotasState extends State<TelaNotas> {
  final _controller = NotasControlador();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final cor = Theme.of(context).colorScheme;
        final estado = EscopoDoEstado.de(context);
        final favoritos = _controller.filtrar(estado.marcacoes);
        final notas = _controller.filtrar(estado.comNota);

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: DevocionalAppBar(
              title: const Text('Favoritos e notas'),
              actions: [
                DevocionalBotaoDeAjustes(estado: estado),
                PopupMenuButton<void Function()>(
                  tooltip: 'Cópia de segurança',
                  icon: const FaIcon(FontAwesomeIcons.ellipsisVertical),
                  onSelected: (acao) => acao(),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: () => _exportar(context, estado),
                      child: const DevocionalItemDeMenu(
                        icone: FontAwesomeIcons.upload,
                        rotulo: 'Exportar cópia',
                      ),
                    ),
                    PopupMenuItem(
                      value: () => _importar(context, estado),
                      child: const DevocionalItemDeMenu(
                        icone: FontAwesomeIcons.download,
                        rotulo: 'Importar cópia',
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
                  Tab(text: 'Notas (${notas.length})'),
                ],
              ),
            ),
            body: DevocionalLarguraDeLeitura(
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
                    DevocionalAvisoDePerda(
                      onExportar: () => _exportar(context, estado),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DevocionalEspacamento.sp16,
                      DevocionalEspacamento.sp12,
                      DevocionalEspacamento.sp16,
                      DevocionalEspacamento.sp4,
                    ),
                    child: DevocionalBusca(
                      controller: _controller.controle,
                      hintText: 'Buscar por referência ou anotação',
                      onChanged: _controller.aoDigitar,
                      aoLimpar: _controller.limpar,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        DevocionalLista(
                          itens: favoritos,
                          vazio: _controller.busca.isEmpty
                              ? const DevocionalAvisoVazio(
                                  icone: FontAwesomeIcons.bookmark,
                                  titulo: 'Nenhum favorito',
                                  detalhe:
                                      'Toque num versículo na Bíblia para favoritá-lo.',
                                )
                              : const DevocionalAvisoVazio(
                                  icone: FontAwesomeIcons.magnifyingGlassMinus,
                                  titulo: 'Nada encontrado',
                                ),
                        ),
                        DevocionalLista(
                          itens: notas,
                          mostrarNota: true,
                          vazio: _controller.busca.isEmpty
                              ? const DevocionalAvisoVazio(
                                  icone: FontAwesomeIcons.penToSquare,
                                  titulo: 'Nenhuma anotação',
                                  detalhe:
                                      'Toque num versículo na Bíblia para anotar.',
                                )
                              : const DevocionalAvisoVazio(
                                  icone: FontAwesomeIcons.magnifyingGlassMinus,
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
      },
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
  mostrarAvisoNo(
    mensageiro,
    'Copiado. Cole num e-mail ou no app de Notas do aparelho para guardar — '
    'depois, é colando aqui de novo que você importa.',
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
          const SizedBox(height: DevocionalEspacamento.sp12),
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
        DevocionalBotaoTerciario(
          onPressed: () => Navigator.pop(dialogo),
          child: const Text('Cancelar'),
        ),
        DevocionalBotaoPrimario(
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
    mostrarAvisoNo(
      mensageiro,
      marcacoes == 0 && dias == 0
          ? 'Nada de novo na cópia; tudo já estava aqui.'
          : 'Importado: $marcacoes favoritos, $dias dias de leitura.',
    );
  } on FormatException {
    mostrarErroNo(
      mensageiro,
      'Cópia não reconhecida. Verifique se colou o texto inteiro exportado '
      'e tente de novo.',
    );
  }
}
