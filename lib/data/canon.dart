/// Os 66 livros, na ordem canônica.
///
/// O `index.json` de cada versão traz os mesmos dados, mas esta lista é síncrona e
/// sempre disponível, o que evita um `await` só para desenhar o seletor de livros ou
/// resolver o nome de um livro vindo do cronograma de leitura.
class Livro {
  const Livro(this.slug, this.nome, this.abrev, this.capitulos, this.testamento);

  final String slug;
  final String nome;
  final String abrev;
  final int capitulos;
  final Testamento testamento;
}

enum Testamento { antigo, novo }

const _at = Testamento.antigo;
const _nt = Testamento.novo;

const canon = <Livro>[
  Livro('genesis', 'Gênesis', 'Gn', 50, _at),
  Livro('exodo', 'Êxodo', 'Êx', 40, _at),
  Livro('levitico', 'Levítico', 'Lv', 27, _at),
  Livro('numeros', 'Números', 'Nm', 36, _at),
  Livro('deuteronomio', 'Deuteronômio', 'Dt', 34, _at),
  Livro('josue', 'Josué', 'Js', 24, _at),
  Livro('juizes', 'Juízes', 'Jz', 21, _at),
  Livro('rute', 'Rute', 'Rt', 4, _at),
  Livro('1samuel', '1 Samuel', '1Sm', 31, _at),
  Livro('2samuel', '2 Samuel', '2Sm', 24, _at),
  Livro('1reis', '1 Reis', '1Rs', 22, _at),
  Livro('2reis', '2 Reis', '2Rs', 25, _at),
  Livro('1cronicas', '1 Crônicas', '1Cr', 29, _at),
  Livro('2cronicas', '2 Crônicas', '2Cr', 36, _at),
  Livro('esdras', 'Esdras', 'Ed', 10, _at),
  Livro('neemias', 'Neemias', 'Ne', 13, _at),
  Livro('ester', 'Ester', 'Et', 10, _at),
  Livro('jo', 'Jó', 'Jó', 42, _at),
  Livro('salmos', 'Salmos', 'Sl', 150, _at),
  Livro('proverbios', 'Provérbios', 'Pv', 31, _at),
  Livro('eclesiastes', 'Eclesiastes', 'Ec', 12, _at),
  Livro('cantares', 'Cantares', 'Ct', 8, _at),
  Livro('isaias', 'Isaías', 'Is', 66, _at),
  Livro('jeremias', 'Jeremias', 'Jr', 52, _at),
  Livro('lamentacoes', 'Lamentações', 'Lm', 5, _at),
  Livro('ezequiel', 'Ezequiel', 'Ez', 48, _at),
  Livro('daniel', 'Daniel', 'Dn', 12, _at),
  Livro('oseias', 'Oseias', 'Os', 14, _at),
  Livro('joel', 'Joel', 'Jl', 3, _at),
  Livro('amos', 'Amós', 'Am', 9, _at),
  Livro('obadias', 'Obadias', 'Ob', 1, _at),
  Livro('jonas', 'Jonas', 'Jn', 4, _at),
  Livro('miqueias', 'Miqueias', 'Mq', 7, _at),
  Livro('naum', 'Naum', 'Na', 3, _at),
  Livro('habacuque', 'Habacuque', 'Hc', 3, _at),
  Livro('sofonias', 'Sofonias', 'Sf', 3, _at),
  Livro('ageu', 'Ageu', 'Ag', 2, _at),
  Livro('zacarias', 'Zacarias', 'Zc', 14, _at),
  Livro('malaquias', 'Malaquias', 'Ml', 4, _at),
  Livro('mateus', 'Mateus', 'Mt', 28, _nt),
  Livro('marcos', 'Marcos', 'Mc', 16, _nt),
  Livro('lucas', 'Lucas', 'Lc', 24, _nt),
  Livro('joao', 'João', 'Jo', 21, _nt),
  Livro('atos', 'Atos', 'At', 28, _nt),
  Livro('romanos', 'Romanos', 'Rm', 16, _nt),
  Livro('1corintios', '1 Coríntios', '1Co', 16, _nt),
  Livro('2corintios', '2 Coríntios', '2Co', 13, _nt),
  Livro('galatas', 'Gálatas', 'Gl', 6, _nt),
  Livro('efesios', 'Efésios', 'Ef', 6, _nt),
  Livro('filipenses', 'Filipenses', 'Fp', 4, _nt),
  Livro('colossenses', 'Colossenses', 'Cl', 4, _nt),
  Livro('1tessalonicenses', '1 Tessalonicenses', '1Ts', 5, _nt),
  Livro('2tessalonicenses', '2 Tessalonicenses', '2Ts', 3, _nt),
  Livro('1timoteo', '1 Timóteo', '1Tm', 6, _nt),
  Livro('2timoteo', '2 Timóteo', '2Tm', 4, _nt),
  Livro('tito', 'Tito', 'Tt', 3, _nt),
  Livro('filemom', 'Filemom', 'Fm', 1, _nt),
  Livro('hebreus', 'Hebreus', 'Hb', 13, _nt),
  Livro('tiago', 'Tiago', 'Tg', 5, _nt),
  Livro('1pedro', '1 Pedro', '1Pe', 5, _nt),
  Livro('2pedro', '2 Pedro', '2Pe', 3, _nt),
  Livro('1joao', '1 João', '1Jo', 5, _nt),
  Livro('2joao', '2 João', '2Jo', 1, _nt),
  Livro('3joao', '3 João', '3Jo', 1, _nt),
  Livro('judas', 'Judas', 'Jd', 1, _nt),
  Livro('apocalipse', 'Apocalipse', 'Ap', 22, _nt),
];

final Map<String, Livro> _porSlug = {for (final l in canon) l.slug: l};

Livro? livroPorSlug(String slug) => _porSlug[slug];

/// Nome de exibição a partir do slug, com o próprio slug como último recurso para
/// que uma referência desconhecida apareça na tela em vez de sumir.
String nomeDoLivro(String slug) => _porSlug[slug]?.nome ?? slug;

/// As duas versões disponíveis. A ordem define a ordem do alternador na tela.
enum Versao {
  bkj('bkj', 'King James 1611', 'BKJ'),
  nvt('nvt', 'Nova Versão Transformadora', 'NVT');

  const Versao(this.pasta, this.nome, this.sigla);

  final String pasta;
  final String nome;
  final String sigla;
}
