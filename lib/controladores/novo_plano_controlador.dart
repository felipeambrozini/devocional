import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/planos.dart';
import '../funcoes/aviso.dart';
import '../telas/novo_plano.dart';

/// Estado e ações do formulário de novo plano: livros escolhidos, dias e
/// opções de devocionais, prévia e a criação do plano. A tela só monta a UI e
/// escuta este controller — toda decisão mora aqui.
class NovoPlanoControlador extends ChangeNotifier {
  NovoPlanoControlador({required this.estado}) {
    Conteudo.instancia.aquecerIndiceDeDevocionais().then((_) {
      if (!_descartado) notifyListeners();
    });
  }

  final Estado estado;

  final form = GlobalKey<FormState>();
  final titulo = TextEditingController();
  final dias = TextEditingController(text: '30');

  /// Slugs escolhidos, na ordem de leitura (a do seletor na criação, e a que
  /// quem cria ajusta em "Alterar ordem de leitura").
  final List<String> livros = [];
  bool incluirDevocionais = false;
  bool devocionalAntes = true;

  bool _descartado = false;

  @override
  void dispose() {
    _descartado = true;
    titulo.dispose();
    dias.dispose();
    super.dispose();
  }

  int get totalDeCapitulos {
    var total = 0;
    for (final slug in livros) {
      total += livroPorSlug(slug)?.capitulos ?? 0;
    }
    return total;
  }

  List<DiaDePlanoDoUsuario> get previa => montarPlanoDeLeitura(
    livros: livros,
    dias: int.tryParse(dias.text) ?? 0,
    incluirDevocionais: incluirDevocionais,
    devocionalAntes: devocionalAntes,
  );

  Future<void> escolherLivros(BuildContext context) async {
    final escolhidos = await mostrarSeletorDeLivros(
      context,
      jaEscolhidos: livros,
    );
    if (escolhidos == null) return;
    livros
      ..clear()
      ..addAll(escolhidos);
    notifyListeners();
  }

  void removerLivro(String slug) {
    livros.remove(slug);
    notifyListeners();
  }

  /// Troca a ordem de leitura sem mudar o conjunto de livros: o seletor
  /// decide quais entram, este método só reordena (vem do diálogo de ordem).
  void reordenarLivros(List<String> novaOrdem) {
    final atuais = Set.of(livros);
    if (novaOrdem.length != livros.length ||
        !novaOrdem.every(atuais.contains)) {
      return;
    }
    livros
      ..clear()
      ..addAll(novaOrdem);
    notifyListeners();
  }

  /// Chamado a cada dígito do campo de dias, só para a prévia e a mensagem de
  /// capítulos acompanharem o que foi digitado.
  void diasAlterados() => notifyListeners();

  void definirIncluirDevocionais(bool? marcado) {
    incluirDevocionais = marcado ?? false;
    notifyListeners();
  }

  void definirDevocionalAntes(bool antes) {
    devocionalAntes = antes;
    notifyListeners();
  }

  Future<void> criar(BuildContext context) async {
    if (livros.isEmpty) {
      mostrarAviso(context, 'Escolha pelo menos um livro.');
      return;
    }
    if (!(form.currentState?.validate() ?? false)) return;
    final plano = await estado.criarPlano(
      titulo: titulo.text,
      livros: livros,
      dias: int.parse(dias.text),
      incluirDevocionais: incluirDevocionais,
      devocionalAntes: devocionalAntes,
    );
    if (!context.mounted) return;
    context.pop(plano);
  }

  String? validarDias(String? valor) {
    final diasValor = int.tryParse(valor ?? '');
    if (diasValor == null || diasValor < 1) {
      return 'Informe em quantos dias o plano acontece.';
    }
    final total = totalDeCapitulos;
    if (total > 0 && diasValor > total) {
      return 'Os livros têm $total capítulos; o máximo é $total dias.';
    }
    return null;
  }
}
