import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/audio_offline.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/nuvem.dart';
import '../estilo/espacamento.dart';
import '../funcoes/terminar_leitura.dart';
import 'baixar_livro.dart';
import 'botao.dart';
import 'cartao_da_obra.dart';
import 'linha_do_capitulo.dart';

/// O corpo do sumário de um livro: o cartão da obra, o botão de começar ou
/// continuar a leitura e a lista de capítulos.
class TabernaculoSumarioDoLivro extends StatelessWidget {
  const TabernaculoSumarioDoLivro({
    super.key,
    required this.obra,
    required this.capitulos,
  });

  final ObraDaBiblioteca obra;
  final List<CapituloDoLivro> capitulos;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Nuvem.instancia,
      builder: (context, _) => _corpo(context),
    );
  }

  Widget _corpo(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    final leitura = estado.leituraDeLivros;
    // O progresso só existe com conta: sem ela, o livro abre sempre no começo
    // e nada do que ficou gravado antes aparece.
    final logado = Nuvem.instancia.logado;
    final posicao = logado ? leitura.posicaoDe(obra.slug) : null;
    final capituloAtual = (posicao?.capitulo ?? 0).clamp(
      0,
      capitulos.length - 1,
    );
    final emLeitura =
        posicao != null || (logado && leitura.quantosLidos(obra.slug) > 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TabernaculoEspacamento.sp16,
        TabernaculoEspacamento.sp8,
        TabernaculoEspacamento.sp16,
        TabernaculoEspacamento.sp32,
      ),
      children: [
        TabernaculoCartaoDaObra(obra: obra, aoAbrir: null),
        const SizedBox(height: TabernaculoEspacamento.sp16),
        // Wrap: em tela estreita ou letra grande, os dois botões descem um
        // para cada linha em vez de estourar.
        Wrap(
          spacing: TabernaculoEspacamento.sp8,
          runSpacing: TabernaculoEspacamento.sp8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TabernaculoBotaoPrimario.icon(
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
              TabernaculoBotaoTerciario.icon(
                onPressed: () => terminarLeituraDoLivro(context, estado, obra),
                icon: const FaIcon(FontAwesomeIcons.flagCheckered, size: 16),
                label: const Text('Terminar a leitura'),
              ),
          ],
        ),
        // Só aparece quando o áudio do livro já está no Storage.
        TabernaculoBaixarLivro(
          livro: LivroParaBaixar.daBiblioteca(obra, capitulos.length),
        ),
        const SizedBox(height: TabernaculoEspacamento.sp20),
        for (final (indice, capitulo) in capitulos.indexed)
          TabernaculoLinhaDoCapitulo(
            numero: indice + 1,
            titulo: capitulo.titulo,
            lido: logado && leitura.foiLido(obra.slug, indice),
            parouAqui: posicao?.capitulo == indice,
            aoAbrir: () =>
                context.push('/biblioteca/${obra.slug}/${indice + 1}'),
          ),
      ],
    );
  }
}
