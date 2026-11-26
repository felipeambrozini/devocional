import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'botao.dart';

/// Pedido de consentimento para guardar os dados da conta na nuvem. A LGPD
/// trata favoritos, anotações e conversas de um app devocional como dado
/// sensível (convicção religiosa) e pede consentimento específico e em
/// destaque, não só uma linha perdida na política.
///
/// [aoConcordar] roda dentro do próprio toque do botão, sem `await` antes: na
/// web é ele que abre a janela de login do Google, e o navegador só a deixa
/// abrir dentro do gesto do usuário (ver `entrarNaConta`).
class TabernaculoConsentimentoDaNuvem extends StatelessWidget {
  const TabernaculoConsentimentoDaNuvem({
    super.key,
    required this.rotuloDeConcordar,
    required this.rotuloDeRecusar,
    required this.aoConcordar,
    this.aoRecusar,
  });

  final String rotuloDeConcordar;
  final String rotuloDeRecusar;
  final VoidCallback aoConcordar;
  final VoidCallback? aoRecusar;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Seus dados na nuvem'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Favoritos, anotações, dias de leitura e conversas do chat falam '
            'da sua fé, e a lei os trata como dados pessoais sensíveis.\n\n'
            'Com a conta Google, eles ficam guardados na nuvem do aplicativo '
            '(Firebase, do Google, que pode usar servidores fora do Brasil), '
            'só para sincronizar entre os seus aparelhos. Nada disso é vendido '
            'nem usado para anúncio. Ao concordar, você consente com esse '
            'uso.\n\n'
            'Você pode retirar o consentimento quando quiser, apagando a cópia '
            'da nuvem no seu perfil, aberto pela sua foto na Hoje.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TabernaculoBotaoTerciario(
              onPressed: () => context.push('/privacidade'),
              child: const Text('Ler a política de privacidade'),
            ),
          ),
        ],
      ),
      actions: [
        TabernaculoBotaoTerciario(
          onPressed: () {
            Navigator.pop(context);
            aoRecusar?.call();
          },
          child: Text(rotuloDeRecusar),
        ),
        TabernaculoBotaoPrimario(
          onPressed: () {
            Navigator.pop(context);
            aoConcordar();
          },
          child: Text(rotuloDeConcordar),
        ),
      ],
    );
  }
}
