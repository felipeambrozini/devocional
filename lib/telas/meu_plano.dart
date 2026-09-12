import 'package:flutter/material.dart';
// ScrollCacheExtent ainda não é reexportado por material.dart nesta versão.
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controladores/plano_controlador.dart';
import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../dados/planos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// A tela de um plano do usuário: o que se lê dia a dia, o progresso
/// próprio e, num plano compartilhado, o progresso de cada participante.
///
/// Funciona em dois modos:
/// - plano local: tudo vem do [Estado], e marcar um dia só grava ali;
/// - plano compartilhado: o documento `planos/{id}` do Firestore é a
///   verdade — participantes e dias lidos de cada um — e esta tela assina o
///   stream dele. O espelho local continua sendo atualizado, para a lista de
///   Meus Planos mostrar o progresso sem depender da rede.
///
/// Aberta por link (sem [plano]), a tela primeiro entra no plano — escreve a
/// própria participação — e só então lê o documento. Sem conta, mostra o
/// caminho para entrar.
class TelaDeUmPlano extends StatefulWidget {
  const TelaDeUmPlano({
    super.key,
    required this.estado,
    required this.planoId,
    this.plano,
  });

  final Estado estado;
  final String planoId;

  /// A cópia local do plano, quando a tela veio da lista de Meus Planos.
  /// Nula quando veio de um link: aí o plano só existe na nuvem.
  final PlanoDoUsuario? plano;

  @override
  State<TelaDeUmPlano> createState() => _TelaDeUmPlanoState();
}

class _TelaDeUmPlanoState extends State<TelaDeUmPlano> {
  late final _controller = PlanoControlador(
    estado: widget.estado,
    planoId: widget.planoId,
    plano: widget.plano,
  );

  /// Marca o primeiro dia ainda não lido, para poder rolar até ele.
  final _chaveDoProximoDia = GlobalKey();

