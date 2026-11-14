import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Uma linha do sumário de um livro: o número (ou o visto de lido), o título
/// do capítulo e a marca de onde a leitura parou.
class DevocionalLinhaDoCapitulo extends StatelessWidget {
  const DevocionalLinhaDoCapitulo({
    super.key,
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
