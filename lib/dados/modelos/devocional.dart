/// Uma leitura diária: Manhã, Noite ou a promessa do dia.
class Devocional {
  const Devocional({
    required this.referencia,
    required this.texto,
    this.titulo = '',
    this.versiculo = '',
    this.outrosVersiculos = const [],
  });

  factory Devocional.doJson(Map<String, dynamic> json) => Devocional(
    referencia: json['referencia'] as String? ?? '',
    texto: json['devocional'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    versiculo: json['versiculo'] as String? ?? '',
  );

  final String referencia;
  final String texto;

  /// Promessas de Deus dá um título a cada dia; Manhã e Noite não.
  final String titulo;

  /// A promessa bíblica em destaque, separada do comentário. Vazio em
  /// Manhã e Noite, onde o versículo vem embutido no próprio texto.
  final String versiculo;

  /// Versículos-base além do principal, para o raro dia cuja epígrafe encadeia
  /// mais de uma passagem, como o de 12 de julho de Manhã e Noite, que abre
  /// citando Judas 1:1, 1 Coríntios 1:2 e 1 Pedro 1:2 em sequência.
  final List<(String referencia, String versiculo)> outrosVersiculos;

  /// Todos os pares (referência, versículo) do dia, o principal primeiro. A
  /// regra do que compõe a epígrafe vive aqui: a voz e a tela leem dela,
  /// em vez de cada uma remontar a lista por conta própria.
  List<(String referencia, String versiculo)> get paresDeVersiculos => [
    (referencia, versiculo),
    ...outrosVersiculos,
  ];
}

enum Periodo {
  manha('manha', 'Manhã'),
  noite('noite', 'Noite');

  const Periodo(this.chave, this.nome);

  final String chave;
  final String nome;

  /// A virada segue o horário do aparelho: manhã até 17h59, noite a partir das 18h.
  static Periodo pelaHora(int hora) =>
      hora < 18 ? Periodo.manha : Periodo.noite;
}
