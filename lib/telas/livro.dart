import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/biblioteca.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../widgets/widgets.dart';

/// O sumário de um livro: os capítulos, o que já foi lido e o botão de
/// continuar de onde parou.
class TelaDoLivro extends StatefulWidget {
  const TelaDoLivro({super.key, required this.slug});

  final String slug;

  @override
  State<TelaDoLivro> createState() => _TelaDoLivroState();
}

class _TelaDoLivroState extends State<TelaDoLivro> {
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

    return Scaffold(
      appBar: DevocionalAppBar(
        title: Text(
          obra?.titulo ?? 'Biblioteca',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [DevocionalBotaoDeAjustes(estado: estado)],
      ),
      body: obra == null
          ? const DevocionalAvisoVazio(
              icone: FontAwesomeIcons.book,
              titulo: 'Livro não encontrado',
              detalhe: 'Este livro não está na biblioteca.',
            )
          : DevocionalLarguraDeLeitura(
              child: DevocionalCarregaUmaVez<List<CapituloDoLivro>?>(
                chave: '${widget.slug}/$_tentativa',
                carregar: () => Biblioteca.instancia.capitulos(widget.slug),
                construir: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Carregando',
                      ),
                    );
                  }
                  final capitulos = snap.data;
                  if (capitulos == null || capitulos.isEmpty) {
                    return DevocionalAvisoDeErro(aoTentarDeNovo: _tentarDeNovo);
                  }
                  return DevocionalSumarioDoLivro(
                    obra: obra,
                    capitulos: capitulos,
                  );
                },
              ),
            ),
    );
  }
}
