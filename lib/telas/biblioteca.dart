import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../dados/biblioteca.dart';
import '../dados/estado.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// A estante: os livros de Spurgeon que o app traz.
class TelaBiblioteca extends StatelessWidget {
  const TelaBiblioteca({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);

    return Scaffold(
      appBar: DevocionalAppBar(
        title: const Text('Biblioteca'),
        actions: [DevocionalBotaoDeAjustes(estado: estado)],
      ),
      body: DevocionalLarguraDeLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DevocionalEspacamento.sp16,
            DevocionalEspacamento.sp8,
            DevocionalEspacamento.sp16,
            DevocionalEspacamento.sp32,
          ),
          children: [
            for (final obra in obrasDaBiblioteca)
              DevocionalCartaoDaObra(
                obra: obra,
                aoAbrir: () => context.push('/biblioteca/${obra.slug}'),
              ),
          ],
        ),
      ),
    );
  }
}
