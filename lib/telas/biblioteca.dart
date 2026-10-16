import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/biblioteca.dart';
import '../dados/config_admin.dart';
import '../dados/estado.dart';
import '../dados/recursos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// A aba Biblioteca: a estante com os livros de Spurgeon que o app traz.
class TelaBiblioteca extends StatelessWidget {
  const TelaBiblioteca({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);

    return ListenableBuilder(
      listenable: ConfigAdmin.instancia,
      builder: (context, _) => Scaffold(
        appBar: DevocionalAppBar(
          title: const Text('Biblioteca'),
          actions: [DevocionalBotaoDeAjustes(estado: estado)],
        ),
        body: !Recursos.biblioteca
            ? const DevocionalAvisoVazio(
                icone: FontAwesomeIcons.bookBookmark,
                titulo: 'Biblioteca desativada',
                detalhe: 'A Biblioteca está desativada temporariamente.',
              )
            : DevocionalLarguraDeLeitura(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    DevocionalEspacamento.sp16,
                    DevocionalEspacamento.sp8,
                    DevocionalEspacamento.sp16,
                    DevocionalEspacamento.sp32,
                  ),
                  itemCount: obrasDaBiblioteca.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: DevocionalEspacamento.sp12),
                  itemBuilder: (context, indice) {
                    final obra = obrasDaBiblioteca[indice];
                    return DevocionalCartaoDaObra(
                      obra: obra,
                      aoAbrir: () => context.push('/biblioteca/${obra.slug}'),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
