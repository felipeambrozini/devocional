import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../dados/planos.dart';
import '../dados/planos_nuvem.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/conta_acoes.dart';
import '../funcoes/planos_acoes.dart' as acoes;
import '../widgets/botao.dart';

/// Estado e ações da tela de um plano: a cópia viva do plano, a assinatura do
/// documento da nuvem (num plano compartilhado) e as ações do menu de
/// opções. A tela só monta a UI e escuta este controller — toda decisão
/// mora aqui.
///
/// Funciona em dois modos:
/// - plano local: tudo vem do [Estado], e marcar um dia só grava ali;
/// - plano compartilhado: o documento `planos/{id}` do Firestore é a
///   verdade — participantes e dias lidos de cada um — e este controller
///   assina o stream dele. O espelho local continua sendo atualizado, para a
///   lista de Meus Planos mostrar o progresso sem depender da rede.
///
/// Aberto por link (sem [plano] inicial), o controller primeiro entra no
/// plano — escreve a própria participação — e só então lê o documento.
class PlanoControlador extends ChangeNotifier {
  PlanoControlador({required this.estado, required this.planoId, this.plano}) {
    // A tela chega pelo widget.estado, fora do alcance do InheritedNotifier
    // quando aberta por link no Navigator raiz: sem este listener, marcar um
    // dia gravava mas a tela não redesenhava o contador nem o visto do cartão.
    estado.addListener(_aoMudarEstado);
    // Único jeito de abrir um plano sem passar por Novo plano — o caso comum
    // de reabrir o próprio ou de entrar por link — então sem isto os
    // devocionais nunca aparecem: [Conteudo] é um singleton, e sem essa
    // chamada aqui nada mais aquece o índice fora da tela de criação.
    Conteudo.instancia.aquecerIndiceDeDevocionais().then((_) {
      if (_descartado) return;
      notifyListeners();
    });
    iniciar();
  }

  final Estado estado;
  final String planoId;

  /// A cópia viva do plano: começa na passada ao construtor e acompanha a
  /// nuvem, para o controller saber quando um plano local passou a
  /// compartilhado.
  PlanoDoUsuario? plano;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _assinatura;
  DocumentSnapshot<Map<String, dynamic>>? doc;
  bool carregando = true;
  String? erro;

  bool _descartado = false;

  /// Um plano aberto por link é compartilhado por definição.
  bool get compartilhado => plano?.compartilhado ?? true;

  PlanoDoUsuario get planoOuObrigatorio => plano!;

  /// O uid da conta, só onde a nuvem existe. Num plano local não há conta
  /// envolvida.
  String? get uid => compartilhado ? Nuvem.instancia.uid : null;

  void _aoMudarEstado() {
    if (_descartado) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    estado.removeListener(_aoMudarEstado);
    _assinatura?.cancel();
    super.dispose();
  }

  Future<void> iniciar() async {
    if (!compartilhado) {
      carregando = false;
      notifyListeners();
      return;
    }
    if (!Nuvem.instancia.logado) {
      // Sem conta não há documento para ler: o cartão de entrar aparece.
      carregando = false;
      notifyListeners();
      return;
    }
    try {
      // Participantes leem o documento; quem ainda não é participante recebe
      // erro de permissão — é o sinal de que precisa entrar primeiro.
      final doc = await FirebaseFirestore.instance
          .collection('planos')
          .doc(planoId)
          .get();
      if (!doc.exists) {
        // O plano sumiu da nuvem: sai também do espelho local. Trata aqui
        // mesmo, sem lançar para o catch abaixo — lançar caía no mesmo
        // `catch (_)` que tenta `entrar()` de novo, e essa segunda falha
        // (documento continua não existindo) sempre substituía esta
        // mensagem clara pela genérica de "Plano não encontrado".
        await estado.removerPlano(planoId);
        if (_descartado) return;
        erro =
            'Este plano não existe mais. Ele pode ter sido excluído por '
            'quem o criou.';
        carregando = false;
        notifyListeners();
        return;
      }
      _aplicarAoEspelho(doc);
      _assinar();
    } catch (_) {
      try {
        await PlanosNaNuvem.instancia.entrar(planoId);
        _assinar();
      } catch (entrada) {
        if (_descartado) return;
        erro = entrada is PlanosNaNuvemExcecao
            ? entrada.mensagem
            : 'Não foi possível abrir o plano. Verifique a conexão.';
        carregando = false;
        notifyListeners();
      }
    }
  }

