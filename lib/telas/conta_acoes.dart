import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/nuvem.dart';
import '../data/registro.dart';
import 'aviso.dart';

/// Tenta o login e mostra o motivo quando não completa. Público porque dois
/// botões chamam isto: o do cabeçalho da Hoje (`hoje.dart`, `_BotaoDeConta`)
/// e o cartão de plano compartilhado (`meu_plano.dart`). Quem chama precisa
/// fazê-lo direto do `onTap`/`onPressed` (sem `await` antes): o navegador só
/// deixa abrir a janela do login dentro do gesto do usuário, e qualquer
/// espera antes do `signInWithPopup` consome esse gesto e a janela sai
/// bloqueada.
Future<void> entrarNaConta(BuildContext context, Nuvem nuvem) async {
  try {
    await nuvem.entrar();
  } on FirebaseAuthException catch (erro, pilha) {
    if (erro.code == 'popup-closed-by-user') {
      if (context.mounted) mostrarAviso(context, 'Login cancelado.');
      return;
    }
    Registro.erro('entrarNaConta', erro, pilha);
    if (!context.mounted) return;
    // "Navegador"/"janelas" só faz sentido no popup/redirect da web — no
    // fluxo nativo (Android/iOS) o `FirebaseAuthException` vem de outra
    // causa (credencial inválida, rede, App Check). Mostra `code`/`message`
    // reais na tela (não só no registro.log), pra dar pra reportar sem
    // precisar de `adb logcat` — ponytail: texto cru da exceção, sem
    // tradução por código; se isto for pra produção com usuário final,
    // trocar por mensagens específicas por `erro.code`.
    mostrarAviso(
      context,
      kIsWeb
          ? 'Não foi possível entrar. Verifique se o navegador permite '
                'janelas deste site.'
          : 'Não foi possível entrar (${erro.code}): ${erro.message}',
    );
  } catch (erro, pilha) {
    // Qualquer outra falha (Firebase sem inicializar, sem rede, App Check
    // recusando o token) não pode deixar o botão "Entrar" sem reação
    // nenhuma: melhor um aviso com o erro cru do que o toque parecer
    // ignorado.
    Registro.erro('entrarNaConta', erro, pilha);
    if (!context.mounted) return;
    mostrarAviso(context, 'Não foi possível entrar: $erro');
  }
}
