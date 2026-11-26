import 'package:material_ui/material_ui.dart';

import '../widgets/widgets.dart';

/// O cronograma de um ano que passou, aberto pelo perfil: o mesmo calendário
/// da aba do cronograma, só para consulta. Os dias lidos aparecem marcados e
/// nenhum toque muda nada; abrir a leitura de um dia para ler continua
/// valendo.
class TelaCronogramaDoAno extends StatelessWidget {
  const TelaCronogramaDoAno({super.key, required this.ano});

  final int ano;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TabernaculoAppBar(title: Text('Cronograma de $ano')),
      body: TabernaculoAbaDoCronograma(
        hoje: null,
        ano: ano,
        somenteLeitura: true,
      ),
    );
  }
}
