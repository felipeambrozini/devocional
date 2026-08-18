import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
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

  /// O nome completo da leitura, para títulos de cartão: "Devocional da
  /// manhã" em vez do rótulo curto de chip "Manhã". Chips e títulos falam do
  /// mesmo conceito com o mesmo substantivo; a diferença é só a forma.
  String get tituloCompleto => switch (this) {
    Leitura.manha => 'Devocional da manhã',
    Leitura.noite => 'Devocional da noite',
    Leitura.promessas => 'Promessas de Deus',
  };

  /// Manhã e Noite têm período; Promessas não, por ser leitura única do dia.
  Periodo? get periodo => switch (this) {
    Leitura.manha => Periodo.manha,
    Leitura.noite => Periodo.noite,
    Leitura.promessas => null,
  };

  String get capa => this == Leitura.promessas
      ? 'assets/images/capa_promessas_de_deus.webp'
      : 'assets/images/capa_manha_e_noite.webp';

  /// A aba inicial segue o horário do aparelho. Ver [Periodo.pelaHora].
  static Leitura pelaHora(int hora) =>
      Periodo.pelaHora(hora) == Periodo.manha ? Leitura.manha : Leitura.noite;
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

  @override
  void initState() {
    super.initState();
    _data = widget.dataInicial ?? DateTime.now();
    _leitura = widget.leituraInicial ?? Leitura.pelaHora(DateTime.now().hour);
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

  Future<Devocional?> _carregar(Versao versao) {
    final periodo = _leitura.periodo;
    return periodo == null
        ? Conteudo.instancia.promessa(_data, versao: versao)
        : Conteudo.instancia.devocional(_data, periodo, versao: versao);
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final ehHoje = _data.month == hoje.month && _data.day == hoje.day;
    final estado = EscopoDoEstado.de(context);
    // Em tela estreita os balões de conversa moram embaixo, na base da tela;
    // o fim da lista precisa de folga para a última linha não ficar atrás
    // deles. Em tela larga os balões ficam fora da coluna de leitura.
    final protegerDosBaloes =
        estado.baloesVisiveis && MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ehHoje ? 'Hoje, ${dataLonga(_data)}' : dataLonga(_data),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Tamanho do texto e aparência',
            icon: const Icon(Icons.tune),
            onPressed: () => ajustesDeLeitura(context, estado),
          ),
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
      body: LarguraDeLeitura(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            protegerDosBaloes ? folgaDosBaloes : 32,
          ),
          children: [
            _AlternadorDeLeitura(
              atual: _leitura,
              ao: (l) => setState(() => _leitura = l),
            ),
            const SizedBox(height: 16),
            BotaoDeVoz(
              chave: 'devocional:${_data.month}/${_data.day}',
              texto: _leitura == Leitura.promessas
                  ? 'Promessa para ${dataLonga(_data)}'
                  : 'Devocional para ${dataLonga(_data)}',
              referencia: _leitura == Leitura.promessas
                  ? 'Promessa de Deus'
                  : '${_leitura.rotulo.toLowerCase()}_${_data.month}_${_data.day}',
            ),
            CarregaUmaVez<Devocional?>(
              chave:
                  '${_leitura.name}/${estado.versao.pasta}/${_data.month}/${_data.day}',
              carregar: () => _carregar(estado.versao),
              construir: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: AvisoDeErro(),
                  );
                }
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
                          ? 'Ainda não há uma promessa cadastrada para esta data.'
                          : 'Sem devocional para esta data.',
                    ),
                  );
                }
                final referencias = [
                  dev.referencia,
                  for (final (referencia, _) in dev.outrosVersiculos)
                    referencia,
                ].join(', ');
                final livros = livrosDaReferencia(referencias);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final livro in livros)
                      AberturaDeLivro(slug: livro.slug),
                    _CartaoDeLeitura(
                      titulo: dev.titulo.isNotEmpty
                          ? dev.titulo
                          : '${_leitura.tituloCompleto}, ${dataLonga(_data)}',
                      dev: dev,
                      texto: dev.texto,
                      capa: _leitura.capa,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
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
          ),
      ],
    );
  }
}

class _CartaoDeLeitura extends StatelessWidget {
  const _CartaoDeLeitura({
    required this.titulo,
    required this.dev,
    required this.texto,
    this.capa,
  });

  final String titulo;

  /// De onde vêm o(s) versículo(s)-base em destaque.
  final Devocional dev;
  final String texto;

  /// Capa do livro de onde a leitura vem, para dar identidade ao cartão.
  final String? capa;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final spans = spansDeCitacao(
      dev,
      estiloCitacao: tema.bodyLarge?.copyWith(
        height: 1.7,
        fontStyle: FontStyle.italic,
        color: cor.secondary,
      ),
      estiloReferencia: tema.titleSmall?.copyWith(color: cor.secondary),
    );
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
                  child: Image.asset(
                    capa!,
                    height: alturaCapa(context, 130),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
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
                    // seguida da atribuição. Mais de uma linha no raro dia com
                    // mais de um versículo-base.
                    if (spans.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text.rich(TextSpan(children: spans)),
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
            child: Image.asset(
              'assets/images/assinatura_spurgeon.webp',
              height: 40,
              semanticLabel: 'Assinatura de Charles Spurgeon',
              // A imagem é tinta chapada num tom só, o próprio dourado claro do
              // tema escuro, e sobre pergaminho ela sumiria. Como é de uma cor
              // só, tingir o mesmo arquivo pelo tema resolve, e evita ter duas
              // versões do asset para manter em sincronia.
              color: cor.secondary,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}
