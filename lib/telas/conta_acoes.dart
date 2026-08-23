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
    // Fechar a janela é decisão do usuário, não falha: aviso quieto.
    if (erro.code == 'popup-closed-by-user' ||
        erro.code == 'cancelled-popup-request') {
      if (context.mounted) mostrarAviso(context, 'Login cancelado.');
      return;
    }
    Registro.erro('entrarNaConta', erro, pilha);
    if (!context.mounted) return;
    mostrarErro(
      context,
      kIsWeb
          ? 'Não foi possível entrar. Verifique se o navegador permite '
                'janelas deste site.'
          : _motivoDeLogin(erro),
    );
  } catch (erro, pilha) {
    // Qualquer outra falha (Firebase sem inicializar, sem rede, App Check
    // recusando o token) não pode deixar o botão "Entrar" sem reação
    // nenhuma: melhor um aviso de recuperação do que o toque parecer
    // ignorado. O detalhe técnico fica no registro, não na tela.
    Registro.erro('entrarNaConta', erro, pilha);
    if (!context.mounted) return;
    mostrarErro(context, 'Não foi possível entrar agora. Tente de novo.');
  }
}

/// Mensagem humana para o fracasso do login no aparelho. Mapeia os códigos
/// que acontecem de verdade em produção; o resto cai no texto genérico de
/// recuperação, e a causa técnica fica no registro.log para quem dá suporte.
String _motivoDeLogin(FirebaseAuthException erro) {
  switch (erro.code) {
    case 'network-request-failed':
      return 'Sem conexão com a internet. Verifique a rede e tente de novo.';
    case 'too-many-requests':
      return 'Muitas tentativas seguidas. Espere um pouco e tente de novo.';
    case 'operation-not-allowed':
    case 'configuration-not-found':
      return 'Entrar com a Google não está disponível agora.';
    case 'user-disabled':
      return 'Esta conta não pode entrar.';
    default:
      return 'Não foi possível entrar agora. Tente de novo.';
  }
}
