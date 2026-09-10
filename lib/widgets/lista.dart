import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../estilo/spacing.dart';
import 'cartao_de_marcacao.dart';

class DevocionalLista extends StatelessWidget {
  const DevocionalLista({
    super.key,
    required this.itens,
    required this.vazio,
    this.mostrarNota = false,
  });

  final List<Marcacao> itens;
  final Widget vazio;
  final bool mostrarNota;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return vazio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(DevocionalEspacamento.sp16, DevocionalEspacamento.sp16, DevocionalEspacamento.sp16, DevocionalEspacamento.sp32),
      itemCount: itens.length,
      separatorBuilder: (_, _) => const SizedBox(height: DevocionalEspacamento.sp10),
      itemBuilder: (context, i) =>
          DevocionalCartaoDeMarcacao(marcacao: itens[i], mostrarNota: mostrarNota),
    );
  }
}
