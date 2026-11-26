import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';

/// A espera da conta numa tela que depende dela (perfil, notas, cronograma):
/// enquanto a sessão pode estar restaurando, o convite de entrar piscaria para
/// quem já está logado, e uma tela em branco parece travada. Estática, sem
/// animação, pelo mesmo motivo de `TabernaculoBotaoDeConta`: a restauração
/// leva 20-30s no Android.
class TabernaculoVerificandoConta extends StatelessWidget {
  const TabernaculoVerificandoConta({super.key});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(TabernaculoEspacamento.sp20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: FaIcon(
                  FontAwesomeIcons.hourglassStart,
                  size: 16,
                  color: cor.primary,
                ),
              ),
              const SizedBox(width: TabernaculoEspacamento.sp10),
              Flexible(
                child: Text(
                  'Verificando sua conta',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
