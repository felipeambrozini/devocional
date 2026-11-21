/// Passos do controle de tamanho do texto de leitura, e o rótulo de cada um.
///
/// Fatores e não pixels: o tema é quem sabe o tamanho base de cada estilo, e
/// assim o versículo, o comentário do devocional e a introdução crescem juntos,
/// na mesma proporção. Os dois passos abaixo do padrão existem porque quem lê
/// numa janela grande às vezes quer caber mais texto na tela, não menos.
///
/// Cada passo fica uns 18% ou mais acima do anterior. Com passos de 15% (a
/// lista antiga tinha 1,15× e 1,5× entre os outros) a diferença no versículo
/// era de 2 a 3 pixels, e quem tocava não via o texto mudar.
///
/// A preferência é gravada pelo valor, não pela posição. Um valor de uma lista
/// antiga vai para o passo mais próximo ([passoDeEscalaMaisProximo]).
///
/// Vivem aqui, e não no tema, porque o [Estado] precisa deles para recusar um
/// valor gravado fora da lista, e o `dados` não importa `tema.dart`.
const escalasDeLeitura = <double>[0.7, 0.85, 1.0, 1.3, 1.6, 2.0];
const rotulosDeEscala = <String>[
  'Mínimo',
  'Pequeno',
  'Padrão',
  'Grande',
  'Muito grande',
  'Máximo',
];

/// O passo de [escalasDeLeitura] mais perto de [escala], ou `null` se ela
/// estiver fora da faixa oferecida (valor corrompido ou de versão futura).
///
/// No empate fica o maior: quem tinha escolhido 1,15× queria o texto acima do
/// padrão, e voltar ao padrão desfaria a escolha.
double? passoDeEscalaMaisProximo(double escala) {
  if (escala < escalasDeLeitura.first || escala > escalasDeLeitura.last) {
    return null;
  }
  var melhor = escalasDeLeitura.first;
  for (final passo in escalasDeLeitura) {
    // Arredonda a distância para que 1,15 fique de fato no meio de 1,0 e 1,3
    // (em ponto flutuante 1,15 − 1,0 sai um pouco maior que 1,3 − 1,15).
    final distancia = ((escala - passo).abs() * 1000).round();
    final distanciaMelhor = ((escala - melhor).abs() * 1000).round();
    if (distancia <= distanciaMelhor) melhor = passo;
  }
  return melhor;
}

/// Claro, escuro ou o que o aparelho estiver usando.
///
/// Seguir o aparelho é o padrão, mas não pode ser a única opção: às nove da
/// noite o celular pode ainda estar no claro, e quem lê na cama quer o escuro
/// independente disso.
///
/// Vive aqui pelo mesmo motivo das escalas: o [Estado] precisa dele para ler e
/// gravar a preferência, e o `dados` não importa `tema.dart` nem `material.dart`.
/// Quem traduz para `ThemeMode` é o `main.dart`.
enum ModoDoTema {
  sistema('sistema', 'Automático'),
  claro('claro', 'Claro'),
  escuro('escuro', 'Escuro');

  const ModoDoTema(this.chave, this.rotulo);

  final String chave;
  final String rotulo;
}
