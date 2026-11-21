import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/datas.dart';
import '../telas/devocional.dart';
import 'aviso_vazio.dart';
import 'item_de_achado.dart';

class DevocionalAbaDevocionais extends StatefulWidget {
  const DevocionalAbaDevocionais({
    super.key,
    required this.termoBuscado,
    required this.achados,
    required this.buscando,
    required this.erro,
    required this.aoTentarDeNovo,
  });

  final String termoBuscado;
  final List<AchadoDevocional> achados;
  final bool buscando;
  final bool erro;
  final VoidCallback aoTentarDeNovo;

  @override
  State<DevocionalAbaDevocionais> createState() =>
      _DevocionalAbaDevocionaisState();
}

class _DevocionalAbaDevocionaisState extends State<DevocionalAbaDevocionais> {
  /// A data digitada e a leitura escolhida são campos de estado, e não a
  /// leitura de um controlador dentro de um getter: com o controlador, cada
  /// tecla-digitada era um `setState` sem nome, e o filtro inteiro rodava a
  /// cada caractere sem nada mudar de fato.
  String _data = '';
  String? _filtroDeLeitura;

  List<AchadoDevocional> get _filtrados {
    return widget.achados.where((a) {
      if (_filtroDeLeitura != null && a.leitura != _filtroDeLeitura) {
        return false;
      }
      if (_data.isNotEmpty && !a.data.contains(_data)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.erro) {
      return DevocionalAvisoDeErro(
        detalhe: 'A busca falhou. Tente de novo.',
        aoTentarDeNovo: widget.aoTentarDeNovo,
      );
    }
    if (widget.termoBuscado.isEmpty) {
      return const DevocionalAvisoVazio(
        icone: FontAwesomeIcons.bookOpen,
        titulo: 'Busque nos devocionais',
        detalhe: 'Manhã e Noite e Promessas de Deus, na voz de Spurgeon',
      );
    }
    final lista = _filtrados;
    final espaco = const EdgeInsets.fromLTRB(
      DevocionalEspacamento.sp16,
      0,
      DevocionalEspacamento.sp16,
      DevocionalEspacamento.sp8,
    );

    // Contagem, data e chips rolam junto com a lista: fixos em cima, com o
    // teclado aberto para digitar a data, sobrava pouco ou nada para os
    // resultados num celular pequeno. E o "Nada encontrado" mora dentro da
    // rolagem, abaixo dos filtros: antes ele trocava a aba inteira, e quem
    // zerava a lista com um chip ou uma data não tinha como voltar.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: espaco,
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${lista.length} ${lista.length == 1 ? 'resultado' : 'resultados'}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                const SizedBox(width: DevocionalEspacamento.sp10),
                if (widget.buscando)
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Carregando',
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: espaco,
          sliver: SliverToBoxAdapter(
            child: TextField(
              onChanged: (valor) {
                final data = valor.trim();
                if (data == _data) return;
                setState(() => _data = data);
              },
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Data (DD-MM)',
                // Centrado numa caixa de 48, como o da busca: o FaIcon solto
                // ficava preso no canto de cima do campo.
                prefixIcon: SizedBox(
                  width: kMinInteractiveDimension,
                  child: Center(
                    child: FaIcon(FontAwesomeIcons.calendarDays, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Chips e não DropdownButton: o menu do dropdown abria com sombra
        // preta (elevação 8 fixa do SDK) e um fio cinza embaixo, fora da Regra
        // do Chapado e da Regra do Fio. Os chips são o mesmo controle do
        // alternador de leitura e deixam as quatro opções à vista. O rótulo
        // quebra em duas linhas em vez de sumir aos poucos com fonte grande.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DevocionalEspacamento.sp16,
            0,
            DevocionalEspacamento.sp16,
            DevocionalEspacamento.sp12,
          ),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              container: true,
              label: 'Filtrar por leitura',
              child: Wrap(
                spacing: DevocionalEspacamento.sp8,
                runSpacing: DevocionalEspacamento.sp8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _filtroDeLeitura == null,
                    onSelected: (_) => setState(() => _filtroDeLeitura = null),
                  ),
                  for (final l in Leitura.values)
                    ChoiceChip(
                      label: Text(l.rotulo, softWrap: true, maxLines: 2),
                      selected: _filtroDeLeitura == l.name,
                      onSelected: (_) =>
                          setState(() => _filtroDeLeitura = l.name),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (lista.isEmpty && !widget.buscando)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DevocionalAvisoVazio(
              icone: FontAwesomeIcons.magnifyingGlassMinus,
              titulo: 'Nada encontrado',
              detalhe: switch ((_filtroDeLeitura != null, _data.isNotEmpty)) {
                (true, true) =>
                  'Nenhum devocional com "${widget.termoBuscado}" nesse '
                      'filtro. Toque em Todas ou apague a data.',
                (true, false) =>
                  'Nenhum devocional com "${widget.termoBuscado}" nesta '
                      'leitura. Toque em Todas para ver as outras.',
                (false, true) =>
                  'Nenhum devocional com "${widget.termoBuscado}" nesta '
                      'data. Apague a data para ver os outros dias.',
                (false, false) =>
                  'Nenhum devocional com "${widget.termoBuscado}"',
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DevocionalEspacamento.sp16,
              0,
              DevocionalEspacamento.sp16,
              DevocionalEspacamento.sp32,
            ),
            sliver: SliverList.separated(
              itemCount: lista.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: DevocionalEspacamento.sp18),
              itemBuilder: (context, i) => _item(context, lista[i]),
            ),
          ),
      ],
    );
  }

  Widget _item(BuildContext context, AchadoDevocional achado) {
    final leitura = Leitura.values.byName(achado.leitura);
    final data = _dataDoDevocional(achado.data);
    return DevocionalItemDeAchado(
      titulo: '${leitura.rotulo} · ${dataLonga(data)}',
      subtitulo: achado.titulo,
      texto: achado.texto,
      termo: widget.termoBuscado,
      aoAbrir: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TelaDevocional(dataInicial: data, leituraInicial: leitura),
        ),
      ),
    );
  }
}

/// Uma data qualquer, só para navegar até o dia certo do devocional: os
/// assets são anuais e a chave 'DD-MM' não guarda ano. 2024 é bissexto de
/// propósito: sem isso, '29-02' normalizaria sozinho para 1º de março (ver
/// `test/bissexto_test.dart`) e a busca levaria para o dia errado, calada.
DateTime _dataDoDevocional(String chave) {
  final partes = chave.split('-');
  return DateTime(2024, int.parse(partes[1]), int.parse(partes[0]));
}
