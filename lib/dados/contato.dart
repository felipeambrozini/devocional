/// E-mail de contato do app: destino de "Relatar um problema" em Sobre e o
/// canal da política de privacidade para pedidos sobre os dados. Vem por
/// `--dart-define`, como as outras chaves, para não versionar um endereço
/// pessoal no repositório. Vazio esconde o item em Sobre: sem endereço
/// configurado, um mailto: sem destino só confundiria.
const emailDeContato = String.fromEnvironment('EMAIL_DE_CONTATO');

/// O link `mailto:` com assunto e corpo preenchidos.
///
/// Monta a query na mão, com `Uri.encodeComponent`: o `queryParameters` do
/// `Uri` codifica espaço como `+` (regra de formulário), e cliente de e-mail
/// não desfaz isso, então o `+` aparecia no assunto e no corpo.
Uri mailtoPara(
  String destino, {
  required String assunto,
  required String corpo,
}) => Uri(
  scheme: 'mailto',
  path: destino,
  query:
      'subject=${Uri.encodeComponent(assunto)}'
      '&body=${Uri.encodeComponent(corpo)}',
);
