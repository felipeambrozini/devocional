/// Passos do controle de tamanho do texto de leitura, e o rótulo de cada um.
///
/// Fatores e não pixels: o tema é quem sabe o tamanho base de cada estilo, e
/// assim o versículo, o comentário do devocional e a introdução crescem juntos,
/// na mesma proporção. O menor passo existe porque quem lê numa janela grande
/// às vezes quer caber mais texto na tela, não menos.
///
/// Vivem aqui, e não no tema, porque o [Estado] precisa deles para recusar um
/// valor gravado fora da lista, e o `data` não importa `theme.dart`.
const escalasDeLeitura = <double>[0.85, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];
const rotulosDeEscala = <String>[
  'Pequeno',
  'Padrão',
  'Médio',
  'Grande',
  'Maior',
  'Muito grande',
  'Máximo',
];

/// Claro, escuro ou o que o aparelho estiver usando.
///
/// Seguir o aparelho é o padrão, mas não pode ser a única opção: às nove da
/// noite o celular pode ainda estar no claro, e quem lê na cama quer o escuro
/// independente disso.
///
/// Vive aqui pelo mesmo motivo das escalas: o [Estado] precisa dele para ler e
/// gravar a preferência, e o `data` não importa `theme.dart` nem `material.dart`.
/// Quem traduz para `ThemeMode` é o `main.dart`.
enum ModoDoTema {
  sistema('sistema', 'Automático'),
  claro('claro', 'Claro'),
  escuro('escuro', 'Escuro');

  const ModoDoTema(this.chave, this.rotulo);

  final String chave;
  final String rotulo;
}
