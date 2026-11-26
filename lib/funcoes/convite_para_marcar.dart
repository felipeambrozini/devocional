import 'package:material_ui/material_ui.dart';

import '../dados/estado.dart';
import '../dados/nuvem.dart';
import 'alternar_lido.dart';
import 'aviso.dart';
import 'conta_acoes.dart';

/// O toque no círculo de marcar um dia do cronograma. Com conta, marca ou
/// desmarca como sempre ([alternarLidoComDesfazer]). Sem conta, o cronograma
/// continua à vista, mas marcar é pessoal: um aviso curto, como o de "Texto
/// copiado", convida a entrar e, se o login der certo, marca o dia, que era o
/// que a pessoa queria. Na restauração da sessão o toque não faz nada: ainda
/// não se sabe se há conta.
void alternarLidoOuConvidar(BuildContext context, Estado estado, String chave) {
  if (Nuvem.instancia.logado) {
    alternarLidoComDesfazer(context, estado, chave);
    return;
  }
  if (Nuvem.instancia.carregandoConta) return;
  avisarParaEntrar(
    context,
    'Entre para marcar a leitura',
    depoisDeEntrar: (contexto) {
      // O login pode ter trazido o dia como lido da nuvem: marcar de novo o
      // desmarcaria.
      if (estado.foiLido(chave)) return;
      alternarLidoComDesfazer(contexto, estado, chave);
    },
  );
}

/// Aviso sem conta com a ação "Entrar". O login usa o contexto do navegador
/// raiz, capturado agora: o aviso fica 8 s na tela e a pessoa pode ter saído
/// da leitura antes de tocar em "Entrar". [depoisDeEntrar] só roda se o
/// login completou.
void avisarParaEntrar(
  BuildContext context,
  String texto, {
  required void Function(BuildContext contexto) depoisDeEntrar,
}) {
  final raiz = Navigator.of(context, rootNavigator: true).context;
  // Com leitor de tela, a ação "Entrar" fica fora da ordem de foco: 8 s é
  // pouco para achá-la na barra do aviso.
  final duracao = MediaQuery.accessibleNavigationOf(context)
      ? const Duration(seconds: 30)
      : duracaoDeAvisoAutomatico;
  mostrarAviso(
    context,
    texto,
    rotuloDeAcao: 'Entrar',
    duracao: duracao,
    aoAgir: () async {
      // Direto do toque, sem espera antes: a janela do login na web só abre
      // dentro do gesto.
      await entrarNaConta(raiz, Nuvem.instancia);
      if (!Nuvem.instancia.logado || !raiz.mounted) return;
      depoisDeEntrar(raiz);
    },
  );
}
