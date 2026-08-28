/// Nomes dos meses, usados no cronograma e no calendário.
const meses = <String>[
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String dataLonga(DateTime data) {
  final base = '${data.day} de ${meses[data.month - 1].toLowerCase()}';
  // Sem ano no ano corrente ("17 de agosto"), com ano fora dele: na virada
  // do ano, "17 de agosto" de outro ano seria ambíguo por um instante.
  return data.year == DateTime.now().year ? base : '$base de ${data.year}';
}
