import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/abrir_na_biblia.dart';
import 'aviso_vazio.dart';
import 'cartao_de_referencia.dart';
import 'item_de_achado.dart';

class TabernaculoAbaBiblia extends StatelessWidget {
  const TabernaculoAbaBiblia({
    super.key,
    required this.termoBuscado,
    required this.referencia,
    required this.achados,
    required this.buscando,
    required this.erro,
    required this.aoTentarDeNovo,
  });

  final String termoBuscado;
  final (Livro, int, int, int)? referencia;
  final List<Achado> achados;
  final bool buscando;
  final bool erro;
  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    if (erro) {
      return TabernaculoAvisoDeErro(
        detalhe: 'A busca falhou. Tente de novo.',
        aoTentarDeNovo: aoTentarDeNovo,
      );
    }
    if (termoBuscado.isEmpty) {
      return const TabernaculoAvisoVazio(
        icone: FontAwesomeIcons.magnifyingGlass,
        titulo: 'Busque um versículo',
        detalhe: 'A busca ignora acentos e maiúsculas',
      );
    }
    if (achados.isEmpty && referencia == null && !buscando) {
      return TabernaculoAvisoVazio(
        icone: FontAwesomeIcons.magnifyingGlassMinus,
        titulo: 'Nada encontrado',
        detalhe: 'Nenhum versículo com "$termoBuscado"',
      );
    }

    final temReferencia = referencia != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TabernaculoEspacamento.sp16,
            0,
            TabernaculoEspacamento.sp16,
            TabernaculoEspacamento.sp8,
          ),
          child: Row(
            children: [
              // A busca para no teto e a lista fica cortada. Dizer só "300
              // resultados" faria parecer que são exatamente 300 na Bíblia
              // inteira, quando na verdade a contagem parou ali.
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    achados.length >= Conteudo.limiteDeBusca
                        ? 'Primeiros ${Conteudo.limiteDeBusca} resultados; há mais'
                        : '${achados.length} ${achados.length == 1 ? 'resultado' : 'resultados'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              const SizedBox(width: TabernaculoEspacamento.sp10),
              if (buscando)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Carregando',
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              TabernaculoEspacamento.sp16,
              0,
              TabernaculoEspacamento.sp16,
              TabernaculoEspacamento.sp32,
            ),
            itemCount: achados.length + (temReferencia ? 1 : 0),
            separatorBuilder: (_, _) =>
                const Divider(height: TabernaculoEspacamento.sp18),
            itemBuilder: (context, i) {
              if (temReferencia && i == 0) {
                return TabernaculoCartaoDeReferencia(referencia: referencia!);
              }
              final achado = achados[temReferencia ? i - 1 : i];
              return TabernaculoItemDeAchado(
                titulo: achado.referencia,
                texto: achado.texto,
                termo: termoBuscado,
                aoAbrir: () => abrirNaBiblia(
                  context,
                  achado.livro,
                  achado.capitulo,
                  destacar: (achado.versiculo, achado.versiculo),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