  void _assinar() {
    _assinatura = PlanosNaNuvem.instancia
        .deUmPlano(planoId)
        .listen(
          (doc) {
            if (_descartado) return;
            if (!doc.exists) {
              this.doc = null;
              carregando = false;
              erro = 'Este plano não existe mais.';
              notifyListeners();
              return;
            }
            _aplicarAoEspelho(doc);
            this.doc = doc;
            carregando = false;
            erro = null;
            notifyListeners();
          },
          onError: (_) {
            if (_descartado) return;
            erro = 'Não foi possível carregar o plano. Verifique a conexão.';
            carregando = false;
            notifyListeners();
          },
        );
  }

  /// Espelha no [Estado] o que chegou da nuvem: o plano em si e os dias
  /// lidos, para a lista de Meus Planos não depender da rede.
  void _aplicarAoEspelho(DocumentSnapshot<Map<String, dynamic>> doc) {
    final dados = doc.data();
    if (dados == null) return;
    final criadoEm = dados['criadoEm'] is Timestamp
        ? (dados['criadoEm'] as Timestamp).toDate()
        : DateTime.now();
    final planoDaNuvem = PlanoDoUsuario.doJsonDaNuvem(
      dados,
      id: planoId,
      criadoEm: criadoEm,
    );
    final atualizado = estado.planoDoUsuario(planoId);
    if (atualizado != null) plano = atualizado;
    unawaited(estado.aplicarPlanoDaNuvem(planoDaNuvem, lidos: lidosDe(dados)));
  }

  /// Os dias lidos do usuário corrente, segundo a verdade de cada modo.
  Set<int> lidosDe(Map<String, dynamic> dados) {
    final uidAtual = uid;
    if (uidAtual == null) return const {};
    final participantes =
        dados['participantes'] as Map<String, dynamic>? ?? const {};
    final minha = participantes[uidAtual];
    if (minha is! Map<String, dynamic> || minha['lidos'] is! List) {
      return const {};
    }
    return {
      for (final dia in minha['lidos'] as List)
        if (dia is int) dia,
    };
  }

  Set<int> meusLidos() {
    final dados = doc?.data();
    if (dados != null) return lidosDe(dados);
    final planoAtual = plano;
    if (planoAtual == null) return const {};
    return {
      for (final dia in planoAtual.diasDoPlano)
        if (estado.foiLidoNoPlano(planoAtual.id, dia.numero)) dia.numero,
    };
  }

