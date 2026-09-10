import 'dart:async';

import 'package:flutter/material.dart';

import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/modelos.dart';
import '../funcoes/aviso.dart';

/// Estado e ações da tela de busca: o termo digitado, os achados da Bíblia
/// (por stream) e dos devocionais, e o debounce que dispara a busca sozinha.
/// A tela só monta a UI e escuta este controller — toda decisão mora aqui.
class BuscaControlador extends ChangeNotifier {
  final controle = TextEditingController();
  final achados = <Achado>[];
  StreamSubscription<Achado>? assinatura;
  Timer? debounce;
  bool buscando = false;
  bool erro = false;
  String termoBuscado = '';

  /// Não nula quando o termo digitado é, ele mesmo, uma referência bíblica
  /// ("João 3:16"): a busca por texto não acha isso, porque o versículo não
  /// contém a própria referência.
  (Livro, int, int, int)? referencia;

  List<AchadoDevocional> achadosDevocionais = [];
  bool buscandoDevocionais = false;
  bool erroDevocionais = false;

  /// Marca que [dispose] já rodou, para os callbacks assíncronos (stream e
  /// Future) pararem de mutar estado e notificar — o ChangeNotifier não tem
  /// um `mounted` como o State, então este é o substituto.
  bool _descartado = false;

  @override
  void dispose() {
    _descartado = true;
    debounce?.cancel();
    assinatura?.cancel();
    controle.dispose();
    super.dispose();
  }

  /// Dispara a busca sozinha um instante depois que a digitação parar, em
  /// vez de esperar clique no botão. O atraso evita buscar a cada tecla.
  void aoDigitar(BuildContext context) {
    notifyListeners();
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 400),
      () => buscar(context, avisar: false),
    );
  }

  void buscar(BuildContext context, {bool avisar = true}) {
    debounce?.cancel();
    final termo = controle.text.trim();
    // Menos de três letras devolveria meia Bíblia e não ajudaria ninguém. Ao
    // digitar, isso só limpa os resultados em silêncio; só o clique no botão
    // ou o Enter avisam, senão a mensagem apareceria a cada letra digitada.
    if (termo.isEmpty || termo.length < 3) {
      if (avisar) {
        mostrarAviso(context, 'Escreva ao menos três letras para buscar.');
      } else {
        resetarResultados();
      }
      return;
    }

    // Cancelar a busca anterior interrompe a leitura dos livros restantes.
    assinatura?.cancel();
    achados.clear();
    achadosDevocionais = [];
    buscando = true;
    buscandoDevocionais = true;
    erro = false;
    erroDevocionais = false;
    termoBuscado = termo;
    referencia = faixaDeVersiculoDaReferencia(termo);
    notifyListeners();

    assinatura = Conteudo.instancia
        .buscar(termo)
        .listen(
          (achado) {
            if (_descartado) return;
            achados.add(achado);
            notifyListeners();
          },
          onDone: () {
            if (_descartado) return;
            buscando = false;
            notifyListeners();
          },
          onError: (Object _) {
            if (_descartado) return;
            erro = true;
            buscando = false;
            notifyListeners();
          },
        );

    buscarDevocionais(termo);
  }

  Future<void> buscarDevocionais(String termo) async {
    try {
      final resultado = await Conteudo.instancia.buscarDevocionais(termo);
      if (_descartado) return;
      achadosDevocionais = resultado;
      buscandoDevocionais = false;
      notifyListeners();
    } catch (_) {
      if (_descartado) return;
      erroDevocionais = true;
      buscandoDevocionais = false;
      notifyListeners();
    }
  }

  /// Devolve os resultados ao estado inicial sem tocar no texto digitado:
  /// usado quando a digitação encolhe abaixo de três letras.
  void resetarResultados() {
    assinatura?.cancel();
    achados.clear();
    achadosDevocionais = [];
    buscando = false;
    buscandoDevocionais = false;
    erro = false;
    erroDevocionais = false;
    termoBuscado = '';
    referencia = null;
    notifyListeners();
  }

  /// Esvazia a busca e devolve a tela ao estado inicial, em vez de pedir
  /// para quem pesquisou apagar o termo letra por letra.
  void limpar() {
    debounce?.cancel();
    controle.clear();
    resetarResultados();
  }
}
