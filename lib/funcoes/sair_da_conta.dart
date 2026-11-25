import 'package:material_ui/material_ui.dart';

import '../dados/nuvem.dart';
import '../dados/registro.dart';
import 'aviso.dart';

/// Confirma e executa o logout. Público porque o botão do cabeçalho da Hoje
/// (`TabernaculoBotaoDeConta`) e o perfil chamam isto.
///
/// Sair só termina depois de tudo guardado na conta (ver `Nuvem.sair`): se
/// algo não chegou lá, a sessão continua, nada sai do aparelho e o erro pede
/// para tentar de novo.
Future<void> sairDaConta(BuildContext context) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Sair da conta?',
    conteudo:
        'Favoritos, notas e progresso ficam guardados na sua conta e voltam '
        'quando você entrar de novo.',
    rotuloDaAcao: 'Sair',
  );
  if (!confirmou || !context.mounted) return;
  final mensageiro = ScaffoldMessenger.of(context);
  try {
    await Nuvem.instancia.sair();
    mostrarAvisoNo(mensageiro, 'Você saiu da conta');
  } on SairDaContaFalhou {
    // `sairEmOrdem` já registrou a causa.
    mostrarErroNo(
      mensageiro,
      'Não foi possível guardar tudo na sua conta. Verifique a conexão e '
      'tente de novo',
    );
  } catch (erro, pilha) {
    Registro.erro('sairDaConta', erro, pilha);
    mostrarErroNo(mensageiro, 'Não foi possível sair agora. Tente de novo');
  }
}
