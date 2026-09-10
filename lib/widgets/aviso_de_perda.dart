import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/nuvem.dart';
import '../estilo/spacing.dart';

/// Faixa fixa, só na web: quem usa o app pelo navegador não tem como saber
/// que o localStorage pode ser limpo sem aviso (ver `_exportar` em notas.dart).
///
/// Logado, o risco de perder continua existindo — o navegador ainda pode
/// limpar — mas deixa de ser uma perda de verdade, porque agora tem de onde
/// voltar. Por isso só o texto muda com `Nuvem.instancia.logado`; o botão
/// "Exportar" fica, porque é a saída que não depende de conta nem de servidor.
class DevocionalAvisoDePerda extends StatelessWidget {
  const DevocionalAvisoDePerda({super.key, required this.onExportar});

  final VoidCallback onExportar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cor.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(DevocionalEspacamento.sp16, DevocionalEspacamento.sp10, DevocionalEspacamento.sp8, DevocionalEspacamento.sp10),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.circleInfo, color: cor.onSurfaceVariant, size: 20),
          const SizedBox(width: DevocionalEspacamento.sp12),
          Expanded(
            child: ListenableBuilder(
              listenable: Nuvem.instancia,
              builder: (context, _) => Text(
                Nuvem.instancia.logado
                    ? 'Suas notas também estão salvas na sua conta Google.'
                    : 'Na web, o navegador pode apagar suas notas sem aviso.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          TextButton(onPressed: onExportar, child: const Text('Exportar')),
        ],
      ),
    );
  }
}
