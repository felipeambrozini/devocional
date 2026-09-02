import 'dart:async';

import 'package:flutter/material.dart';

import '../data/estado.dart';
import '../data/eventos.dart';
import 'aviso.dart';

/// Marca ou desmarca o dia como lido e oferece voltar no mesmo gesto.
///
/// O alternador é um toque só, e um toque errado num dia lido custaria o
/// registro sem aviso: o "Desfazer" devolve o estado anterior. É o mesmo
/// padrão do deslize de capítulo (`biblia.dart`): a ação tem sempre uma
/// saída de um toque. Usado pelo "Leitura de hoje" (`hoje.dart`).
void alternarLidoComDesfazer(
  BuildContext context,
  Estado estado,
  String chave,
) {
  final estavaLido = estado.foiLido(chave);
  estado.alternarLido(chave);
  if (!estavaLido) unawaited(registrarDiaMarcado());
  // Confirmação de um toque só, não um erro: aparece e some sozinho, sem
  // depender do "Desfazer" para fechar.
  mostrarAviso(
    context,
    estavaLido ? 'Dia desmarcado.' : 'Dia marcado como lido.',
    rotuloDeAcao: 'Desfazer',
    aoAgir: () => estado.alternarLido(chave),
  );
}
