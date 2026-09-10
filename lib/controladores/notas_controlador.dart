import 'package:flutter/material.dart';

import '../dados/conteudo.dart';
import '../dados/modelos.dart';

/// Estado e ações da tela de notas: o texto de busca e o filtro por
/// referência/anotação que hoje mora dentro da classe privada da tela. A tela
/// só monta a UI e escuta este controller — toda decisão mora aqui.
class NotasControlador extends ChangeNotifier {
  final controle = TextEditingController();
  String busca = '';

  @override
  void dispose() {
    controle.dispose();
    super.dispose();
  }

  void aoDigitar(String v) {
    busca = v;
    notifyListeners();
  }

  void limpar() {
    controle.clear();
    busca = '';
    notifyListeners();
  }

  /// Filtra por referência (ex. "João 3:16") e pelo texto da própria nota.
  ///
  /// Não pelo corpo do versículo: ele é carregado sob demanda, um por cartão
  /// (ver `Conteudo.instancia.versiculo` abaixo), e trazer todos para buscar
  /// no corpo derrubaria exatamente o carregamento tardio que o app inteiro
  /// foi desenhado para ter.
  List<Marcacao> filtrar(List<Marcacao> itens) {
    if (busca.isEmpty) return itens;
    final alvo = Conteudo.normalizar(busca);
    return itens
        .where(
          (m) =>
              Conteudo.normalizar(m.referencia).contains(alvo) ||
              Conteudo.normalizar(m.nota).contains(alvo),
        )
        .toList();
  }
}
