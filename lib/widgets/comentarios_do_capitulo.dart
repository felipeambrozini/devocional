import 'package:flutter/material.dart';

import '../dados/config_admin.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/recursos.dart';
import 'carrega_uma_vez.dart';

/// Carrega os comentários de Spurgeon do capítulo uma vez só e os entrega ao
/// [construir], que desenha a lista. O mapa é nulo enquanto carrega e quando o
/// recurso (admin) ou a preferência do leitor está desligado. O texto bíblico
/// já está na tela quando os comentários chegam, e a lista é desenhada pelo
/// mesmo [construir] nos dois casos, então a rolagem não se perde.
///
/// Uma carga por capítulo, e não uma por versículo: o JSON do livro é grande,
/// e cada linha pedindo o seu o decodificaria várias vezes na primeira
/// abertura.
class DevocionalComentariosDoCapitulo extends StatelessWidget {
  const DevocionalComentariosDoCapitulo({
    super.key,
    required this.livro,
    required this.capituloNumero,
    required this.construir,
  });

  final String livro;
  final int capituloNumero;
  final Widget Function(BuildContext context, Map<int, String>? comentarios)
  construir;

  @override
  Widget build(BuildContext context) {
    final ligadoPeloLeitor = EscopoDoEstado.de(context).comentarioNoCapitulo;
    return ListenableBuilder(
      listenable: ConfigAdmin.instancia,
      builder: (context, _) {
        if (!ligadoPeloLeitor || !Recursos.comentarioNoCapitulo) {
          return construir(context, null);
        }
        return DevocionalCarregaUmaVez<Map<int, String>>(
          chave: '$livro:$capituloNumero',
          carregar: () =>
              Conteudo.instancia.comentariosDoCapitulo(livro, capituloNumero),
          construir: (context, instantaneo) =>
              construir(context, instantaneo.data),
        );
      },
    );
  }
}