  /// Se a rolagem automática já aconteceu, para não refazê-la a cada
  /// redesenho nem roubar a posição de quem já rolou a lista com a mão.
  bool _jaRolouAteProximoDia = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Num plano de muitos dias, rolar manualmente até onde se parou é
  /// cansativo — o cronograma anual já resolve isso para o dia de hoje
  /// (`_rolarAteHoje` em aba_do_cronograma.dart); aqui o equivalente é o
  /// primeiro dia ainda não marcado como lido.
  void _rolarAteProximoDia() {
    if (_jaRolouAteProximoDia) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alvo = _chaveDoProximoDia.currentContext;
      if (!mounted || alvo == null) return;
      _jaRolouAteProximoDia = true;
      Scrollable.ensureVisible(
        alvo,
        alignment: 0.15,
        duration: MediaQuery.disableAnimationsOf(alvo)
            ? Duration.zero
            : const Duration(milliseconds: 350),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final plano = _controller.plano;
        final dados = _controller.doc?.data();
        final uid = _controller.uid;
        final criador = dados?['criadoPor'] as String?;
        final souCriador =
            _controller.compartilhado && criador != null && criador == uid;
        final diaCount = plano?.diasDoPlano.length ?? 0;
        final lidos = _controller.meusLidos().length;

        return Scaffold(
          appBar: DevocionalAppBar(
            title: Text(plano?.titulo ?? 'Plano'),
            actions: [
              if (_controller.compartilhado && dados != null) ...[
                PopupMenuButton<String>(
                  tooltip: 'Opções do plano',
                  onSelected: (opcao) {
                    switch (opcao) {
                      case 'copiar':
                        _controller.copiarLink(context);
                      case 'editar':
                        _controller.editar(context);
                      case 'sair':
                        _controller.sair(context);
                      case 'excluir':
                        _controller.excluir(context, compartilhado: true);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'copiar',
                      child: DevocionalItemDeMenu(
                        icone: FontAwesomeIcons.link,
                        rotulo: 'Copiar link do plano',
                      ),
                    ),
                    // Só o criador edita: os outros participantes veem o
                    // mesmo título e a mesma escolha de devocionais que ele
                    // definir.
                    if (souCriador)
                      const PopupMenuItem(
                        value: 'editar',
                        child: DevocionalItemDeMenu(
                          icone: FontAwesomeIcons.penToSquare,
                          rotulo: 'Editar plano',
                        ),
                      ),
                    if (!souCriador)
                      const PopupMenuItem(
                        value: 'sair',
                        child: DevocionalItemDeMenu(
                          icone: FontAwesomeIcons.rightFromBracket,
                          rotulo: 'Sair do plano',
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'excluir',
                        child: DevocionalItemDeMenu(
                          icone: FontAwesomeIcons.trash,
                          rotulo: 'Excluir plano',
                        ),
                      ),
                  ],
                ),
              ] else if (!_controller.compartilhado)
                PopupMenuButton<String>(
                  tooltip: 'Opções do plano',
                  onSelected: (opcao) {
                    switch (opcao) {
                      case 'editar':
                        _controller.editar(context);
                      case 'excluir':
                        _controller.excluir(context, compartilhado: false);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'editar',
                      child: DevocionalItemDeMenu(
                        icone: FontAwesomeIcons.penToSquare,
                        rotulo: 'Editar plano',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'excluir',
                      child: DevocionalItemDeMenu(
                        icone: FontAwesomeIcons.trash,
                        rotulo: 'Excluir plano',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: _corpo(context, dados, plano, diaCount, lidos),
        );
      },
    );
  }

  Widget _corpo(
    BuildContext context,
    Map<String, dynamic>? dados,
    PlanoDoUsuario? plano,
    int diaCount,
    int lidos,
  ) {
    if (_controller.carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    final erro = _controller.erro;
    if (erro != null) {
      return DevocionalAvisoVazio(
        icone: FontAwesomeIcons.triangleExclamation,
        titulo: erro,
        acao: DevocionalBotaoPrimario.icon(
          icon: const FaIcon(FontAwesomeIcons.arrowsRotate),
          label: const Text('Tentar de novo'),
          onPressed: _controller.tentarDeNovo,
        ),
      );
    }
    final planoLocal = _controller.plano;
    if (planoLocal == null) {
      // Link aberto sem conta: o plano não pôde ser lido.
      return DevocionalCartaoDeEntrar(onEntrar: _controller.iniciar);
    }

    final dias = planoLocal.diasDoPlano;
    final meusLidos = _controller.meusLidos();
    var proximoIndice = -1;
    for (var i = 0; i < dias.length; i++) {
      if (!meusLidos.contains(dias[i].numero)) {
        proximoIndice = i;
        break;
      }
    }
    if (proximoIndice != -1) _rolarAteProximoDia();

    return DevocionalLarguraDeLeitura(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          DevocionalEspacamento.sp16,
          DevocionalEspacamento.sp12,
          DevocionalEspacamento.sp16,
          DevocionalEspacamento.sp32,
        ),
        // ponytail: monta o plano inteiro (como aba_do_cronograma.dart monta o mês
        // inteiro), dimensionado ao tamanho real do plano — sem isto o GlobalKey do
        // próximo dia não lido ainda não tem contexto quando _rolarAteProximoDia
        // procura por ele, em qualquer plano além de poucos dias. 240px/dia é uma
        // superestimativa deliberada: com `incluirDevocionais` cada dia intercala
        // até 2-3 devocionais por capítulo (ver planos.dart) e o Wrap de chips do
        // cartão cresce em altura — superestimar só gasta memória de widgets
        // construídos a mais, subestimar quebra a rolagem em silêncio. Se planos
        // crescerem para milhares de dias, o caminho é scrollable_positioned_list
        // (mesmo próximo passo já anotado no cronograma).
        scrollCacheExtent: ScrollCacheExtent.pixels(dias.length * 240.0),
        itemCount: dias.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: DevocionalEspacamento.sp10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DevocionalCabecalhoDoPlano(
                  plano: planoLocal,
                  lidos: lidos,
                  totalDeDias: diaCount,
                ),
                if (_controller.compartilhado && nuvemSuportada) ...[
                  const SizedBox(height: DevocionalEspacamento.sp10),
                  DevocionalCartaoDeCompartilhar(
                    compartilhado: true,
                    aoCompartilhar: () => _controller.copiarLink(context),
                  ),
                ] else if (nuvemSuportada) ...[
                  const SizedBox(height: DevocionalEspacamento.sp10),
                  DevocionalCartaoDeCompartilhar(
                    compartilhado: false,
                    aoCompartilhar: () => _controller.compartilhar(context),
                  ),
                ],
                if (_controller.compartilhado && dados != null) ...[
                  const SizedBox(height: DevocionalEspacamento.sp10),
                  DevocionalSecaoDeParticipantes(
                    dados: dados,
                    meuUid: _controller.uid,
                    totalDeDias: diaCount,
                  ),
                ],
              ],
            );
          }
          final dia = dias[i - 1];
          return DevocionalCartaoDeDia(
            key: (i - 1) == proximoIndice ? _chaveDoProximoDia : null,
            numero: dia.numero,
            rotulo: dia.rotulo,
            itens: dia.itens,
            lido: _controller.meusLidos().contains(dia.numero),
            aoAlternar: () => _controller.alternarDia(context, dia.numero),
          );
        },
      ),
    );
  }
}
