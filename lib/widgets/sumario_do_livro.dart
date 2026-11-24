import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/audio_offline.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/terminar_leitura.dart';
import 'baixar_livro.dart';
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
    final estado = EscopoDoEstado.de(context);
    final leitura = estado.leituraDeLivros;
    final posicao = leitura.posicaoDe(obra.slug);
    final capituloAtual = (posicao?.capitulo ?? 0).clamp(
      0,
      capitulos.length - 1,
    );
    final emLeitura = posicao != null || leitura.quantosLidos(obra.slug) > 0;

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
        // Wrap: em tela estreita ou letra grande, os dois botões descem um
        // para cada linha em vez de estourar.
        Wrap(
          spacing: DevocionalEspacamento.sp8,
          runSpacing: DevocionalEspacamento.sp8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DevocionalBotaoPrimario.icon(
              onPressed: () =>
                  context.push('/biblioteca/${obra.slug}/${capituloAtual + 1}'),
              icon: const FaIcon(FontAwesomeIcons.bookOpenReader, size: 16),
              label: Text(
                posicao == null ? 'Começar a ler' : 'Continuar de onde parei',
              ),
            ),
            // Terminar sem precisar chegar ao último capítulo: quem já leu o
            // livro em outro lugar, ou quer recomeçar. O mesmo fluxo do botão
            // do último capítulo, com a mesma confirmação.
            if (emLeitura)
              DevocionalBotaoTerciario.icon(
                onPressed: () => terminarLeituraDoLivro(context, estado, obra),
                icon: const FaIcon(FontAwesomeIcons.flagCheckered, size: 16),
                label: const Text('Terminar a leitura'),
              ),
          ],
        ),
        // Só aparece quando o áudio do livro já está no Storage.
        DevocionalBaixarLivro(
          livro: LivroParaBaixar.daBiblioteca(obra, capitulos.length),
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
