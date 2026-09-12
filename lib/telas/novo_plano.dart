import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controladores/novo_plano_controlador.dart';
import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/planos.dart';
import '../estilo/espacamento.dart';
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
            if (termo.isEmpty ||
                Conteudo.normalizar(livro.nome).contains(termo))
              livro,
        ];
        return AlertDialog(
          title: Text(
            'Escolher livros',
            style: Theme.of(dialogContext).textTheme.headlineSmall,
          ),
          content: SizedBox(
            width: 460,
            height: 480,
            child: Column(
              children: [
                DevocionalBusca(
                  controller: busca,
                  // Mesmo padrão da aba de busca: no celular o teclado
                  // cobriria a lista de 66 livros antes de qualquer intenção.
                  autofocus: !kIsWeb,
                  hintText: 'Buscar livro',
                  onChanged: (_) => setDialogState(() {}),
                  border: const OutlineInputBorder(),
                ),
                const SizedBox(height: DevocionalEspacamento.sp12),
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
            DevocionalBotaoTerciario(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            DevocionalBotaoPrimario(
              onPressed: () =>
                  Navigator.pop(dialogContext, selecionados.toList()),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    ),
  );
}
