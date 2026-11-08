/// Reconhece, numa mensagem do chat, sinais de quem pensa em tirar a própria
/// vida ou se ferir, para a tela mostrar o contato do CVV ao lado da resposta
/// da IA. Uma IA não substitui ajuda humana; o aviso fixo não depende de o
/// modelo lembrar de dá-lo.
///
// ponytail: lista de expressões, não classificador; deixa passar frases fora
// dela e pode avisar em falso positivo (que custa só um cartão a mais). Trocar
// por classificação do próprio modelo se a lista se mostrar curta.
bool pedeApoioEmCrise(String texto) {
  final normalizado = _semAcentos(texto.toLowerCase());
  return _sinaisDeCrise.any(normalizado.contains);
}

const _sinaisDeCrise = [
  'suicid',
  'me matar',
  'tirar minha vida',
  'tirar a minha vida',
  'tirar a propria vida',
  'acabar com minha vida',
  'acabar com a minha vida',
  'nao quero mais viver',
  'nao aguento mais viver',
  'quero morrer',
  'queria morrer',
  'sem vontade de viver',
  'desistir de viver',
  'melhor morto',
  'melhor morta',
  'me mutilar',
  'automutila',
  'me cortar',
  'me ferir',
];

const _acentos = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'é': 'e',
  'ê': 'e',
  'í': 'i',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ü': 'u',
  'ç': 'c',
};

String _semAcentos(String texto) =>
    texto.split('').map((letra) => _acentos[letra] ?? letra).join();
