import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controladores/novo_plano_controlador.dart';
import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/planos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/dialogos.dart';
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
  late final _controller = NovoPlanoControlador(estado: widget.estado);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final livros = _controller.livros;
        final dias = int.tryParse(_controller.dias.text) ?? 0;
        final previa = _controller.previa;
        final totalDeCapitulos = _controller.totalDeCapitulos;

        return Scaffold(
          appBar: DevocionalAppBar(title: const Text('Novo plano de leitura')),
          body: DevocionalLarguraDeLeitura(
            child: Form(
              key: _controller.form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DevocionalEspacamento.sp16,
                  DevocionalEspacamento.sp12,
                  DevocionalEspacamento.sp16,
                  DevocionalEspacamento.sp32,
                ),
                children: [
                  TextFormField(
                    controller: _controller.titulo,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nome do plano (opcional)',
                      hintText: livros.isEmpty
                          ? 'Ex.: Ler os Evangelhos'
                          : tituloDePlano(livros, dias),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp20),
                  Text('Quais livros?', style: tema.titleMedium),
                  const SizedBox(height: DevocionalEspacamento.sp8),
                  DevocionalBotaoSecundario.icon(
                    onPressed: () => _controller.escolherLivros(context),
                    icon: const FaIcon(FontAwesomeIcons.book),
                    label: Text(
                      livros.isEmpty
                          ? 'Escolher livros'
                          : '${livros.length} '
                                '${livros.length == 1 ? 'livro' : 'livros'} '
                                'escolhidos',
                    ),
                  ),
                  if (livros.isNotEmpty) ...[
                    const SizedBox(height: DevocionalEspacamento.sp10),
                    DevocionalLivrosEscolhidos(
                      livros: livros,
                      aoRemover: _controller.removerLivro,
                      aoReordenar: _controller.reordenarLivros,
                      aoRestaurar: _controller.restaurarLivros,
                    ),
                  ],
                  const SizedBox(height: DevocionalEspacamento.sp20),
                  Text('Em quantos dias?', style: tema.titleMedium),
                  const SizedBox(height: DevocionalEspacamento.sp8),
                  TextFormField(
                    controller: _controller.dias,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _controller.diasAlterados(),
                    validator: _controller.validarDias,
                    // O texto de ajuda já mostra o teto de capítulos enquanto
                    // digita; sem isto, o erro só aparecia ao tocar "Criar
                    // plano", mesmo com o valor inválido visível há tempo.
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      helperText: totalDeCapitulos == 0
                          ? 'Escolha os livros para ver o tamanho do plano.'
                          : 'O plano terá $totalDeCapitulos '
                                '${totalDeCapitulos == 1 ? 'capítulo' : 'capítulos'}.',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: DevocionalEspacamento.sp20),
                  DevocionalOpcaoDeDevocionais(
                    incluir: _controller.incluirDevocionais,
                    antes: _controller.devocionalAntes,
                    aoMudarIncluir: _controller.definirIncluirDevocionais,
                    aoMudarOrdem: _controller.definirDevocionalAntes,
                  ),
                  if (previa.isNotEmpty) ...[
                    const SizedBox(height: DevocionalEspacamento.sp20),
                    DevocionalCartao(
                      titulo: 'Prévia',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final dia in previa.take(5))
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: DevocionalEspacamento.sp4,
                              ),
                              child: Text(
                                'Dia ${dia.numero} · ${dia.rotulo}',
                                style: tema.bodySmall,
                              ),
                            ),
                          if (previa.length > 5)
                            Text(
                              '… e mais ${previa.length - 5} dias',
                              style: tema.bodySmall?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: DevocionalEspacamento.sp24),
                  DevocionalBotaoPrimario.icon(
                    onPressed: () => _controller.criar(context),
                    icon: const FaIcon(FontAwesomeIcons.check),
                    label: const Text('Criar plano'),
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

/// Seletor de livros com busca: a lista do canon com uma caixa de marcar
/// para cada livro, e dois atalhos antes dela para marcar o Antigo ou o Novo
/// Testamento inteiros de uma vez. Devolve os slugs escolhidos, ou nulo se
/// cancelado.
///
/// Quem já estava escolhido mantém a ordem que tinha (a ordem de leitura que
/// quem cria ajusta depois); livro novo entra no fim, em ordem canônica.
///
/// Dialog e não bottom sheet: são 66 livros, e a busca + a lista rolável
/// precisam da janela inteira no celular.
Future<List<String>?> mostrarSeletorDeLivros(
  BuildContext context, {
  required List<String> jaEscolhidos,
}) => showDialog<List<String>>(
  context: context,
  builder: (_) => _SeletorDeLivros(jaEscolhidos: jaEscolhidos),
);

/// O conteúdo do diálogo é um `StatefulWidget`, e não um `StatefulBuilder`
/// com um `TextEditingController` criado na função que abre o diálogo: um
/// controlador precisa de um dono com `dispose`, e o dono tem de ser o `State`
/// do conteúdo. Criado fora e descartado no `finally` do `Future`, ele morre
/// com a rota ainda na transição de saída, e o campo da rota morta ainda o
/// usa.
class _SeletorDeLivros extends StatefulWidget {
  const _SeletorDeLivros({required this.jaEscolhidos});

  final List<String> jaEscolhidos;

  @override
  State<_SeletorDeLivros> createState() => _SeletorDeLivrosState();
}

class _SeletorDeLivrosState extends State<_SeletorDeLivros> {
  static final _antigos = [
    for (final livro in canon)
      if (livro.testamento == Testamento.antigo) livro,
  ];
  static final _novos = [
    for (final livro in canon)
      if (livro.testamento == Testamento.novo) livro,
  ];

  final _busca = TextEditingController();
  final _selecionados = <String>{};

  @override
  void initState() {
    super.initState();
    _selecionados.addAll(widget.jaEscolhidos);
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  bool _todosMarcados(List<Livro> grupo) =>
      grupo.every((livro) => _selecionados.contains(livro.slug));
  bool _nenhumMarcado(List<Livro> grupo) =>
      grupo.every((livro) => !_selecionados.contains(livro.slug));

  Widget _atalhoDeTestamento(List<Livro> grupo, String nome) {
    return CheckboxListTile(
      dense: true,
      tristate: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(nome),
      subtitle: Text(
        '${grupo.length} ${grupo.length == 1 ? 'livro' : 'livros'}',
      ),
      value: _todosMarcados(grupo)
          ? true
          : _nenhumMarcado(grupo)
          ? false
          : null,
      onChanged: (_) => setState(() {
        final slugs = grupo.map((livro) => livro.slug).toList();
        if (_todosMarcados(grupo)) {
          _selecionados.removeAll(slugs);
        } else {
          _selecionados.addAll(slugs);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final termo = Conteudo.normalizar(_busca.text);
    final livros = [
      for (final livro in canon)
        if (termo.isEmpty || Conteudo.normalizar(livro.nome).contains(termo))
          livro,
    ];
    return AlertDialog(
      title: Text(
        'Escolher livros (${_selecionados.length} de ${canon.length})',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      content: SizedBox(
        width: larguraDeDialogo(context, 460),
        height: 480,
        child: Column(
          children: [
            DevocionalBusca(
              controller: _busca,
              // Mesmo padrão da aba de busca: no celular o teclado cobriria a
              // lista de 66 livros antes de qualquer intenção.
              autofocus: !kIsWeb,
              hintText: 'Buscar livro',
              onChanged: (_) => setState(() {}),
              border: const OutlineInputBorder(),
            ),
            const SizedBox(height: DevocionalEspacamento.sp12),
            _atalhoDeTestamento(_antigos, 'Antigo Testamento'),
            _atalhoDeTestamento(_novos, 'Novo Testamento'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DevocionalEspacamento.sp16,
              ),
              child: Text(
                'Caixa cheia marca o testamento inteiro. Traço quer dizer que só parte dele está marcada.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: livros.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Nenhum livro encontrado.'),
                          const SizedBox(height: DevocionalEspacamento.sp8),
                          DevocionalBotaoTerciario(
                            onPressed: () => setState(_busca.clear),
                            child: const Text('Limpar busca'),
                          ),
                        ],
                      ),
                    )
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
                          value: _selecionados.contains(livro.slug),
                          onChanged: (marcado) => setState(() {
                            if (marcado == true) {
                              _selecionados.add(livro.slug);
                            } else {
                              _selecionados.remove(livro.slug);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        DevocionalBotaoTerciario(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        DevocionalBotaoPrimario(
          // Sem livro não há plano: o botão só acende com 1+ marcado, em vez
          // de confirmar vazio e avisar depois.
          onPressed: _selecionados.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  // Mantém a ordem de leitura que já existia; o novo entra no
                  // fim, em ordem canônica.
                  for (final slug in widget.jaEscolhidos)
                    if (_selecionados.contains(slug)) slug,
                  for (final livro in canon)
                    if (_selecionados.contains(livro.slug) &&
                        !widget.jaEscolhidos.contains(livro.slug))
                      livro.slug,
                ]),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
