import 'package:flutter/foundation.dart' show kIsWeb;

import 'config_admin.dart';
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

/// Interruptores de funcionalidades do app.
///
/// Os valores vivem no Firestore (`config/recursos`, ver `config_admin.dart`)
/// e o painel admin (`/admin`, só web e só o dono) os edita sem reimplantar.
/// Sem o documento (primeiro deploy, sem rede, teste), cada campo vale o
/// padrão ligado — desligar exige um gesto explícito do admin, nunca a
/// ausência de dado.
class Recursos {
  Recursos._();

  /// A conta do dono, a única que vê o painel admin. Minúsculas de propósito:
  /// a comparação abaixo normaliza o e-mail logado antes de comparar.
  static const emailDoAdmin = 'felipe.anegrini@gmail.com';

  /// Se a conta logada é a do dono. Só o e-mail decide — o portão da web
  /// fica em [adminNaWeb], para este getter continuar testável sem plataforma.
  static bool get ehAdmin {
    final email = Nuvem.instancia.email?.trim().toLowerCase();
    return email == emailDoAdmin;
  }

  /// O portão do painel admin: conta do dono E web. No celular não existe
  /// painel, mesmo para o dono — o admin é ferramenta de escritório, não de
  /// leitura diária.
  static bool get adminNaWeb => kIsWeb && ehAdmin;

  /// Aba "Meus planos", onde o usuário monta o próprio cronograma de leitura.
  static bool get planoPersonalizado =>
      planoPersonalizadoForcado ??
      ConfigAdmin.instancia.planoPersonalizadoAtivo;

  /// Override para teste, mesmo padrão de [conversasForcado].
  static bool? planoPersonalizadoForcado;

  /// Botão "Ouvir" nos textos (Bíblia, devocional, introduções, notas).
  static bool get ouvirTextos =>
      ouvirTextosForcado ?? ConfigAdmin.instancia.ouvirTextosAtivo;

  /// Override para teste, mesmo padrão de [conversasForcado].
  static bool? ouvirTextosForcado;

  /// Cronograma anual (aba "Cronograma" dentro do Plano).
  static bool get cronograma =>
      cronogramaForcado ?? ConfigAdmin.instancia.cronogramaAtivo;

  /// Override para teste, mesmo padrão de [conversasForcado].
  static bool? cronogramaForcado;

  /// Cada leitura do devocional desliga em separado: Manhã, Noite e Promessas
  /// de Deus têm públicos diferentes, e tirar uma do ar não tira as outras.
  static bool get devocionalManha =>
      devocionalManhaForcado ?? ConfigAdmin.instancia.manhaAtivo;

  /// Override para teste, mesmo padrão de [conversasForcado].
  static bool? devocionalManhaForcado;

  static bool get devocionalNoite =>
      devocionalNoiteForcado ?? ConfigAdmin.instancia.noiteAtivo;

  /// Override para teste, mesmo padrão de [conversasForcado].
  static bool? devocionalNoiteForcado;

  static bool get promessas =>
      promessasForcado ?? ConfigAdmin.instancia.promessasAtivo;

  /// Override para teste, mesmo padrão de [conversasForcado].
  static bool? promessasForcado;

  /// E-mails das contas Google que já podem usar Conversas (chat com as
  /// personas) e ver os balões flutuantes. Em teste: o chat chama a API paga
  /// do Gemini, e abrir para todo mundo antes da hora custaria sem controle.
  ///
  /// A lista mora no Firestore (`config/recursos`, campo `emailsComConversas`)
  /// e o painel admin edita sem reimplantar, sem versionar e-mail nenhum no
  /// repositório. O `--dart-define=EMAILS_COM_CONVERSAS` abaixo é só o legado
  /// de bootstrap: vale enquanto o documento ainda não carregou (primeiro
  /// deploy, sem rede), e perde assim que o Firestore responde.
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
    if (!ConfigAdmin.instancia.conversasAtivas) return false;
    final email = Nuvem.instancia.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return false;
    if (ConfigAdmin.instancia.carregado) {
      return ConfigAdmin.instancia.emailsComConversas.contains(email);
    }
    return _allowlistDeConversas.contains(email);
  }
}
