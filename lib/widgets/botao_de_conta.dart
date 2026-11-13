import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/nuvem.dart';
import '../dados/registro.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/conta_acoes.dart';
import 'botao.dart';

/// Confirma e executa o logout. Um toque no "Sair" não pode deslogar sem
/// pergunta: na web, o espelho na nuvem é a proteção contra o navegador
/// limpar o armazenamento local, e derrubar a sessão desarma essa proteção.
Future<void> _sairDaConta(BuildContext context) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Sair da conta?',
    conteudo:
        'Favoritos, notas e progresso ficam neste aparelho, mas a cópia na '
        'nuvem para de se atualizar. Na web, é ela que devolve os dados se o '
        'navegador limpar o armazenamento.',
    rotuloDaAcao: 'Sair',
  );
  if (!confirmou || !context.mounted) return;
  final mensageiro = ScaffoldMessenger.of(context);
  try {
    await Nuvem.instancia.sair();
    mostrarAvisoNo(mensageiro, 'Você saiu da conta.');
  } catch (erro, pilha) {
    Registro.erro('_sairDaConta', erro, pilha);
    mostrarErroNo(mensageiro, 'Não foi possível sair agora. Tente de novo.');
  }
}

/// Entrar, sair ou esperar, no fim do cabeçalho da Hoje. Três estados, nunca
/// dois ao mesmo tempo: a espera enquanto a sessão pode estar restaurando
/// (sem ela, o "Entrar" aparecia e sumia sozinho segundos depois, parecendo
/// que o app tinha deslogado sozinho ao fechar), o convite para entrar, ou o
/// botão "Sair" de quem já entrou (o e-mail fica no Sobre, em "Conta e
/// privacidade").
class DevocionalBotaoDeConta extends StatelessWidget {
  const DevocionalBotaoDeConta({super.key});

  @override
  Widget build(BuildContext context) {
    final nuvem = Nuvem.instancia;
    return ListenableBuilder(
      listenable: nuvem,
      builder: (context, _) {
        if (nuvem.logado) {
          return DevocionalBotaoTerciario.icon(
            onPressed: () => _sairDaConta(context),
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
        return DevocionalBotaoSecundario.icon(
          onPressed: nuvem.entrando
              ? null
              : () => entrarNaConta(context, nuvem),
          icon: nuvem.entrando
              ? const SizedBox(
                  width: DevocionalEspacamento.sp18,
                  height: DevocionalEspacamento.sp18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Carregando',
                  ),
                )
              : const FaIcon(FontAwesomeIcons.google, size: 16),
          label: const Text('Entrar'),
        );
      },
    );
  }
}
