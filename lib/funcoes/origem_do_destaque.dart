import '../dados/biblioteca.dart';
import '../dados/conteudo.dart';
import '../dados/leitura_de_livros.dart';
import '../dados/modelos.dart';
import 'datas.dart';

/// De onde vem um favorito ou nota que não é da Bíblia: o título do cartão e
/// o texto de trás, para as telas de notas da Biblioteca e do Devocional.
class OrigemDoDestaque {
  const OrigemDoDestaque({
    required this.referencia,
    required this.rotaDeAbrir,
    required this.rotulo,
  });

  /// "Respigas entre os Feixes, capítulo 3" ou "Manhã, 17 de novembro".
  final String referencia;

  /// A rota que reabre o texto.
  final String rotaDeAbrir;

  /// De onde veio: "Devocional" ou o nome do livro da Biblioteca.
  final String rotulo;

  /// Nulo para um slug que o app não conhece (livro tirado do catálogo).
  static OrigemDoDestaque? de(DestaqueDeLivro d) {
    if (ehSlugDeDevocional(d.slug)) {
      final leitura = leituraDoSlug(d.slug);
      final data = dataDoDestaque(d);
      final leituraRotulo = switch (leitura) {
        'manha' => 'Manhã',
        'noite' => 'Noite',
        'promessas' => 'Promessas de Deus',
        _ => null,
      };
      if (leituraRotulo == null || data == null) return null;
      return OrigemDoDestaque(
        referencia: '$leituraRotulo, ${dataLonga(data)}',
        rotaDeAbrir:
            '/$leitura?data=${data.year}-'
            '${data.month.toString().padLeft(2, '0')}-'
            '${data.day.toString().padLeft(2, '0')}',
        rotulo: 'Devocional',
      );
    }
    final obra = obraPorSlug(d.slug);
    if (obra == null) return null;
    return OrigemDoDestaque(
      referencia: '${obra.titulo}, capítulo ${d.capitulo + 1}',
      rotaDeAbrir: '/biblioteca/${d.slug}/${d.capitulo + 1}',
      rotulo: obra.titulo,
    );
  }

  /// O dia de um destaque de devocional, no ano corrente (a rota de hoje
  /// continua valendo) ou em 2024 para 29 de fevereiro.
  static DateTime? dataDoDestaque(DestaqueDeLivro d) {
    final mes = d.capitulo ~/ 100;
    final dia = d.capitulo % 100;
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    final ano = DateTime.now().year;
    final data = DateTime(ano, mes, dia);
    if (data.month == mes) return data;
    final bissexto = DateTime(2024, mes, dia);
    return bissexto.month == mes ? bissexto : null;
  }
}

/// O texto de trás de um destaque, carregado sob demanda como o versículo no
/// cartão da Bíblia: a lista não traz todos os livros para a memória de uma
/// vez. Vazio quando o texto não existe mais (livro encurtado, data inválida).
Future<String> textoDoDestaque(DestaqueDeLivro destaque) async {
  if (ehSlugDeDevocional(destaque.slug)) {
    final data = OrigemDoDestaque.dataDoDestaque(destaque);
    if (data == null) return '';
    final dev = switch (leituraDoSlug(destaque.slug)) {
      'manha' => await Conteudo.instancia.devocional(data, Periodo.manha),
      'noite' => await Conteudo.instancia.devocional(data, Periodo.noite),
      _ => await Conteudo.instancia.promessa(data),
    };
    return dev?.texto ?? '';
  }
  final capitulos = await Biblioteca.instancia.capitulos(destaque.slug);
  if (capitulos == null ||
      destaque.capitulo >= capitulos.length ||
      destaque.paragrafo >= capitulos[destaque.capitulo].paragrafos.length) {
    return '';
  }
  return capitulos[destaque.capitulo].paragrafos[destaque.paragrafo];
}
