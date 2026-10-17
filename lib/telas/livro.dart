import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/biblioteca.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// O sumário de um livro: os capítulos, o que já foi lido e o botão de
/// continuar de onde parou.
class TelaDoLivro extends StatelessWidget {
  const TelaDoLivro({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final obra = obraPorSlug(slug);
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
                chave: slug,
                carregar: () => Biblioteca.instancia.capitulos(slug),
                construir: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final capitulos = snap.data;
                  if (capitulos == null || capitulos.isEmpty) {
                    return const DevocionalAvisoDeErro();
                  }
                  return _Sumario(obra: obra, capitulos: capitulos);
                },
              ),
            ),
    );
  }
}

class _Sumario extends StatelessWidget {
  const _Sumario({required this.obra, required this.capitulos});

  final ObraDaBiblioteca obra;
  final List<CapituloDoLivro> capitulos;

  @override
  Widget build(BuildContext context) {
    final leitura = EscopoDoEstado.de(context).leituraDeLivros;
    final posicao = leitura.posicaoDe(obra.slug);
    final capituloAtual = (posicao?.capitulo ?? 0).clamp(
      0,
      capitulos.length - 1,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp8,
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp32,
      ),
      children: [
        DevocionalCartaoDaObra(
          obra: obra,
          aoAbrir: () =>
              context.push('/biblioteca/${obra.slug}/${capituloAtual + 1}'),
        ),
        const SizedBox(height: DevocionalEspacamento.sp16),
        Align(
          alignment: Alignment.centerLeft,
          child: DevocionalBotaoPrimario.icon(
            onPressed: () =>
                context.push('/biblioteca/${obra.slug}/${capituloAtual + 1}'),
            icon: const FaIcon(FontAwesomeIcons.bookOpenReader, size: 16),
            label: Text(
              posicao == null ? 'Começar a ler' : 'Continuar de onde parei',
            ),
          ),
        ),
        const SizedBox(height: DevocionalEspacamento.sp20),
        for (final (indice, capitulo) in capitulos.indexed)
          _LinhaDoCapitulo(
            numero: indice + 1,
            titulo: capitulo.titulo,
            lido: leitura.foiLido(obra.slug, indice),
            parouAqui: posicao?.capitulo == indice,
            aoAbrir: () =>
                context.push('/biblioteca/${obra.slug}/${indice + 1}'),
          ),
      ],
    );
  }
}

class _LinhaDoCapitulo extends StatelessWidget {
  const _LinhaDoCapitulo({
    required this.numero,
    required this.titulo,
    required this.lido,
    required this.parouAqui,
    required this.aoAbrir,
  });

  final int numero;
  final String titulo;
  final bool lido;
  final bool parouAqui;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: aoAbrir,
      leading: SizedBox(
        width: 28,
        child: Center(
          child: lido
              ? FaIcon(
                  FontAwesomeIcons.circleCheck,
                  size: 18,
                  color: cor.secondary,
                )
              : Text('$numero', style: tema.labelLarge),
        ),
      ),
      title: Text(titulo, style: tema.bodyLarge),
      trailing: parouAqui ? Text('Parei aqui', style: tema.labelMedium) : null,
    );
  }
}
