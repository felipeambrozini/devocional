import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import 'aviso_vazio.dart';
import 'cartao_de_referencia.dart';
import 'erro_de_busca.dart';
import 'item_de_achado.dart';

class DevocionalAbaBiblia extends StatelessWidget {
  const DevocionalAbaBiblia({
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
      return DevocionalErroDeBusca(aoTentarDeNovo: aoTentarDeNovo);
    }
    if (termoBuscado.isEmpty) {
      return const DevocionalAvisoVazio(
        icone: FontAwesomeIcons.magnifyingGlass,
        titulo: 'Busque um versículo',
        detalhe: 'A busca ignora acentos e maiúsculas.',
      );
    }
    if (achados.isEmpty && referencia == null && !buscando) {
      return DevocionalAvisoVazio(
        icone: FontAwesomeIcons.magnifyingGlassMinus,
        titulo: 'Nada encontrado',
        detalhe: 'Nenhum versículo com "$termoBuscado".',
      );
    }

    final temReferencia = referencia != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DevocionalEspacamento.sp16, 0, DevocionalEspacamento.sp16, DevocionalEspacamento.sp8),
          child: Row(
            children: [
              // A busca para no teto e a lista fica cortada. Dizer só "300
              // resultados" faria parecer que são exatamente 300 na Bíblia
              // inteira, quando na verdade a contagem parou ali.
              Expanded(
                child: Text(
                  achados.length >= Conteudo.limiteDeBusca
                      ? 'Primeiros ${Conteudo.limiteDeBusca} resultados; há mais'
                      : '${achados.length} ${achados.length == 1 ? 'resultado' : 'resultados'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: DevocionalEspacamento.sp10),
              if (buscando)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(DevocionalEspacamento.sp16, 0, DevocionalEspacamento.sp16, DevocionalEspacamento.sp32),
            itemCount: achados.length + (temReferencia ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: DevocionalEspacamento.sp18),
            itemBuilder: (context, i) {
              if (temReferencia && i == 0) {
                return DevocionalCartaoDeReferencia(referencia: referencia!);
              }
              final indice = temReferencia ? i - 1 : i;
              return DevocionalItemDeAchado(achado: achados[indice], termo: termoBuscado);
            },
          ),
        ),
      ],
    );
  }
}
