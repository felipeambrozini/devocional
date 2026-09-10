import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'aviso_vazio.dart';

/// Falha de busca com a recuperação à mão: um erro de stream ou de leitura
/// de asset costuma ser momentâneo, e o "Tentar de novo" refaz a última
/// busca sem digitar nada de novo.
class DevocionalErroDeBusca extends StatelessWidget {
  const DevocionalErroDeBusca({super.key, required this.aoTentarDeNovo});

  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) => DevocionalAvisoVazio(
    icone: FontAwesomeIcons.triangleExclamation,
    titulo: 'Não foi possível carregar',
    detalhe: 'A busca falhou. Tente de novo.',
    acao: TextButton(
      onPressed: aoTentarDeNovo,
      child: const Text('Tentar de novo'),
    ),
  );
}
