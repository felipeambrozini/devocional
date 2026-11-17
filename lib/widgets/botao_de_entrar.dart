import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/nuvem.dart';
import '../estilo/espacamento.dart';
import '../funcoes/conta_acoes.dart';
import 'botao.dart';

/// O botão de entrar com a conta Google, com o giro no lugar do "G" enquanto
/// o login está no ar (e desabilitado, para um segundo toque não abrir outra
/// janela). Ouve a [Nuvem] por conta própria: quem o usa costuma construí-lo
/// dentro de um cartão que o pai não redesenha.
///
/// O toque chama `entrarNaConta` direto, sem `await` antes: na web, a janela
/// do login só abre dentro do gesto do usuário.
class DevocionalBotaoDeEntrar extends StatelessWidget {
  const DevocionalBotaoDeEntrar({
    super.key,
    this.rotulo = 'Entrar com Google',
    this.discreto = false,
    this.aoEntrar,
  });

  final String rotulo;

  /// Secundário em vez de primário: no cabeçalho da Hoje, o entrar divide a
  /// linha com a saudação e não pode ser a maior mancha de metal da tela.
  final bool discreto;

  /// Roda depois do login. Quem só depende da [Nuvem] para reconstruir a
  /// tela não precisa dele.
  final VoidCallback? aoEntrar;

  @override
  Widget build(BuildContext context) {
    final nuvem = Nuvem.instancia;
    return ListenableBuilder(
      listenable: nuvem,
      builder: (context, _) {
        final onPressed = nuvem.entrando
            ? null
            : () async {
                await entrarNaConta(context, nuvem);
                aoEntrar?.call();
              };
        final icone = nuvem.entrando
            ? const SizedBox(
                width: DevocionalEspacamento.sp18,
                height: DevocionalEspacamento.sp18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Carregando',
                ),
              )
            : const FaIcon(FontAwesomeIcons.google, size: 16);
        return discreto
            ? DevocionalBotaoSecundario.icon(
                onPressed: onPressed,
                icon: icone,
                label: Text(rotulo),
              )
            : DevocionalBotaoPrimario.icon(
                onPressed: onPressed,
                icon: icone,
                label: Text(rotulo),
              );
      },
    );
  }
}