  Future<void> alternarDia(BuildContext context, int dia) async {
    // O total de dias do plano, para saber quando ele termina (ver
    // [_avisarConclusao]): sem plano carregado não há o que concluir.
    final total = plano?.diasDoPlano.length ?? 0;
    if (compartilhado) {
      if (!Nuvem.instancia.logado) {
        if (context.mounted) {
          mostrarAviso(context, 'Entre na sua conta para marcar dias.');
        }
        return;
      }
      // A verdade é o documento: o novo conjunto parte do que ele diz, não
      // do espelho, senão um espelho velho apagaria dias marcados noutro
      // aparelho.
      final atual = {...meusLidos()};
      final novo = {...atual};
      if (!novo.remove(dia)) novo.add(dia);
      final marcou = novo.contains(dia);
      await estado.substituirLidosDoPlano(planoId, novo);
      try {
        await PlanosNaNuvem.instancia.gravarDias(
          planoId,
          novo.toList()..sort(),
        );
        if (context.mounted) {
          _avisarConclusao(
            context,
            marcou: marcou,
            lidos: novo.length,
            total: total,
          );
        }
      } on PlanosNaNuvemExcecao catch (erro) {
        // Devolve o espelho ao que o documento diz: sem rede a marcação não
        // aconteceu de verdade.
        await estado.substituirLidosDoPlano(planoId, atual);
        if (context.mounted) mostrarErro(context, erro.mensagem);
      }
    } else {
      final marcou = !estado.foiLidoNoPlano(planoId, dia);
      await estado.alternarLidoNoPlano(planoId, dia);
      if (context.mounted) {
        _avisarConclusao(
          context,
          marcou: marcou,
          lidos: meusLidos().length,
          total: total,
        );
      }
    }
  }

  /// Mensagem discreta ao fechar o último dia do plano: sem streak, sem
  /// cobrança, só o ponto final. Só quando marcou (desmarcar o último dia
  /// não celebra) e só na transição para o plano cheio.
  void _avisarConclusao(
    BuildContext context, {
    required bool marcou,
    required int lidos,
    required int total,
  }) {
    if (!marcou || total <= 0 || lidos < total) return;
    if (context.mounted) mostrarAviso(context, 'Você concluiu este plano.');
  }

  Future<void> compartilhar(BuildContext context) async {
    final nuvem = Nuvem.instancia;
    if (!nuvem.logado) {
      await entrarNaConta(context, nuvem);
      if (!context.mounted || !nuvem.logado) return;
    }
    try {
      final link = await PlanosNaNuvem.instancia.compartilhar(
        planoOuObrigatorio,
      );
      await estado.marcarCompartilhado(planoOuObrigatorio.id);
      if (!context.mounted) return;
      plano = estado.planoDoUsuario(planoOuObrigatorio.id);
      notifyListeners();
      await mostrarLink(context, link);
    } on PlanosNaNuvemExcecao catch (erro) {
      if (context.mounted) mostrarErro(context, erro.mensagem);
    }
  }

  Future<void> copiarLink(BuildContext context) async {
    final link = linkDoPlano(planoId, titulo: plano?.titulo);
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) mostrarAviso(context, 'Link copiado.');
  }

  Future<void> mostrarLink(BuildContext context, String link) async {
    final copiou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plano compartilhado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quem abrir este link entra no plano e o progresso de cada '
              'participante aparece para todos.',
            ),
            const SizedBox(height: DevocionalEspacamento.sp12),
            SelectableText(link),
          ],
        ),
        actions: [
          DevocionalBotaoTerciario(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Fechar'),
          ),
          DevocionalBotaoPrimario.icon(
            icon: const FaIcon(FontAwesomeIcons.copy),
            label: const Text('Copiar link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );
    if (copiou == true && context.mounted) {
      mostrarAviso(context, 'Link copiado.');
    }
  }

  Future<void> editar(BuildContext context) async {
    final planoAtual = plano;
    if (planoAtual == null) return;
    final editou = await acoes.editarPlano(context, estado, planoAtual);
    if (editou && !_descartado) {
      plano = estado.planoDoUsuario(planoId);
      notifyListeners();
    }
  }

  Future<void> sair(BuildContext context) async {
    final saiu = await acoes.sairDoPlano(context, estado, planoId);
    if (saiu && context.mounted) Navigator.pop(context);
  }

  Future<void> excluir(
    BuildContext context, {
    required bool compartilhado,
  }) async {
    final excluiu = await acoes.excluirPlano(
      context,
      estado,
      planoId,
      compartilhado: compartilhado,
    );
    if (excluiu && context.mounted) Navigator.pop(context);
  }

  void tentarDeNovo() {
    erro = null;
    carregando = true;
    notifyListeners();
    iniciar();
  }
}
