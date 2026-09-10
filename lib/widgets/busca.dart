import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// O campo de busca usado em toda tela do app: mesma lupa, mesmo
/// espaçamento, mesmo padrão de limpar/buscar — sem isto, cada tela
/// reescrevia o próprio `TextField`, e um ajuste (como o espaçamento da
/// lupa) tinha de ser repetido em todo lugar que tinha um.
class DevocionalBusca extends StatelessWidget {
  const DevocionalBusca({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.autofocus = false,
    this.aoBuscar,
    this.aoLimpar,
    this.border,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  /// Quando definido, mostra a seta de busca (e a tecla Enter também busca)
  /// — telas que só filtram a lista ao digitar deixam isto de fora.
  final VoidCallback? aoBuscar;

  /// Quando definido, mostra o X de limpar assim que há texto no campo.
  final VoidCallback? aoLimpar;

  final InputBorder? border;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: aoBuscar == null
          ? TextInputAction.done
          : TextInputAction.search,
      onSubmitted: aoBuscar == null ? null : (_) => aoBuscar!(),
      decoration: InputDecoration(
        hintText: hintText,
        border: border,
        // SizedBox do tamanho do alvo de toque do IconButton do sufixo: sem
        // isto o FaIcon (que não força caixa quadrada como o Icon comum)
        // fica colado na borda do campo.
        prefixIcon: SizedBox(
          width: kMinInteractiveDimension,
          child: Center(
            child: FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        suffixIcon: _sufixo(controller.text.isNotEmpty),
      ),
    );
  }

  Widget? _sufixo(bool temTexto) {
    final limpar = aoLimpar == null || !temTexto
        ? null
        : IconButton(
            tooltip: 'Limpar busca',
            icon: const FaIcon(FontAwesomeIcons.xmark),
            onPressed: aoLimpar,
          );
    final buscar = aoBuscar == null
        ? null
        : IconButton(
            tooltip: 'Buscar',
            icon: const FaIcon(FontAwesomeIcons.arrowRight),
            onPressed: aoBuscar,
          );
    if (limpar != null && buscar != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [limpar, buscar]);
    }
    return limpar ?? buscar;
  }
}
