import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';
import 'cartao.dart';
import 'filete.dart';

/// O cartão da leitura de hoje enquanto o cronograma não chegou: carregando,
/// ou a falha. Mesmo filete e mesmo título do cartão pronto, para a Hoje não
/// pular de lugar quando ele entra.
class DevocionalCartaoLeituraProgressoAviso extends StatelessWidget {
  const DevocionalCartaoLeituraProgressoAviso({
    super.key,
    required this.mensagem,
  });

  /// "Carregando..." ou o motivo da falha.
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return DevocionalCartao(
      padding: const EdgeInsets.all(DevocionalEspacamento.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DevocionalFilete(),
          const SizedBox(height: DevocionalEspacamento.sp12),
          Text('Leitura de hoje', style: tema.titleLarge),
          const SizedBox(height: DevocionalEspacamento.sp8),
          Text(mensagem, style: tema.bodyMedium),
        ],
      ),
    );
  }
}
