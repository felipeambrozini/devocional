import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/voz.dart';
import '../estilo/spacing.dart';
import '../funcoes/capa_biblia.dart';
import '../funcoes/citacao.dart';
import '../funcoes/datas.dart';
import '../widgets/widgets.dart';
import 'biblia.dart';
import 'busca.dart';

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

  @override
  void didUpdateWidget(TelaDevocional anterior) {
    super.didUpdateWidget(anterior);
    // O go_router chaveia a página de uma rota pelo caminho, sem os
    // parâmetros: ir de /manha a /manha?data=... atualiza o widget no lugar,
    // e o initState não roda de novo. Quem recolhe a data nova da URL é este
    // método — sem ele, o calendário escrevia a URL mas a tela não mudava.
    final novaData = widget.dataInicial ?? DateTime.now();
    final novaLeitura = widget.leituraInicial ?? _leitura;
    if (novaLeitura == _leitura && _mesmoDia(novaData, _data)) return;
    setState(() {
      _data = novaData;
      _leitura = novaLeitura;
    });
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
    if (escolhida != null) _irPara(_leitura, escolhida);
  }

  /// A busca abre na aba de devocionais: quem pesquisa daqui procura
  /// devocional, não versículo.
  void _abrirBusca() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const TelaBusca(abaInicial: AbaDaBusca.devocionais),
    ),
  );

  /// Navega para a leitura com a data na URL (`/manha?data=AAAA-MM-DD`):
  /// o chip, o calendário e o "voltar para hoje" escrevem a URL, e a rota
  /// (main.dart) reconstrói a tela com `dataInicial`. A data de hoje não
  /// aparece na URL de propósito, para o link continuar limpo.
  void _irPara(Leitura leitura, DateTime data) {
    if (leitura == _leitura && _mesmoDia(data, _data)) return;
    GoRouter.of(context).go('/${leitura.name}${_parametroDeData(data)}');
  }

  /// `?data=AAAA-MM-DD`, ou vazio no dia de hoje — para a URL de hoje
  /// continuar limpa, na navegação (`_irPara`) e no link de [_linkDaLeitura].
  static String _parametroDeData(DateTime data) =>
      _mesmoDia(data, DateTime.now()) ? '' : '?data=${_formatoDeData(data)}';

  /// Link absoluto da leitura atual, o mesmo caminho que main.dart declara
  /// para cada leitura (`/manha`, `/noite`, `/promessas`): quem abre o link
  /// cai direto nela. Vai no texto de Compartilhar do cartão.
  String _linkDaLeitura() =>
      '$enderecoDoSite${_leitura.name}${_parametroDeData(_data)}';

  /// O ano entra na comparação: a data da URL é completa, e "19 de agosto"
  /// de um ano não é o mesmo dia de outro. Sem ele, escolher no calendário o
  /// mesmo dia e mês de um ano diferente não navegava, e a tela ficava presa.
  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatoDeData(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<Devocional?> _carregar() {
    final periodo = _leitura.periodo;
    return periodo == null
        ? Conteudo.instancia.promessa(_data)
        : Conteudo.instancia.devocional(_data, periodo);
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final ehHoje = _mesmoDia(_data, hoje);
    final estado = EscopoDoEstado.de(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ehHoje ? 'Hoje, ${dataLonga(_data)}' : dataLonga(_data),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: _abrirBusca,
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
              onPressed: () => _irPara(_leitura, DateTime.now()),
            ),
          IconButton(
            tooltip: 'Tamanho do texto e aparência',
            icon: const Icon(Icons.tune),
            onPressed: () => ajustesDeLeitura(context, estado),
          ),
        ],
      ),
      body: LarguraDeLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sp16,
            Spacing.sp8,
            Spacing.sp16,
            Spacing.sp32,
          ),
          children: [
            _AlternadorDeLeitura(atual: _leitura, ao: (l) => _irPara(l, _data)),
            const SizedBox(height: Spacing.sp16),
            CarregaUmaVez<Devocional?>(
              chave: '${_leitura.name}/${_data.month}/${_data.day}',
              carregar: _carregar,
              construir: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(Spacing.sp32),
                    child: AvisoDeErro(),
                  );
                }
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(Spacing.sp32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final dev = snap.data;
                if (dev == null) {
                  // Os três corpora cobrem 366/366 dias (verificado pelos
                  // testes de conteúdo) e falha de carga já virou o hasError
                  // acima. Chegar aqui é asset corrompido ou incompleto:
                  // falha de conteúdo, não dia vazio.
                  return const Padding(
                    padding: EdgeInsets.all(Spacing.sp32),
                    child: AvisoDeErro(),
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
                      // A chave leva a leitura junto: Manhã e Noite do mesmo
                      // dia são leituras diferentes, e a cache não pode
                      // confundi-las numa só.
                      vozChave: chaveDeDevocional(
                        _leitura.name,
                        _data.day,
                        _data.month,
                      ),
                      vozReferencia: dev.referencia.isNotEmpty
                          ? dev.referencia
                          : _leitura.rotulo,
                      link: _linkDaLeitura(),
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
      spacing: Spacing.sp8,
      runSpacing: Spacing.sp8,
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
    required this.vozChave,
    required this.vozReferencia,
    required this.link,
  });

  final String titulo;

  /// De onde vêm o(s) versículo(s)-base em destaque.
  final Devocional dev;
  final String texto;

  /// Capa do livro de onde a leitura vem, para dar identidade ao cartão.
  final String? capa;

  /// O que a voz de Spurgeon lê: chave do áudio e referência.
  final String vozChave;
  final String vozReferencia;

  /// Link absoluto da leitura, para o fim do texto de Compartilhar — é como
  /// quem recebe chega direto nela, mesmo fora do app.
  final String link;

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
      // A epígrafe é a porta do devocional para o texto da BKJ: tocar na
      // referência abre o capítulo com os versículos citados em destaque.
      aoAbrirReferencia: (livro, capitulo, deVersiculo, ateVersiculo) =>
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaBiblia(
                livroInicial: livro.slug,
                capituloInicial: capitulo,
                destacar: (deVersiculo, ateVersiculo),
              ),
            ),
          ),
    );
    return Cartao(
      padding: const EdgeInsets.all(Spacing.sp20),
      // Igual à Bíblia: o texto vira selecionável e copiável, e "Compartilhar"
      // entra no próprio menu de seleção. Ver AreaDeSelecaoComCompartilhar.
      child: AreaDeSelecaoComCompartilhar(
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
                  const SizedBox(width: Spacing.sp14),
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
                        const SizedBox(height: Spacing.sp10),
                        Text.rich(TextSpan(children: spans)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp14),
            // A linha dourada só separa a citação do comentário, por isso vem
            // depois dela, não antes.
            const Filete(),
            const SizedBox(height: Spacing.sp14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BotaoDeVoz(chave: vozChave, referencia: vozReferencia),
                IconButton(
                  tooltip: 'Compartilhar',
                  icon: Icon(Icons.ios_share_outlined, color: cor.primary),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: _textoParaCompartilhar),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp14),
            Text(texto, style: tema.bodyLarge?.copyWith(height: 1.7)),
            const SizedBox(height: Spacing.sp8),
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
      ),
    );
  }

  /// Título, citação e comentário do cartão, terminando no link da leitura —
  /// o mesmo texto que a tela mostra, pronto para sair do app.
  String get _textoParaCompartilhar => [
    titulo,
    textoDeCitacao(dev),
    texto,
    link,
  ].where((parte) => parte.isNotEmpty).join('\n\n');
}
