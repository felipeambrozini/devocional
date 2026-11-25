import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/nuvem.dart';
import '../funcoes/sair_da_conta.dart';
import 'botao.dart';
import 'botao_de_entrar.dart';

/// Entrar, sair ou esperar, no fim do cabeçalho da Hoje. Três estados, nunca
/// dois ao mesmo tempo: a espera enquanto a sessão pode estar restaurando
/// (sem ela, o "Entrar" aparecia e sumia sozinho segundos depois, parecendo
/// que o app tinha deslogado sozinho ao fechar), o convite para entrar, ou o
/// botão "Sair" de quem já entrou (o e-mail fica no Sobre, em "Conta e
/// privacidade").
class TabernaculoBotaoDeConta extends StatelessWidget {
  const TabernaculoBotaoDeConta({super.key});

  @override
  Widget build(BuildContext context) {
    final nuvem = Nuvem.instancia;
    return ListenableBuilder(
      listenable: nuvem,
      builder: (context, _) {
        if (nuvem.logado) {
          return TabernaculoBotaoTerciario.icon(
            onPressed: () => sairDaConta(context),
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 18),
            label: const Text('Sair'),
          );
        }
        if (nuvem.carregandoConta) {
          // Espera estática, sem animação: a restauração leva 20-30s no
          // Android, e um giro indeterminado queimaria bateria à toa no
          // cabeçalho de toda abertura (além de nunca assentar em teste).
          return Tooltip(
            message: 'Verificando conta…',
            child: Semantics(
              label: 'Verificando conta',
              liveRegion: true,
              child: FaIcon(
                FontAwesomeIcons.hourglassStart,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        return const TabernaculoBotaoDeEntrar(rotulo: 'Entrar', discreto: true);
      },
    );
  }
}
