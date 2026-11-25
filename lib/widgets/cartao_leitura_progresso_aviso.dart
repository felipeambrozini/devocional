import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';
import 'cartao.dart';
import 'filete.dart';

/// O cartão da leitura de hoje enquanto o cronograma não chegou: carregando,
/// ou a falha. Mesmo filete e mesmo título do cartão pronto, para a Hoje não
/// pular de lugar quando ele entra.
class TabernaculoCartaoLeituraProgressoAviso extends StatelessWidget {
  const TabernaculoCartaoLeituraProgressoAviso({
    super.key,
    required this.mensagem,
  });

  /// "Carregando..." ou o motivo da falha.
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return TabernaculoCartao(
      padding: const EdgeInsets.all(TabernaculoEspacamento.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabernaculoFilete(),
          const SizedBox(height: TabernaculoEspacamento.sp12),
          Text('Leitura de hoje', style: tema.titleLarge),
          const SizedBox(height: TabernaculoEspacamento.sp8),
          Text(mensagem, style: tema.bodyMedium),
        ],
      ),
    );
  }
}
