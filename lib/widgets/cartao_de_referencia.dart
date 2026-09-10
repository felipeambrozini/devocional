import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../estilo/spacing.dart';
import '../telas/biblia.dart';

/// Card fixo no topo dos resultados quando o próprio termo digitado é uma
/// referência bíblica reconhecida, para ir direto ao versículo em vez de
/// depender da busca de texto — que nunca acharia isso, já que o corpo do
/// versículo não contém a própria referência.
class DevocionalCartaoDeReferencia extends StatelessWidget {
  const DevocionalCartaoDeReferencia({super.key, required this.referencia});

  final (Livro, int, int, int) referencia;

  @override
  Widget build(BuildContext context) {
    final (livro, capitulo, deVersiculo, ateVersiculo) = referencia;
    final cor = Theme.of(context).colorScheme;
    final rotulo = deVersiculo == ateVersiculo
        ? '${livro.nome} $capitulo:$deVersiculo'
        : '${livro.nome} $capitulo:$deVersiculo-$ateVersiculo';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaBiblia(
            livroInicial: livro.slug,
            capituloInicial: capitulo,
            destacar: (deVersiculo, ateVersiculo),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DevocionalEspacamento.sp10, horizontal: DevocionalEspacamento.sp4),
        child: Row(
          children: [
            FaIcon(FontAwesomeIcons.arrowRight, size: 18, color: cor.primary),
            const SizedBox(width: DevocionalEspacamento.sp10),
            Text(
              'Ir para $rotulo',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cor.primary),
            ),
          ],
        ),
      ),
    );
  }
}
