import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../estilo/espacamento.dart';
import '../funcoes/dialogos.dart';
import 'botao.dart';
import 'busca.dart';

/// O conteúdo do diálogo é um `StatefulWidget`, e não um `StatefulBuilder`
/// com um `TextEditingController` criado na função que abre o diálogo: um
/// controlador precisa de um dono com `dispose`, e o dono tem de ser o `State`
/// do conteúdo. Criado fora e descartado no `finally` do `Future`, ele morre
/// com a rota ainda na transição de saída, e o campo da rota morta ainda o
/// usa.
class DevocionalSeletorDeLivrosDoPlano extends StatefulWidget {
  const DevocionalSeletorDeLivrosDoPlano({
    super.key,
    required this.jaEscolhidos,
  });

  final List<String> jaEscolhidos;

  @override
  State<DevocionalSeletorDeLivrosDoPlano> createState() =>
      _DevocionalSeletorDeLivrosDoPlanoState();
}

class _DevocionalSeletorDeLivrosDoPlanoState
    extends State<DevocionalSeletorDeLivrosDoPlano> {
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
        height: alturaDeDialogo(context, 480),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
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
                ],
              ),
            ),
            if (livros.isEmpty)
              SliverToBoxAdapter(
                child: Center(
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
                ),
              )
            else
              SliverList.builder(
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
