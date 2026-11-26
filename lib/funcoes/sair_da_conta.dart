import 'package:material_ui/material_ui.dart';

import '../dados/nuvem.dart';
import '../dados/registro.dart';
import 'aviso.dart';

/// Confirma e executa o logout. Público porque o perfil (`TelaPerfil`) chama
/// isto.
///
/// Sair só termina depois de tudo guardado na conta (ver `Nuvem.sair`): se
/// algo não chegou lá, a sessão continua, nada sai do aparelho e o erro pede
/// para tentar de novo.
///
/// [aoConfirmar] roda logo depois do "Sair" do diálogo, antes da espera, para
/// quem chama mostrar que está salvando (o Sair pode levar uns 15 segundos).
/// Devolve se a conta saiu de fato: `false` se a pessoa desistiu ou se falhou.
Future<bool> sairDaConta(
  BuildContext context, {
  VoidCallback? aoConfirmar,
}) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Sair da conta?',
    conteudo:
        'Favoritos, notas e progresso ficam guardados na sua conta e voltam '
        'quando você entrar de novo.',
    rotuloDaAcao: 'Sair',
  );
  if (!confirmou || !context.mounted) return false;
  final mensageiro = ScaffoldMessenger.of(context);
  aoConfirmar?.call();
  try {
    await Nuvem.instancia.sair();
    mostrarAvisoNo(mensageiro, 'Você saiu da conta');
    return true;
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
  return false;
}
