import 'nuvem.dart';

/// Interruptores de funcionalidades do app. Sem servidor de configuração:
/// mudar um valor aqui e reimplantar é o próprio "ligar/desligar" possível
/// para um app de usuário único — um `firebase_remote_config` seria uma
/// dependência nova para o mesmo resultado.
class Recursos {
  Recursos._();

  /// Aba "Meus planos", onde o usuário monta o próprio cronograma de leitura.
  static const planoPersonalizado = true;

  /// Botão "Ouvir" nos textos (Bíblia, devocional, introduções, notas).
  static const ouvirTextos = true;

  /// E-mail da conta Google de quem já pode usar Conversas (chat com as
  /// personas) e ver os balões flutuantes. Em teste: o chat chama a API paga
  /// do Gemini, e abrir para todo mundo antes da hora custaria sem controle.
  static const _emailComConversas = 'felipe.anegrini@gmail.com';

  /// Override para teste: os testes de balões e chat não fazem login de
  /// verdade (`Nuvem.iniciar` nunca roda neles), então sem isto a comparação
  /// de e-mail travaria sempre em `false` e nenhum deles veria o recurso. Em
  /// produção fica `null` e vale a comparação real.
  static bool? conversasForcado;

  static bool get conversas =>
      conversasForcado ?? Nuvem.instancia.email == _emailComConversas;
}
