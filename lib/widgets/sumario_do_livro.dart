import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import 'botao.dart';
import 'cartao_da_obra.dart';
import 'linha_do_capitulo.dart';

/// O corpo do sumário de um livro: o cartão da obra, o botão de começar ou
/// continuar a leitura e a lista de capítulos.
class DevocionalSumarioDoLivro extends StatelessWidget {
  const DevocionalSumarioDoLivro({
    super.key,
    required this.obra,
    required this.capitulos,
  });

  final ObraDaBiblioteca obra;
  final List<CapituloDoLivro> capitulos;

  @override
  Widget build(BuildContext context) {
    final leitura = EscopoDoEstado.de(context).leituraDeLivros;
    final posicao = leitura.posicaoDe(obra.slug);
    final capituloAtual = (posicao?.capitulo ?? 0).clamp(
      0,
      capitulos.length - 1,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp8,
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp32,
      ),
      children: [
        DevocionalCartaoDaObra(obra: obra, aoAbrir: null),
        const SizedBox(height: DevocionalEspacamento.sp16),
        Align(
          alignment: Alignment.centerLeft,
          child: DevocionalBotaoPrimario.icon(
            onPressed: () =>
                context.push('/biblioteca/${obra.slug}/${capituloAtual + 1}'),
            icon: const FaIcon(FontAwesomeIcons.bookOpenReader, size: 16),
            label: Text(
              posicao == null ? 'Começar a ler' : 'Continuar de onde parei',
            ),
          ),
        ),
        const SizedBox(height: DevocionalEspacamento.sp20),
        for (final (indice, capitulo) in capitulos.indexed)
          DevocionalLinhaDoCapitulo(
            numero: indice + 1,
            titulo: capitulo.titulo,
            lido: leitura.foiLido(obra.slug, indice),
            parouAqui: posicao?.capitulo == indice,
            aoAbrir: () =>
                context.push('/biblioteca/${obra.slug}/${indice + 1}'),
          ),
      ],
    );
  }
}
