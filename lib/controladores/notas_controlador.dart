import 'package:material_ui/material_ui.dart';

import '../dados/conteudo.dart';
import '../dados/modelos.dart';

/// De qual aba vieram as notas: cada aba mostra só os próprios favoritos e
/// anotações, para Bíblia, Devocional e Biblioteca não se misturarem.
enum OrigemDasNotas {
  biblia('Bíblia'),
  devocional('Devocional'),
  biblioteca('Biblioteca');

  const OrigemDasNotas(this.rotulo);

  final String rotulo;

  /// O parâmetro `?aba=` da rota; qualquer outra coisa cai na Bíblia.
  static OrigemDasNotas doParametro(String? nome) =>
      values.firstWhere((o) => o.name == nome, orElse: () => biblia);
}

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
  List<Marcacao> filtrar(List<Marcacao> itens) =>
      itens.where((m) => combina(m.referencia, m.nota)).toList(growable: false);

  /// Se a referência ou a nota têm o termo buscado (sem acento nem caixa).
  /// Sem busca, tudo combina.
  bool combina(String referencia, String nota) {
    if (busca.isEmpty) return true;
    final alvo = Conteudo.normalizar(busca);
    return Conteudo.normalizar(referencia).contains(alvo) ||
        Conteudo.normalizar(nota).contains(alvo);
  }
}
