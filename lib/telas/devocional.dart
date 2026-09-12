import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controladores/devocional_controlador.dart';
import '../dados/canon.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/voz.dart';
import '../estilo/espacamento.dart';
import '../funcoes/datas.dart';
import '../widgets/widgets.dart';

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
      ? 'assets/imagens/capa_promessas_de_deus.webp'
      : 'assets/imagens/capa_manha_e_noite.webp';

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
  late final _controller = DevocionalControlador(
    dataInicial: widget.dataInicial,
    leituraInicial: widget.leituraInicial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TelaDevocional anterior) {
    super.didUpdateWidget(anterior);
    // O go_router chaveia a página de uma rota pelo caminho, sem os
    // parâmetros: ir de /manha a /manha?data=... atualiza o widget no lugar,
    // e o initState não roda de novo. Quem recolhe a data nova da URL é o
    // controller — sem isto, o calendário escrevia a URL mas a tela não mudava.
    _controller.atualizarSeMudou(
      dataInicial: widget.dataInicial,
      leituraInicial: widget.leituraInicial,
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final hoje = DateTime.now();
        final ehHoje = _controller.ehHoje(hoje);
        final data = _controller.data;
        final leitura = _controller.leitura;

        return Scaffold(
          appBar: DevocionalAppBar(
            title: Text(
              ehHoje ? 'Hoje, ${dataLonga(data)}' : dataLonga(data),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Buscar',
                icon: const FaIcon(FontAwesomeIcons.magnifyingGlass),
                onPressed: () => _controller.abrirBusca(context),
              ),
              PopupMenuButton<String>(
                tooltip: 'Mais opções',
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
                onSelected: (valor) {
                  switch (valor) {
                    case 'data':
                      _controller.escolherData(context);
                    case 'hoje':
                      _controller.irPara(context, leitura, hoje);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'data',
                    child: DevocionalItemDeMenu(
                      icone: FontAwesomeIcons.calendarDays,
                      rotulo: 'Escolher data',
                    ),
                  ),
                  if (!ehHoje)
                    const PopupMenuItem(
                      value: 'hoje',
                      child: DevocionalItemDeMenu(
                        icone: FontAwesomeIcons.calendarCheck,
                        rotulo: 'Voltar para hoje',
                      ),
                    ),
                ],
              ),
              DevocionalBotaoDeAjustes(estado: estado),
            ],
          ),
          body: DevocionalLarguraDeLeitura(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DevocionalEspacamento.sp16,
                DevocionalEspacamento.sp8,
                DevocionalEspacamento.sp16,
                DevocionalEspacamento.sp32,
              ),
              children: [
                if (!ehHoje)
                  Padding(
                    padding: const EdgeInsets.only(bottom: DevocionalEspacamento.sp12),
                    child: Center(
                      child: DevocionalBotaoTerciario.icon(
                        onPressed: () => _controller.irPara(context, leitura, hoje),
                        icon: const FaIcon(FontAwesomeIcons.calendarCheck, size: 14),
                        label: const Text('Voltar para hoje'),
                      ),
                    ),
                  ),
                DevocionalAlternadorDeLeitura(
                  atual: leitura,
                  ao: (l) => _controller.irPara(context, l, data),
                ),
                const SizedBox(height: DevocionalEspacamento.sp16),
                DevocionalCarregaUmaVez<Devocional?>(
                  chave: '${leitura.name}/${data.month}/${data.day}',
                  carregar: _controller.carregar,
                  construir: (context, snap) {
                    if (snap.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(DevocionalEspacamento.sp32),
                        child: DevocionalAvisoDeErro(),
                      );
                    }
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(DevocionalEspacamento.sp32),
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
                        padding: EdgeInsets.all(DevocionalEspacamento.sp32),
                        child: DevocionalAvisoDeErro(),
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
                          DevocionalAberturaDeLivro(slug: livro.slug),
                        DevocionalCartaoDeLeitura(
                          titulo: dev.titulo.isNotEmpty
                              ? dev.titulo
                              : '${leitura.tituloCompleto}, ${dataLonga(data)}',
                          dev: dev,
                          texto: dev.texto,
                          capa: leitura.capa,
                          // A chave leva a leitura junto: Manhã e Noite do mesmo
                          // dia são leituras diferentes, e a cache não pode
                          // confundi-las numa só.
                          vozChave: chaveDeDevocional(
                            leitura.name,
                            data.day,
                            data.month,
                          ),
                          vozReferencia: dev.referencia.isNotEmpty
                              ? dev.referencia
                              : leitura.rotulo,
                          link: _controller.linkDaLeitura(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
