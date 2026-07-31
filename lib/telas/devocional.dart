import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'comuns.dart';

/// As três leituras diárias, na ordem em que aparecem no alternador do topo.
///
/// Manhã e Noite vêm do devocional de mesmo nome; Promessas de Deus é obra
/// separada, e por isso a aba do meio busca em outro asset.
enum Leitura {
  manha('Manhã'),
  promessas('Promessas de Deus'),
  noite('Noite');

  const Leitura(this.rotulo);

  final String rotulo;

  /// Manhã e Noite têm período; Promessas não, por ser leitura única do dia.
  Periodo? get periodo => switch (this) {
        Leitura.manha => Periodo.manha,
        Leitura.noite => Periodo.noite,
        Leitura.promessas => null,
      };

  String get capa => this == Leitura.promessas
      ? 'assets/images/capa_promessas_de_deus.png'
      : 'assets/images/capa_manha_e_noite.png';

  /// A aba inicial segue o sol do lugar, com o horário fixo como recurso.
  /// Ver [Periodo.peloSol].
  static Leitura peloSol(DateTime momento, (double, double)? lugar) =>
      Periodo.peloSol(momento, lugar) == Periodo.manha
          ? Leitura.manha
          : Leitura.noite;
}

/// Manhã e Noite e Promessas de Deus, com calendário para escolher a data.
class TelaDevocional extends StatefulWidget {
  const TelaDevocional({super.key, this.dataInicial, this.leituraInicial});

  final DateTime? dataInicial;
  final Leitura? leituraInicial;

  @override
  State<TelaDevocional> createState() => _TelaDevocionalState();
}

class _TelaDevocionalState extends State<TelaDevocional> {
  late DateTime _data;
  late Leitura _leitura;
  bool _abaEscolhida = false;

  @override
  void initState() {
    super.initState();
    _data = widget.dataInicial ?? DateTime.now();
  }

  /// A aba de abertura depende do lugar guardado no estado, que só está
  /// acessível daqui. Roda uma vez: depois disso quem manda é o toque do leitor.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_abaEscolhida) return;
    _abaEscolhida = true;
    _leitura = widget.leituraInicial ??
        Leitura.peloSol(DateTime.now(), EscopoDoEstado.de(context).lugar);
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      // O devocional é anual e se repete, então a janela é só um intervalo
      // confortável para navegar, não um limite de conteúdo.
      firstDate: DateTime(_data.year - 5),
      lastDate: DateTime(_data.year + 5, 12, 31),
      helpText: 'Escolha a data do devocional',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<Devocional?> _carregar() {
    final periodo = _leitura.periodo;
    return periodo == null
        ? Conteudo.instancia.promessa(_data)
        : Conteudo.instancia.devocional(_data, periodo);
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final ehHoje = _data.month == hoje.month && _data.day == hoje.day;

    return Scaffold(
      appBar: AppBar(
        title: Text(ehHoje ? 'Hoje, ${dataLonga(_data)}' : dataLonga(_data)),
        actions: [
          IconButton(
            tooltip: 'Escolher data',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _escolherData,
          ),
          if (!ehHoje)
            IconButton(
              tooltip: 'Voltar para hoje',
              icon: const Icon(Icons.today_outlined),
              onPressed: () => setState(() => _data = DateTime.now()),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _AlternadorDeLeitura(
            atual: _leitura,
            ao: (l) => setState(() => _leitura = l),
          ),
          const SizedBox(height: 16),
          CarregaUmaVez<Devocional?>(
            chave: '${_leitura.name}/${_data.month}/${_data.day}',
            carregar: _carregar,
            construir: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final dev = snap.data;
              if (dev == null) {
                return Cartao(
                  titulo: _leitura.rotulo,
                  child: Text(
                    _leitura == Leitura.promessas
                        ? 'O texto de Promessas de Deus ainda não foi carregado. '
                            'Assim que o arquivo entrar em '
                            'assets/devotional/promises.json, a promessa do dia '
                            'aparece aqui.'
                        : 'Sem devocional para esta data.',
                  ),
                );
              }
              final livros = livrosDaReferencia(dev.referencia);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final livro in livros) AberturaDeLivro(slug: livro.slug),
                  _CartaoDeLeitura(
                    titulo: dev.titulo.isNotEmpty
                        ? dev.titulo
                        : '${_leitura.rotulo}, ${dataLonga(_data)}',
                    referencia: dev.referencia,
                    versiculo: dev.versiculo,
                    texto: dev.texto,
                    capa: _leitura.capa,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Alternador das três leituras, centralizado.
///
/// Chips e não SegmentedButton: o SegmentedButton iguala a largura de todos os
/// segmentos à do maior, então três vezes "Promessas de Deus" nunca cabe num
/// celular e o rótulo aparecia cortado. Cada chip se dimensiona pelo próprio
/// texto, e o Wrap passa para uma segunda linha em telas muito estreitas em
/// vez de cortar.
class _AlternadorDeLeitura extends StatelessWidget {
  const _AlternadorDeLeitura({required this.atual, required this.ao});

  final Leitura atual;
  final ValueChanged<Leitura> ao;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final l in Leitura.values)
          ChoiceChip(
            label: Text(l.rotulo, maxLines: 1),
            selected: l == atual,
            onSelected: (_) => ao(l),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _CartaoDeLeitura extends StatelessWidget {
  const _CartaoDeLeitura({
    required this.titulo,
    required this.referencia,
    required this.texto,
    this.versiculo = '',
    this.capa,
  });

  final String titulo;
  final String referencia;

  /// A promessa em destaque, quando a leitura a traz separada do comentário.
  final String versiculo;
  final String texto;

  /// Capa do livro de onde a leitura vem, para dar identidade ao cartão.
  final String? capa;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Cartao(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (capa != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(capa!, height: 62, fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: tema.headlineMedium),
                    // A citação vem alinhada embaixo do título, não embaixo da
                    // capa, e o nome do livro fica ao lado do fim da citação
                    // (não numa linha própria embaixo), como uma epígrafe
                    // seguida da atribuição.
                    if (versiculo.isNotEmpty || referencia.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (versiculo.isNotEmpty)
                              TextSpan(
                                text: '"$versiculo" ',
                                style: tema.bodyLarge?.copyWith(
                                  height: 1.7,
                                  fontStyle: FontStyle.italic,
                                  color: Cores.douradoClaro,
                                ),
                              ),
                            if (referencia.isNotEmpty)
                              TextSpan(
                                text: referencia.toUpperCase(),
                                style: tema.titleSmall?.copyWith(color: Cores.douradoClaro),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // A linha dourada só separa a citação do comentário, por isso vem
          // depois dela, não antes.
          const Filete(),
          const SizedBox(height: 14),
          Text(texto, style: tema.bodyLarge?.copyWith(height: 1.7)),
          const SizedBox(height: 8),
          Center(
            child: Image.asset('assets/images/assinatura_spurgeon.png', height: 40),
          ),
        ],
      ),
    );
  }
}


