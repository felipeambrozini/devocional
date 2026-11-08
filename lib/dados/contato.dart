/// E-mail de contato do app: destino de "Relatar um problema" em Sobre e o
/// canal da política de privacidade para pedidos sobre os dados. Vem por
/// `--dart-define`, como as outras chaves, para não versionar um endereço
/// pessoal no repositório. Vazio esconde o item em Sobre: sem endereço
/// configurado, um mailto: sem destino só confundiria.
const emailDeContato = String.fromEnvironment('EMAIL_DE_CONTATO');
