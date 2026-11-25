import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../estilo/espacamento.dart';
import '../estilo/toque.dart';
import '../funcoes/abrir_na_biblia.dart';

/// Card fixo no topo dos resultados quando o próprio termo digitado é uma
/// referência bíblica reconhecida, para ir direto ao versículo em vez de
/// depender da busca de texto — que nunca acharia isso, já que o corpo do
/// versículo não contém a própria referência.
class TabernaculoCartaoDeReferencia extends StatelessWidget {
  const TabernaculoCartaoDeReferencia({super.key, required this.referencia});

  final (Livro, int, int, int) referencia;

  @override
  Widget build(BuildContext context) {
    final (livro, capitulo, deVersiculo, ateVersiculo) = referencia;
    final cor = Theme.of(context).colorScheme;
    final rotulo =
        '${nomeNaReferencia(livro.slug)} $capitulo:'
        '${intervaloDeNumeros(deVersiculo, ateVersiculo)}';

    return InkWell(
      onTap: () => abrirNaBiblia(
        context,
        livro.slug,
        capitulo,
        destacar: (deVersiculo, ateVersiculo),
      ),
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: TabernaculoToque.minimo),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: TabernaculoEspacamento.sp10,
            horizontal: TabernaculoEspacamento.sp4,
          ),
          child: Row(
            children: [
              FaIcon(FontAwesomeIcons.arrowRight, size: 18, color: cor.primary),
              const SizedBox(width: TabernaculoEspacamento.sp10),
              Text(
                'Ir para $rotulo',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: cor.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
