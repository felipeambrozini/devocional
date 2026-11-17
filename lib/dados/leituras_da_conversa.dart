import 'conteudo.dart';
import 'modelos.dart';
import 'registro.dart';

/// As leituras de Spurgeon que o próprio app traz (Manhã e Noite e Promessas
/// de Deus), anexadas à instrução de sistema do chat para as personas
/// falarem do texto exato em vez de lembrá-lo de memória.
///
/// Sempre entram as três leituras de hoje: quem acabou de ler o devocional
/// e abre o chat pergunta dele. Quando a pergunta vem no formato da Seção 7
/// das instruções do Felipe (`Data | Tipo | Versículo`), entram também as
/// leituras daquela data, que são a base da descrição do YouTube.
enum LeituraDoDia {
  manha('Manhã e Noite, leitura da Manhã'),
  noite('Manhã e Noite, leitura da Noite'),
  promessa('Promessas de Deus');

  const LeituraDoDia(this.rotulo);

  final String rotulo;
}

/// A data e as leituras pedidas numa linha `dd/mm | Tipo | Referência` (o
/// ano é opcional). "Manhã" e "Noite" pedem a leitura do período, "Dia" (ou
/// "Devocional do Dia") as duas, e qualquer outro texto no meio é o título de
/// uma promessa (o formato de Promessas de Deus). null sem essa linha ou com
/// data que não existe.
({DateTime data, Set<LeituraDoDia> leituras})? leituraPedida(String pergunta) {
  final achado = _linhaDeDevocional.firstMatch(pergunta);
  if (achado == null) return null;
  final dia = int.parse(achado.group(1)!);
  final mes = int.parse(achado.group(2)!);
  // Sem ano informado vale um ano bissexto: 29/02 existe em Manhã e Noite, e
  // num ano comum o DateTime o empurraria para 1 de março.
  final ano = _ano(achado.group(3)) ?? 2024;
  final data = DateTime(ano, mes, dia);
  if (data.month != mes || data.day != dia) return null;

  final tipo = Conteudo.normalizar(achado.group(4)!.trim());
  final leituras = switch (tipo) {
    _ when tipo.startsWith('manha') => {LeituraDoDia.manha},
    _ when tipo.startsWith('noite') => {LeituraDoDia.noite},
    _ when tipo == 'dia' || tipo.startsWith('devocional do dia') => {
      LeituraDoDia.manha,
      LeituraDoDia.noite,
    },
    _ => {LeituraDoDia.promessa},
  };
  return (data: data, leituras: leituras);
}

final _linhaDeDevocional = RegExp(
  r'(\d{1,2})\s*/\s*(\d{1,2})(?:\s*/\s*(\d{2,4}))?\s*\|\s*([^|\n]+?)\s*\|',
);

int? _ano(String? texto) {
  if (texto == null) return null;
  final ano = int.parse(texto);
  return ano < 100 ? 2000 + ano : ano;
}

/// O bloco de leituras para o sistema, ou null se nada carregar (asset
/// quebrado, teste sem binding): a conversa segue sem ele, nunca falha por
/// causa dele.
Future<String?> leiturasDaConversa(String pergunta, DateTime agora) async {
  try {
    final blocos = [
      await _leituras(agora, 'Hoje', LeituraDoDia.values.toSet()),
    ];
    final pedida = leituraPedida(pergunta);
    if (pedida != null &&
        Conteudo.chaveDoDia(pedida.data) != Conteudo.chaveDoDia(agora)) {
      blocos.add(
        await _leituras(
          pedida.data,
          'Data pedida na mensagem',
          pedida.leituras,
        ),
      );
    }
    final texto = blocos.where((b) => b.isNotEmpty).join('\n\n');
    return texto.isEmpty ? null : texto;
  } catch (erro, pilha) {
    Registro.esperado('LeiturasDaConversa', erro, pilha);
    return null;
  }
}

Future<String> _leituras(
  DateTime data,
  String quando,
  Set<LeituraDoDia> leituras,
) async {
  final dia = '${data.day} de ${_meses[data.month - 1]}';
  final partes = <String>[];
  for (final leitura in LeituraDoDia.values) {
    if (!leituras.contains(leitura)) continue;
    final devocional = switch (leitura) {
      LeituraDoDia.manha => await Conteudo.instancia.devocional(
        data,
        Periodo.manha,
      ),
      LeituraDoDia.noite => await Conteudo.instancia.devocional(
        data,
        Periodo.noite,
      ),
      LeituraDoDia.promessa => await Conteudo.instancia.promessa(data),
    };
    if (devocional == null) continue;
    partes.add(
      [
        '### ${leitura.rotulo}, $dia ($quando)',
        if (devocional.titulo.isNotEmpty) 'Título: ${devocional.titulo}',
        devocional.versiculo.isEmpty
            ? 'Referência: ${devocional.referencia}'
            : 'Versículo: ${devocional.versiculo} (${devocional.referencia})',
        devocional.texto,
      ].join('\n'),
    );
  }
  return partes.join('\n\n');
}

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
