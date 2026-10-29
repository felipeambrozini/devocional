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
        DevocionalCartaoDaObra(obra: obra, aoAbrir: null),
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

    // O número some quando lido e o ícone sozinho não diz qual capítulo é:
    // o rótulo único carrega número, título e estado.
    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: aoAbrir,
      label:
          'Capítulo $numero, $titulo'
          '${lido ? ', lido' : ''}'
          '${parouAqui ? ', parei aqui' : ''}',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: aoAbrir,
        // Largura mínima, não fixa: "Tesouro de Davi" tem 149 capítulos, e um
        // número de três dígitos (ou a escala de texto aumentada) precisa caber
        // sem cortar. O centro com widthFactor deixa o alvo crescer pelo conteúdo.
        leading: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: Center(
            widthFactor: 1,
            child: lido
                ? FaIcon(
                    FontAwesomeIcons.circleCheck,
                    size: 18,
                    color: cor.secondary,
                  )
                : Text(
                    '$numero',
                    textAlign: TextAlign.center,
                    style: tema.labelLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ),
        title: Text(titulo, style: tema.bodyLarge),
        trailing: parouAqui
            ? Text('Parei aqui', style: tema.labelMedium)
            : null,
      ),
    );
  }
}
