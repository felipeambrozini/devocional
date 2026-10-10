import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/capa_biblia.dart';
import 'cartao_da_obra.dart';

/// Os livros que o usuário está lendo, para a Hoje. Nenhum livro iniciado: não
/// mostra nada. Um só: o cartão do livro. Mais de um: uma lista horizontal com
/// todos, do mais recente ao mais antigo.
class DevocionalLivrosEmLeitura extends StatelessWidget {
  const DevocionalLivrosEmLeitura({
    super.key,
    required this.obras,
    required this.aoAbrir,
  });

  final List<ObraDaBiblioteca> obras;
  final void Function(ObraDaBiblioteca obra) aoAbrir;

  /// Largura de cada cartão na lista horizontal: deixa o próximo aparecer um
  /// pouco na borda, o que mostra que a lista rola.
  static const _larguraDoCartao = 290.0;

  @override
  Widget build(BuildContext context) {
    if (obras.isEmpty) return const SizedBox.shrink();
    if (obras.length == 1) {
      final obra = obras.first;
      return DevocionalCartaoDaObra(obra: obra, aoAbrir: () => aoAbrir(obra));
    }

    final altura =
        alturaCapa(context, 104) + 2 * DevocionalEspacamento.sp16 + 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seus livros', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: DevocionalEspacamento.sp8),
        SizedBox(
          height: altura,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: obras.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: DevocionalEspacamento.sp8),
            itemBuilder: (context, indice) => SizedBox(
              width: _larguraDoCartao,
              child: DevocionalCartaoDaObra(
                obra: obras[indice],
                aoAbrir: () => aoAbrir(obras[indice]),
                compacto: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
