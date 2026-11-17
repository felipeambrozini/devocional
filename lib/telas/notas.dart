import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../controladores/notas_controlador.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/leitura_de_livros.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/abrir_na_biblia.dart';
import '../funcoes/aviso.dart';
import '../funcoes/dialogos.dart';
import '../funcoes/origem_do_destaque.dart';
import '../widgets/widgets.dart';

/// Favoritos e anotações de uma aba do app ([origem]), em duas abas, com busca.
/// Bíblia, Devocional e Biblioteca não se misturam: cada uma mostra só o que
/// foi marcado nela.
class TelaNotas extends StatefulWidget {
  const TelaNotas({super.key, this.origem = OrigemDasNotas.biblia});

  final OrigemDasNotas origem;

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
        final estado = EscopoDoEstado.de(context);
        final origem = widget.origem;
        final ehBiblia = origem == OrigemDasNotas.biblia;
        final favoritos = ehBiblia ? _controller.filtrar(estado.marcacoes) : [];
        final notas = ehBiblia ? _controller.filtrar(estado.comNota) : [];
        final destaques = ehBiblia
            ? const <DestaqueDeLivro>[]
            : _destaques(estado);
        final destaquesComNota = [
          for (final d in destaques)
            if (d.nota.trim().isNotEmpty) d,
        ];
        final totalFavoritos = ehBiblia ? favoritos.length : destaques.length;
        final totalNotas = ehBiblia ? notas.length : destaquesComNota.length;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: DevocionalAppBar(
              title: Text('Notas: ${origem.rotulo}'),
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
                tabs: [
                  Tab(text: 'Favoritos ($totalFavoritos)'),
                  Tab(text: 'Notas ($totalNotas)'),
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
                      (estado.marcacoes.isNotEmpty ||
                          estado.diasLidosEmTodosOsAnos > 0))
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
                        _lista(
                          estado: estado,
                          ehBiblia: ehBiblia,
                          marcacoes: [...favoritos],
                          destaques: destaques,
                          vazio: _vazio(
                            icone: FontAwesomeIcons.bookmark,
                            titulo: 'Nenhum favorito',
                            detalhe: _dicaDeFavorito(origem),
                          ),
                        ),
                        _lista(
                          estado: estado,
                          ehBiblia: ehBiblia,
                          marcacoes: [...notas],
                          destaques: destaquesComNota,
                          mostrarNota: true,
                          vazio: _vazio(
                            icone: FontAwesomeIcons.penToSquare,
                            titulo: 'Nenhuma anotação',
                            detalhe: _dicaDeNota(origem),
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

/// Os favoritos da aba que não é a Bíblia, já filtrados pela busca: livros da
/// Biblioteca ou leituras do Devocional, cada um no seu armazenamento
/// compartilhado (ver `ehSlugDeDevocional`).
extension on _TelaNotasState {
  List<DestaqueDeLivro> _destaques(Estado estado) {
    final doDevocional = widget.origem == OrigemDasNotas.devocional;
    final lista = [
      for (final d in estado.leituraDeLivros.todosOsDestaques)
        if (ehSlugDeDevocional(d.slug) == doDevocional)
          if (OrigemDoDestaque.de(d) case final origem?)
            if (_controller.combina(origem.referencia, d.nota)) d,
    ];
    // Devocional pelo calendário (a leitura do dia, não da leitura): o que
    // se favoritou em janeiro vem antes do de dezembro.
    if (doDevocional) {
      lista.sort((a, b) {
        final porDia = a.capitulo.compareTo(b.capitulo);
        return porDia != 0 ? porDia : a.slug.compareTo(b.slug);
      });
    }
    return lista;
  }

  Widget _vazio({
    required FaIconData icone,
    required String titulo,
    required String detalhe,
  }) => _controller.busca.isEmpty
      ? DevocionalAvisoVazio(icone: icone, titulo: titulo, detalhe: detalhe)
      : const DevocionalAvisoVazio(
          icone: FontAwesomeIcons.magnifyingGlassMinus,
          titulo: 'Nada encontrado',
        );

  Widget _lista({
    required Estado estado,
    required bool ehBiblia,
    required List<Marcacao> marcacoes,
    required List<DestaqueDeLivro> destaques,
    required Widget vazio,
    bool mostrarNota = false,
  }) {
    if (ehBiblia) {
      return DevocionalListaDeNotas(
        quantidade: marcacoes.length,
        vazio: vazio,
        construir: (context, i) =>
            _cartaoDaMarcacao(context, estado, marcacoes[i], mostrarNota),
      );
    }
    // Destaque de um livro que saiu do catálogo não tem para onde levar.
    final visiveis = [
      for (final d in destaques)
        if (OrigemDoDestaque.de(d) case final origem?) (d, origem),
    ];
    return DevocionalListaDeNotas(
      quantidade: visiveis.length,
      vazio: vazio,
      construir: (context, i) => _cartaoDoDestaque(
        context,
        estado.leituraDeLivros,
        visiveis[i].$1,
        visiveis[i].$2,
        mostrarNota,
      ),
    );
  }
}

Widget _cartaoDaMarcacao(
  BuildContext context,
  Estado estado,
  Marcacao m,
  bool mostrarNota,
) => DevocionalCartaoDeNota(
  referencia: m.referencia,
  chaveDoTexto: m.chave,
  carregarTexto: () =>
      Conteudo.instancia.versiculo(m.livro, m.capitulo, m.versiculo),
  mensagemDeFalha: 'Não foi possível carregar o texto deste versículo.',
  nota: m.nota,
  mostrarNota: mostrarNota,
  aoAbrir: () => abrirNaBiblia(
    context,
    m.livro,
    m.capitulo,
    destacar: (m.versiculo, m.versiculo),
  ),
  aoSalvarNota: (nota) =>
      estado.definirNota(m.livro, m.capitulo, m.versiculo, nota),
  aoRemover: () => estado.removerMarcacao(m),
);

Widget _cartaoDoDestaque(
  BuildContext context,
  LeituraDeLivros leitura,
  DestaqueDeLivro d,
  OrigemDoDestaque origem,
  bool mostrarNota,
) => DevocionalCartaoDeNota(
  referencia: origem.referencia,
  chaveDoTexto: d.chave,
  carregarTexto: () => textoDoDestaque(d),
  maxLinhas: 4,
  nota: d.nota,
  mostrarNota: mostrarNota,
  aoAbrir: () => context.go(origem.rotaDeAbrir),
  aoSalvarNota: (nota) =>
      leitura.definirNota(d.slug, d.capitulo, d.paragrafo, nota),
  aoRemover: () => leitura.removerDestaque(d),
);

String _dicaDeFavorito(OrigemDasNotas origem) => switch (origem) {
  OrigemDasNotas.biblia => 'Toque num versículo na Bíblia para favoritá-lo.',
  OrigemDasNotas.devocional =>
    'Toque no texto de um devocional para favoritá-lo.',
  OrigemDasNotas.biblioteca =>
    'Toque num parágrafo de um livro da Biblioteca para favoritá-lo.',
};

String _dicaDeNota(OrigemDasNotas origem) => switch (origem) {
  OrigemDasNotas.biblia => 'Toque num versículo na Bíblia para anotar.',
  OrigemDasNotas.devocional => 'Toque no texto de um devocional para anotar.',
  OrigemDasNotas.biblioteca =>
    'Toque num parágrafo de um livro da Biblioteca para anotar.',
};

/// A cópia sai pela folha de compartilhar, não pela área de transferência.
/// Favoritos, notas e progresso vivem no SharedPreferences, que na web é o
/// localStorage e o navegador limpa sozinho sob pressão de espaço; texto
/// escrito à mão não pode existir num lugar só. O texto é o mesmo de antes
/// (o que o "importar" abaixo sabe ler, colando), então a simetria
/// exportar/importar continua: a folha de compartilhar tem Copiar, e quem
/// prefere o app de Notas manda direto para lá sem passar pelo copiar-colar.
/// Se um dia precisar de arquivo de verdade, o caminho é
/// `SharePlus.instance.share(ShareParams(files: [...]))`.
Future<void> _exportar(BuildContext context, Estado estado) async {
  final mensageiro = ScaffoldMessenger.of(context);
  await SharePlus.instance.share(ShareParams(text: estado.exportar()));
  mostrarAvisoNo(
    mensageiro,
    'Cópia enviada. Para guardar, salve no app de Notas; '
    'depois, é colando aqui de novo que você importa.',
  );
}

Future<void> _importar(BuildContext context, Estado estado) async {
  final texto = await showDialog<String>(
    context: context,
    builder: (_) => DialogoDeTexto(
      titulo: 'Importar cópia',
      rotuloDoCampo: 'Texto exportado',
      rotuloDaAcao: 'Importar',
      descricao:
          'Cole aqui o texto exportado. Nada é apagado: a cópia se junta ao '
          'que já está no aparelho.',
      linhasMin: 4,
      // Mesmo padrão da busca: no celular o teclado cobriria o diálogo.
      autofocus: !kIsWeb,
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
