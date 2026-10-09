import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../dados/estado.dart';

/// A rolagem de um capítulo de livro: devolve o leitor ao ponto em que parou e
/// guarda o ponto novo quando o dedo para. Um controlador por capítulo aberto.
class LeitorDeLivroControlador {
  LeitorDeLivroControlador({
    required this.estado,
    required this.slug,
    required this.capitulo,
  });

  final Estado estado;
  final String slug;

  /// Índice do capítulo, a partir de 0.
  final int capitulo;

  final rolagem = ScrollController();

  /// Chamar depois do primeiro desenho: só então o texto tem altura. Volta ao
  /// ponto em que o capítulo foi deixado, e marca o capítulo como o atual do
  /// livro (é o que o "continuar" da estante lê).
  void iniciar() {
    final posicao = estado.leituraDeLivros.posicaoDe(slug);
    if (posicao?.capitulo == capitulo) {
      _rolarPara(posicao!.fracao);
    } else {
      estado.leituraDeLivros.registrarPosicao(slug, capitulo, 0);
    }
  }

  /// Guarda quanto do capítulo já foi rolado. Chamar quando a rolagem para.
  void guardarPosicao() {
    estado.leituraDeLivros.registrarPosicao(slug, capitulo, _fracaoAtual);
  }

  double get _fracaoAtual {
    if (!rolagem.hasClients) return 0;
    final fim = rolagem.position.maxScrollExtent;
    return fim <= 0 ? 0 : rolagem.offset / fim;
  }

  void _rolarPara(double fracao) {
    if (!rolagem.hasClients) return;
    final fim = rolagem.position.maxScrollExtent;
    rolagem.jumpTo(math.min(fracao * fim, fim));
  }

  void dispose() => rolagem.dispose();
}
