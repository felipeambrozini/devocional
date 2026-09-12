import 'package:flutter/material.dart';

import '../dados/estado.dart';
import '../widgets/widgets.dart';

/// Cronograma anual agrupado por mês, com marcação de lido — e, na aba Meus
/// Planos, os planos de leitura que o usuário cria, compartilha e acompanha.
///
/// As duas abas ficam sempre visíveis: a aba Meus Planos explica o que falta
/// (conta ou o recurso premium) em vez de sumir em silêncio quando não se
/// aplica — ver `DevocionalAbaDosMeusPlanos`.
class TelaPlano extends StatefulWidget {
  const TelaPlano({super.key, this.hoje});

  /// Só o teste passa data: é o que permite verificar o cronograma bissexto sem
  /// esperar 2028. Em produção fica nulo e vale o relógio.
  final DateTime? hoje;

  @override
  State<TelaPlano> createState() => _TelaPlanoState();
}

class _TelaPlanoState extends State<TelaPlano> {
  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);

    return DevocionalAbasDoPlano(
      hoje: widget.hoje,
      acaoDeAjustes: DevocionalBotaoDeAjustes(estado: estado),
    );
  }
}