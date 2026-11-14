import 'package:material_ui/material_ui.dart';

import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/datas.dart';
import '../telas/busca.dart';
import '../telas/devocional.dart';

class DevocionalItemDeAchadoDevocional extends StatelessWidget {
  const DevocionalItemDeAchadoDevocional({
    super.key,
    required this.achado,
    required this.termo,
  });

  final AchadoDevocional achado;
  final String termo;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final leitura = Leitura.values.byName(achado.leitura);
    final data = _dataDoDevocional(achado.data);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TelaDevocional(dataInicial: data, leituraInicial: leitura),
        ),
      ),
      // 12 como no destaque de versículo: 8 está fora da escala do DESIGN.md.
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
              '${leitura.rotulo} · ${dataLonga(data)}',
              style: tema.titleSmall?.copyWith(color: cor.secondary),
            ),
            if (achado.titulo.isNotEmpty) ...[
              const SizedBox(height: DevocionalEspacamento.sp2),
              Text(
                achado.titulo,
                style: tema.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: cor.onSurfaceVariant,
                ),
              ),
            ],
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

/// Uma data qualquer, só para navegar até o dia certo do devocional: os
/// assets são anuais e a chave 'DD-MM' não guarda ano. 2024 é bissexto de
/// propósito — sem isso, '29-02' normalizaria sozinho para 1º de março (ver
/// `test/bissexto_test.dart`) e a busca levaria para o dia errado, calada.
DateTime _dataDoDevocional(String chave) {
  final partes = chave.split('-');
  return DateTime(2024, int.parse(partes[1]), int.parse(partes[0]));
}
