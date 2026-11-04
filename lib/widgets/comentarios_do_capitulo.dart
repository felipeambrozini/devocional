import 'package:flutter/material.dart';

import '../dados/config_admin.dart';
import '../dados/conteudo.dart';
import '../dados/recursos.dart';
import 'carrega_uma_vez.dart';

/// Carrega os comentários de Spurgeon do capítulo uma vez só e os entrega ao
/// [construir], que desenha a lista. O mapa é nulo enquanto carrega e quando o
/// admin desligou o recurso. O texto bíblico
/// já está na tela quando os comentários chegam, e a lista é desenhada pelo
/// mesmo [construir] nos dois casos, então a rolagem não se perde.
///
/// Uma carga por capítulo, e não uma por versículo: o JSON do livro é grande,
/// e cada linha pedindo o seu o decodificaria várias vezes na primeira
/// abertura.
///
/// [aoCarregar] roda uma vez, depois do quadro em que os comentários entram.
/// Quem abriu o capítulo num versículo pedido rola de novo por ele: os
/// comentários crescem o conteúdo acima do alvo e o empurrariam para fora da
/// tela.
class DevocionalComentariosDoCapitulo extends StatelessWidget {
  const DevocionalComentariosDoCapitulo({
    super.key,
    required this.livro,
    required this.capituloNumero,
    required this.construir,
    this.aoCarregar,
  });

  final String livro;
  final int capituloNumero;
  final Widget Function(BuildContext context, Map<int, String>? comentarios)
  construir;
  final VoidCallback? aoCarregar;

  Future<Map<int, String>> _carregar() async {
    final comentarios = await Conteudo.instancia.comentariosDoCapitulo(
      livro,
      capituloNumero,
    );
    final depois = aoCarregar;
    if (depois != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => depois());
    }
    return comentarios;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConfigAdmin.instancia,
      builder: (context, _) {
        if (!Recursos.comentarioNoCapitulo) {
          return construir(context, null);
        }
        return DevocionalCarregaUmaVez<Map<int, String>>(
          chave: '$livro:$capituloNumero',
          carregar: _carregar,
          construir: (context, instantaneo) =>
              construir(context, instantaneo.data),
        );
      },
    );
  }
}
