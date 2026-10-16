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

  bool _encerrado = false;

  /// Depois de terminar o livro este capítulo ainda existe por alguns quadros
  /// (a transição de tela), e uma rolagem que acabe nesse intervalo refaria a
  /// posição que `concluir` acabou de apagar. Encerrado, o controlador para de
  /// escrever.
  void encerrar() => _encerrado = true;

  /// Chamar depois do primeiro desenho: só então o texto tem altura. Volta ao
  /// ponto em que o capítulo foi deixado, e marca o capítulo como o atual do
  /// livro (é o que o "continuar" da estante lê).
  void iniciar() {
    if (_encerrado) return;
    final posicao = estado.leituraDeLivros.posicaoDe(slug);
    if (posicao?.capitulo == capitulo) {
      _rolarPara(posicao!.fracao);
    } else {
      estado.leituraDeLivros.registrarPosicao(slug, capitulo, 0);
    }
  }

  /// Guarda quanto do capítulo já foi rolado. Chamar quando a rolagem para.
  void guardarPosicao() {
    if (_encerrado) return;
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
