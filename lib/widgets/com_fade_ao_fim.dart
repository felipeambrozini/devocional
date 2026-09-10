import 'package:flutter/material.dart';

/// Texto de até 5 linhas que desvanece na última quando o corte é real.
///
/// A reticência sozinha parecia um fim de texto, e a prévia competia com o
/// resto do cartão: o corte vira um convite ao "Ler tudo" quando se lê como
/// corte. O `TextPainter` decide antes de pintar se o texto estoura; só então
/// o `ShaderMask` suaviza a quinta linha para o fundo (o `dstIn` usa só o
/// alfa do gradiente, preservando a cor do texto).
class DevocionalComFadeAoFim extends StatelessWidget {
  const DevocionalComFadeAoFim({super.key, required this.texto, required this.estilo});

  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: texto, style: estilo),
          maxLines: 5,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        if (!painter.didExceedMaxLines) {
          return Text(
            texto,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          );
        }
        return ShaderMask(
          shaderCallback: (limites) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.82, 0.95, 1.0],
          ).createShader(limites),
          blendMode: BlendMode.dstIn,
          child: Text(
            texto,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          ),
        );
      },
    );
  }
}
