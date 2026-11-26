import 'package:material_ui/material_ui.dart';

import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../estilo/espacamento.dart';
import '../widgets/botao_de_entrar.dart';
import '../widgets/layout_leitura.dart';
import 'alternar_lido.dart';

/// O toque no círculo de marcar um dia do cronograma. Com conta, marca ou
/// desmarca como sempre ([alternarLidoComDesfazer]). Sem conta, o cronograma
/// continua à vista, mas marcar é pessoal: abre o convite para entrar e, se o
/// login der certo, marca o dia, que era o que a pessoa queria. Na
/// restauração da sessão o toque não faz nada: ainda não se sabe se há conta.
Future<void> alternarLidoOuConvidar(
  BuildContext context,
  Estado estado,
  String chave,
) async {
  if (Nuvem.instancia.logado) {
    alternarLidoComDesfazer(context, estado, chave);
    return;
  }
  if (Nuvem.instancia.carregandoConta) return;
  final entrou = await convidarParaMarcar(context);
  // O login pode ter trazido o dia como lido da nuvem: marcar de novo o
  // desmarcaria.
  if (!entrou || !context.mounted || estado.foiLido(chave)) return;
  alternarLidoComDesfazer(context, estado, chave);
}

/// Abre a folha que convida a entrar para marcar a leitura. Devolve `true` se
/// a pessoa entrou por ela, e `false` se fechou a folha ou o login não
/// completou.
Future<bool> convidarParaMarcar(BuildContext context) async {
  final entrou = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const TabernaculoConviteParaMarcar(),
  );
  return entrou ?? false;
}

/// O conteúdo da folha de [convidarParaMarcar]: o motivo e o botão de entrar.
/// Fecha sozinha, devolvendo `true`, quando o login completa.
class TabernaculoConviteParaMarcar extends StatelessWidget {
  const TabernaculoConviteParaMarcar({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TabernaculoEspacamento.sp20,
          0,
          TabernaculoEspacamento.sp20,
          TabernaculoEspacamento.sp20,
        ),
        child: TabernaculoLarguraDeLeitura(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(
                  'Entre para marcar a leitura',
                  style: tema.titleLarge,
                ),
              ),
              const SizedBox(height: TabernaculoEspacamento.sp8),
              Text(
                'Os dias lidos ficam guardados na sua conta Google.',
                style: tema.bodyMedium,
              ),
              const SizedBox(height: TabernaculoEspacamento.sp16),
              TabernaculoBotaoDeEntrar(
                aoEntrar: () {
                  if (!context.mounted || !Nuvem.instancia.logado) return;
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
