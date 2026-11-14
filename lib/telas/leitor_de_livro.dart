import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/biblioteca.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../widgets/widgets.dart';

/// Um capítulo de um livro da biblioteca. [capitulo] vem da URL, a partir de 1.
class TelaLeitorDeLivro extends StatefulWidget {
  const TelaLeitorDeLivro({
    super.key,
    required this.slug,
    required this.capitulo,
  });

  final String slug;
  final int capitulo;

  @override
  State<TelaLeitorDeLivro> createState() => _TelaLeitorDeLivroState();
}

class _TelaLeitorDeLivroState extends State<TelaLeitorDeLivro> {
  /// A chave do carregamento muda a cada "Tentar de novo" para o
  /// [DevocionalCarregaUmaVez] refazer o future em vez de reusar a falha.
  var _tentativa = 0;

  void _tentarDeNovo() {
    Biblioteca.instancia.esquecer(widget.slug);
    setState(() => _tentativa++);
  }

  @override
  Widget build(BuildContext context) {
    final obra = obraPorSlug(widget.slug);
    final estado = EscopoDoEstado.de(context);

    Widget aviso(String titulo, [Widget? corpo]) => Scaffold(
      appBar: DevocionalAppBar(
        title: Text(obra?.titulo ?? 'Biblioteca'),
        actions: [DevocionalBotaoDeAjustes(estado: estado)],
      ),
      body:
          corpo ??
          DevocionalAvisoVazio(icone: FontAwesomeIcons.book, titulo: titulo),
    );

    if (obra == null) return aviso('Livro não encontrado');

    return DevocionalCarregaUmaVez<List<CapituloDoLivro>?>(
      chave: '${widget.slug}/$_tentativa',
      carregar: () => Biblioteca.instancia.capitulos(widget.slug),
      construir: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return aviso(
            '',
            const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Carregando'),
            ),
          );
        }
        final capitulos = snap.data;
        if (capitulos == null || capitulos.isEmpty) {
          return aviso(
            '',
            DevocionalAvisoDeErro(aoTentarDeNovo: _tentarDeNovo),
          );
        }
        final indice = widget.capitulo - 1;
        if (indice < 0 || indice >= capitulos.length) {
          return aviso('Capítulo não encontrado');
        }
        // A chave leva o capítulo junto: o go_router pode reaproveitar a
        // página ao trocar só o parâmetro, e a rolagem do capítulo anterior
        // não pode sobrar no próximo.
        return DevocionalCapituloAberto(
          key: ValueKey('${widget.slug}/$indice'),
          estado: estado,
          obra: obra,
          capitulos: capitulos,
          indice: indice,
        );
      },
    );
  }
}
