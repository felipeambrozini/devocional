import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../controladores/notas_controlador.dart';
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
        appBar: TabernaculoAppBar(
          title: const Text('Biblioteca'),
          actions: [
            const TabernaculoBotaoDeNotas(origem: OrigemDasNotas.biblioteca),
            TabernaculoBotaoDeAjustes(estado: estado),
          ],
        ),
        body: !Recursos.biblioteca
            ? const TabernaculoAvisoVazio(
                icone: FontAwesomeIcons.bookBookmark,
                titulo: 'Biblioteca desativada',
                detalhe: 'A Biblioteca está desativada temporariamente',
              )
            : TabernaculoLarguraDeLeitura(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    TabernaculoEspacamento.sp16,
                    TabernaculoEspacamento.sp8,
                    TabernaculoEspacamento.sp16,
                    TabernaculoEspacamento.sp32,
                  ),
                  itemCount: obrasDaBiblioteca.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: TabernaculoEspacamento.sp12),
                  itemBuilder: (context, indice) {
                    final obra = obrasDaBiblioteca[indice];
                    return TabernaculoCartaoDaObra(
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
