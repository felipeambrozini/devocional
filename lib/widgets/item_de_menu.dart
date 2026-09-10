import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Uma linha de opção num PopupMenuItem: ícone e rótulo, sem o respiro padrão
/// do ListTile — que só sobra dentro de um menu compacto.
class DevocionalItemDeMenu extends StatelessWidget {
  const DevocionalItemDeMenu({super.key, required this.icone, required this.rotulo});

  final FaIconData icone;
  final String rotulo;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: FaIcon(icone),
    title: Text(rotulo),
    contentPadding: EdgeInsets.zero,
  );
}
