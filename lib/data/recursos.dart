import 'nuvem.dart';

/// Interpreta a lista de `--dart-define=EMAILS_COM_CONVERSAS=a@x.com,b@y.com`
/// (separada por vírgula, com espaço e caixa normalizados) — extraído à
/// parte para dar para testar sem precisar passar `--dart-define` ao
/// `flutter test`, que sempre roda com o valor vazio.
Set<String> allowlistDeEmails(String bruto) => bruto
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .where((email) => email.isNotEmpty)
    .toSet();

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

  /// E-mails das contas Google que já podem usar Conversas (chat com as
  /// personas) e ver os balões flutuantes. Em teste: o chat chama a API paga
  /// do Gemini, e abrir para todo mundo antes da hora custaria sem controle.
  /// Convidar alguém é mudar o secret do build e reimplantar, sem versionar
  /// e-mail nenhum no repositório.
  static const _emailsComConversas = String.fromEnvironment(
    'EMAILS_COM_CONVERSAS',
  );

  static final Set<String> _allowlistDeConversas = allowlistDeEmails(
    _emailsComConversas,
  );

  /// Override para teste: os testes de balões e chat não fazem login de
  /// verdade (`Nuvem.iniciar` nunca roda neles), então sem isto a allowlist
  /// vazia recusaria sempre e nenhum deles veria o recurso. Em produção fica
  /// `null` e vale a allowlist real.
  static bool? conversasForcado;

  static bool get conversas {
    final forcado = conversasForcado;
    if (forcado != null) return forcado;
    final email = Nuvem.instancia.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return false;
    return _allowlistDeConversas.contains(email);
  }
}
