import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../dados/canon.dart';
import '../dados/conteudo.dart';
import '../dados/modelos.dart';
import '../telas/busca.dart';
import '../telas/devocional.dart';

/// Estado e ações da tela de devocional: data e leitura atuais, navegação
/// entre leituras e o carregamento do devocional do dia. A tela só monta a
/// UI e escuta este controller — toda decisão mora aqui.
class DevocionalControlador extends ChangeNotifier {
  DevocionalControlador({DateTime? dataInicial, Leitura? leituraInicial})
    : data = dataInicial ?? DateTime.now(),
      leitura = leituraInicial ?? Leitura.pelaHora(DateTime.now().hour);

  DateTime data;
  Leitura leitura;

  /// Aplica a data/leitura vindas de fora (a URL, via `didUpdateWidget`): o
  /// go_router chaveia a página pelo caminho, sem os parâmetros, então ir de
  /// `/manha` a `/manha?data=...` atualiza o widget no lugar, sem recriar o
  /// controller. Sem isto, o calendário escrevia a URL mas a tela não mudava.
  void atualizarSeMudou({DateTime? dataInicial, Leitura? leituraInicial}) {
    final novaData = dataInicial ?? DateTime.now();
    final novaLeitura = leituraInicial ?? leitura;
    if (novaLeitura == leitura && _mesmoDia(novaData, data)) return;
    data = novaData;
    leitura = novaLeitura;
    notifyListeners();
  }

  Future<void> escolherData(BuildContext context) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: data,
      // O devocional é anual e se repete, então a janela é só um intervalo
      // confortável para navegar, não um limite de conteúdo.
      firstDate: DateTime(data.year - 5),
      lastDate: DateTime(data.year + 5, 12, 31),
      helpText: 'Escolha a data do devocional',
    );
    if (escolhida != null && context.mounted) {
      irPara(context, leitura, escolhida);
    }
  }

  /// A busca abre na aba de devocionais: quem pesquisa daqui procura
  /// devocional, não versículo.
  void abrirBusca(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const TelaBusca(abaInicial: AbaDaBusca.devocionais),
    ),
  );

  /// Navega para a leitura com a data na URL (`/manha?data=AAAA-MM-DD`):
  /// o chip, o calendário e o "voltar para hoje" escrevem a URL, e a rota
  /// (main.dart) reconstrói a tela com `dataInicial`. A data de hoje não
  /// aparece na URL de propósito, para o link continuar limpo.
  void irPara(BuildContext context, Leitura novaLeitura, DateTime novaData) {
    if (novaLeitura == leitura && _mesmoDia(novaData, data)) return;
    GoRouter.of(
      context,
    ).go('/${novaLeitura.name}${_parametroDeData(novaData)}');
  }

  /// `?data=AAAA-MM-DD`, ou vazio no dia de hoje — para a URL de hoje
  /// continuar limpa, na navegação ([irPara]) e no link de [linkDaLeitura].
  static String _parametroDeData(DateTime data) =>
      _mesmoDia(data, DateTime.now()) ? '' : '?data=${_formatoDeData(data)}';

  /// Link absoluto da leitura atual, o mesmo caminho que main.dart declara
  /// para cada leitura (`/manha`, `/noite`, `/promessas`): quem abre o link
  /// cai direto nela. Vai no texto de Compartilhar do cartão.
  String linkDaLeitura() =>
      '$enderecoDoSite${leitura.name}${_parametroDeData(data)}';

  /// O ano entra na comparação: a data da URL é completa, e "19 de agosto"
  /// de um ano não é o mesmo dia de outro. Sem ele, escolher no calendário o
  /// mesmo dia e mês de um ano diferente não navegava, e a tela ficava presa.
  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatoDeData(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool ehHoje(DateTime hoje) => _mesmoDia(data, hoje);

  Future<Devocional?> carregar() {
    final periodo = leitura.periodo;
    return periodo == null
        ? Conteudo.instancia.promessa(data)
        : Conteudo.instancia.devocional(data, periodo);
  }
}
