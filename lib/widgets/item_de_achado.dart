import 'package:material_ui/material_ui.dart';

import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/abrir_na_biblia.dart';
import '../telas/busca.dart';

class DevocionalItemDeAchado extends StatelessWidget {
  const DevocionalItemDeAchado({
    super.key,
    required this.achado,
    required this.termo,
  });

  final Achado achado;
  final String termo;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => abrirNaBiblia(
        context,
        achado.livro,
        achado.capitulo,
        destacar: (achado.versiculo, achado.versiculo),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: DevocionalEspacamento.sp4,
          horizontal: DevocionalEspacamento.sp4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              achado.referencia,
              style: tema.titleSmall?.copyWith(color: cor.secondary),
            ),
            const SizedBox(height: DevocionalEspacamento.sp5),
            Text.rich(
              destacar(achado.texto, termo, tema, cor),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
