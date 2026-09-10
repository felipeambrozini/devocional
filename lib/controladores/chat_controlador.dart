import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../dados/conversador.dart';
import '../dados/estado.dart';
import '../dados/ia.dart';
import '../dados/personas.dart';
import '../funcoes/aviso.dart';
import '../telas/chat.dart';

/// Estado e ações da tela de chat: o conversador (pergunta/resposta com a
/// IA), o campo de mensagem, a rolagem e o aviso de corte da conversa. A tela
/// só monta a UI e escuta este controller — toda decisão mora aqui.
class ChatControlador extends ChangeNotifier {
  ChatControlador({required this.persona, this.conversaId});

  final Persona persona;
  final String? conversaId;

  final controle = TextEditingController();
  final rolagem = ScrollController();

  /// A conversa nova recebe o id só na primeira mensagem (o [Conversador]
  /// chama o Estado); quando isso acontece, a URL ganha o id no lugar de
  /// `/conversa`, para um F5 ou um link reabrirem a conversa de verdade.
  bool rotaAtualizada = false;

  /// O turno da conversa: registra a pergunta, chama a IA e grava a resposta.
  ///
  /// Nasce em [iniciar] (precisa do [EscopoDoEstado], que não pode ser
  /// consultado no initState) e morre com o controller.
  Conversador? conversador;

  /// Estado de corte da conversa na abertura: o snackbar de corte é só para
  /// o momento em que ele acontece, não para a conversa que já abriu cortada
  /// (essa mostra a nota quieta no topo).
  bool cortadaAnterior = false;

  void Function()? _ouvinteConversador;

  /// A tela foi fechada antes de a resposta chegar; não notificar nem mexer
  /// em campo nenhum depois do dispose.
  bool _descartado = false;

  /// Cria o [conversador] e retoma uma resposta interrompida. Chamado do
  /// initState da tela, depois do primeiro frame — é aqui, e não no
  /// construtor, porque depende do [EscopoDoEstado] via [context].
  void iniciar(BuildContext context) {
    final conversadorNovo = Conversador(
      persona: persona,
      estado: EscopoDoEstado.de(context),
      chamar: perguntar,
      conversaId: conversaId,
    );
    conversador = conversadorNovo;
    _ouvinteConversador = () => aoMudarConversador(context);
    conversadorNovo.addListener(_ouvinteConversador!);
    // Reabrir depois de uma resposta interrompida: a última pergunta ficou
    // pendente, e a tela oferece "Tentar de novo" em vez de deixar a
    // pergunta respondida pelo silêncio.
    cortadaAnterior =
        conversaId != null &&
        (EscopoDoEstado.de(
              context,
            ).conversaDe(persona.id, conversaId!)?.cortada ??
            false);
    conversadorNovo.retomarInterrompida();
    // Reabrir cai na última fala, não no topo: cada retomada começava com
    // uma rolagem cheia manual. A segunda passada, agendada dentro do
    // primeiro callback, roda no frame seguinte, quando a lista já mede os
    // extents de verdade (a primeira medida é por estimativa).
    final id = conversadorNovo.id ?? conversaId;
    if (id != null &&
        EscopoDoEstado.de(context).mensagensDe(persona.id, id).isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!rolagem.hasClients) return;
        rolagem.jumpTo(rolagem.position.maxScrollExtent);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!rolagem.hasClients) return;
          rolagem.jumpTo(rolagem.position.maxScrollExtent);
        });
      });
    }
    notifyListeners();
  }

  /// O conversador notificou (resposta chegou, erro, interrupção): redesenhar
  /// o rodapé e rolar para o fim quando uma resposta começa a vir.
  void aoMudarConversador(BuildContext context) {
    if (_descartado) return;
    notifyListeners();
    if (conversador?.respondendo ?? false) rolarParaOFim();
    // O corte do teto acontece no Estado, em silêncio; o aviso quieto no
    // topo só aparece na próxima visita. Anunciar na hora em que as falas
    // saem, uma única vez por sessão de tela.
    final id = conversador?.id;
    final cortadaAgora =
        id != null &&
        (EscopoDoEstado.de(context).conversaDe(persona.id, id)?.cortada ??
            false);
    if (cortadaAgora && !cortadaAnterior) {
      mostrarAviso(context, avisoDeCorte);
    }
    cortadaAnterior = cortadaAgora;
    // A conversa nova acabou de ganhar o id; a URL precisa acompanhar, para
    // um F5 ou um link compartilhado reabrirem esta conversa e não outra.
    final idDaRota = conversador?.id;
    if (idDaRota != null && conversaId == null && !rotaAtualizada) {
      rotaAtualizada = true;
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.replace('/${persona.slug}/conversa/$idDaRota');
      }
    }
  }

  Future<void> enviar() async {
    final texto = controle.text.trim();
    final conversadorAtual = conversador;
    if (texto.isEmpty ||
        conversadorAtual == null ||
        conversadorAtual.respondendo) {
      return;
    }
    controle.clear();
    await conversadorAtual.enviar(texto);
  }

  Future<void> limparConversa(BuildContext context) async {
    final id = conversador?.id;
    if (id == null) return;
    final confirmou = await confirmar(
      context,
      titulo: 'Apagar esta conversa?',
      conteudo:
          'Só esta conversa será apagada deste aparelho, e da cópia na nuvem '
          'se houver. As outras conversas ficam. Essa ação não pode ser '
          'desfeita.',
      rotuloDaAcao: 'Apagar',
    );
    if (!confirmou || !context.mounted) return;
    await EscopoDoEstado.de(context).limparConversa(persona.id, id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  void rolarParaOFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!rolagem.hasClients) return;
      rolagem.jumpTo(rolagem.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _descartado = true;
    final ouvinte = _ouvinteConversador;
    if (ouvinte != null) conversador?.removeListener(ouvinte);
    conversador?.dispose();
    controle.dispose();
    rolagem.dispose();
    super.dispose();
  }
}
