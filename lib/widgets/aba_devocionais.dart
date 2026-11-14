import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import 'aviso_vazio.dart';
import 'erro_de_busca.dart';
import 'item_de_achado_devocional.dart';

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
      return DevocionalErroDeBusca(aoTentarDeNovo: widget.aoTentarDeNovo);
    }
    if (widget.termoBuscado.isEmpty) {
      return const DevocionalAvisoVazio(
        icone: FontAwesomeIcons.bookOpen,
        titulo: 'Busque nos devocionais',
        detalhe: 'Manhã e Noite e Promessas de Deus, na voz de Spurgeon.',
      );
    }
    final lista = _filtrados;
    if (lista.isEmpty && !widget.buscando) {
      return DevocionalAvisoVazio(
        icone: FontAwesomeIcons.magnifyingGlassMinus,
        titulo: 'Nada encontrado',
        detalhe: 'Nenhum devocional com "${widget.termoBuscado}".',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DevocionalEspacamento.sp16,
            0,
            DevocionalEspacamento.sp16,
            DevocionalEspacamento.sp8,
          ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DevocionalEspacamento.sp16,
            0,
            DevocionalEspacamento.sp16,
            DevocionalEspacamento.sp8,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (valor) {
                    final data = valor.trim();
                    if (data == _data) return;
                    setState(() => _data = data);
                  },
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Data (DD-MM)',
                    prefixIcon: FaIcon(FontAwesomeIcons.calendarDays, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: DevocionalEspacamento.sp8),
              Semantics(
                label: 'Filtrar por leitura',
                child: DropdownButton<String?>(
                  value: _filtroDeLeitura,
                  hint: const Text('Leitura'),
                  onChanged: (v) => setState(() => _filtroDeLeitura = v),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    const DropdownMenuItem(
                      value: 'manha',
                      child: Text('Manhã'),
                    ),
                    const DropdownMenuItem(
                      value: 'noite',
                      child: Text('Noite'),
                    ),
                    const DropdownMenuItem(
                      value: 'promessas',
                      child: Text('Promessas'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              DevocionalEspacamento.sp16,
              0,
              DevocionalEspacamento.sp16,
              DevocionalEspacamento.sp32,
            ),
            itemCount: lista.length,
            separatorBuilder: (_, _) =>
                const Divider(height: DevocionalEspacamento.sp18),
            itemBuilder: (context, i) => DevocionalItemDeAchadoDevocional(
              achado: lista[i],
              termo: widget.termoBuscado,
            ),
          ),
        ),
      ],
    );
  }
}
