import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controladores/chat_controlador.dart';
import '../dados/conversas.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../widgets/widgets.dart';

/// A conversa com uma persona, enquadrada como carta da Estante.
///
/// THESIS: a conversa recusa a casca de messenger: sem sombra, sem metal em
/// área grande, sem ponta de balão. É uma página do livro: abre-se pelo
/// DevocionalFilete, a palavra da persona entra como citação das introduções e o texto
/// do visitante recua em pergaminho.
/// OWN-WORLD: chapado sobre chapado; fio do metal no lugar da sombra; citação
/// com fio esquerdo de 3 (a gramática das introduções em
/// `widgets/abertura_de_livro.dart`);
/// rostos recortados sempre pelo topo; Cinzel nos títulos, Montserrat no
/// corpo.
/// STORY: quem chega vê o retrato, o DevocionalFilete e a primeira palavra da persona
/// como quem abre uma página; o erro tem o rosto de quem respondeu; uma
/// resposta interrompida espera com "Tentar de novo".
/// FIRST VIEWPORT: AppBar com o retrato e o título; a conversa abre com o
/// DevocionalFilete de 64; respostas à esquerda na gramática da citação, perguntas à
/// direita recuadas; rodapé com o campo e a nota da IA.
/// FORM: redesenho da superfície do chat no mundo estabelecido da Estante,
/// direção fixada pelo usuário (carta enquadrada pelo DevocionalFilete); sem sorteio.
/// FINISH: unreviewed and undocumented is unfinished; this build ends with
/// the finish review, the verdict, and DESIGN.md.

/// Quantas camadas flutuantes estão abertas (folha de ajustes, diálogo, o
/// próprio chat). Os balões somem quando o número passa de zero: não faz
/// sentido ter o botão do chat por cima do próprio chat, nem por cima de uma
/// folha que precisa da tela inteira. Quem soma e subtrai: o observador de
/// rotas em `main.dart` para folhas e diálogos, e a [TelaChat] para si mesma.
final camadasFlutuantes = ValueNotifier<int>(0);

/// O aviso de que o teto de mensagens cortou as falas mais antigas. O mesmo
/// texto na snackbar do momento do corte e na nota quieta no topo da conversa:
/// ajustar num lugar ajusta nos dois.
const avisoDeCorte =
    'As falas mais antigas saíram quando esta conversa '
    'passou de ${Conversas.maxMensagensPorConversa} mensagens.';

/// O chat com uma persona: histórico da conversa, campo de mensagem e a
/// resposta da inteligência artificial gratuita.
///
/// [conversaId] é a conversa que este chat abre; null abre uma conversa nova,
/// que só nasce (com o próprio id) na primeira pergunta. A lista de
/// conversas fica em `lib/telas/historico.dart`, e é de lá que este chat é
/// empurrado, junto com a URL que o F5 e o link compartilhado reabrem.
class TelaChat extends StatefulWidget {
  const TelaChat({super.key, required this.persona, this.conversaId});

  final Persona persona;
  final String? conversaId;

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> {
  late final _controller = ChatControlador(
    persona: widget.persona,
    conversaId: widget.conversaId,
  );

  @override
  void initState() {
    super.initState();
    // O chat é uma tela empurrada por cima das abas, e os balões são irmãos
    // do Navigator: sem isto, o botão do chat flutuaria por cima do chat.
    // O aviso precisa sair do meio do build: incrementar aqui dentro
    // notificaria os balões enquanto a árvore ainda monta o chat, e o
    // framework proíbe marcar um widget para reconstruir nessa fase (assert
    // em debug). Depois do frame o efeito é o mesmo, sem a exceção.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      camadasFlutuantes.value++;
      _controller.iniciar(context);
    });
  }

  @override
  void dispose() {
    // O dispose também roda dentro do build (o do desmonte da rota), então a
    // contagem volta depois do frame, como no initState.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => camadasFlutuantes.value--,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final conversador = _controller.conversador;
        final respondendo = conversador?.respondendo ?? false;
        // A conversa aberta: a que veio na rota (existe antes do conversador
        // nascer) ou a que nasceu na primeira pergunta de uma conversa nova.
        final conversaId = conversador?.id ?? widget.conversaId;
        // O corte do teto de mensagens acontece no Estado; a tela só
        // pergunta se a conversa aberta foi cortada para mostrar o aviso
        // quieto no topo.
        final cortada =
            conversaId != null &&
            (estado.conversaDe(widget.persona.id, conversaId)?.cortada ??
                false);

        return Scaffold(
          appBar: DevocionalAppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    widget.persona.foto,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                const SizedBox(width: DevocionalEspacamento.sp10),
                // Flexible com reticências, como na barra do leitor
                // (biblia.dart): o nome longo de uma persona em celular estreito
                // com escala 2x estouraria a linha da AppBar.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.persona.nome,
                        style: tema.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.persona.titulo,
                        style: tema.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Sem id a conversa ainda não existe (não tem mensagem nenhuma):
              // não há o que apagar. O botão nasce junto com a primeira pergunta.
              if (conversaId != null)
                IconButton(
                  tooltip: 'Apagar esta conversa',
                  icon: const FaIcon(FontAwesomeIcons.trash),
                  onPressed: () => _controller.limparConversa(context),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: estado,
                  builder: (context, _) {
                    final mensagens = conversaId == null
                        ? const <Mensagem>[]
                        : estado.mensagensDe(widget.persona.id, conversaId);
                    if (mensagens.isEmpty) {
                      return DevocionalBoasVindas(persona: widget.persona);
                    }
                    // O cabeçalho (o DevocionalFilete) é o índice 0; as mensagens vêm depois.
                    return ListView.builder(
                      controller: _controller.rolagem,
                      padding: const EdgeInsets.fromLTRB(
                        DevocionalEspacamento.sp16,
                        DevocionalEspacamento.sp16,
                        DevocionalEspacamento.sp16,
                        DevocionalEspacamento.sp8,
                      ),
                      itemCount: mensagens.length + 1 + (cortada ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          // A conversa abre como página: o DevocionalFilete que abre cada
                          // leitura da Estante sinaliza onde o fio começa.
                          return const Padding(
                            padding: EdgeInsets.only(bottom: DevocionalEspacamento.sp18),
                            child: Center(child: DevocionalFilete(largura: 64)),
                          );
                        }
                        if (cortada && i == 1) {
                          // A conversa passou do teto e as falas mais antigas
                          // saíram do histórico: a nota quieta explica por que a
                          // conversa não começa na primeira pergunta.
                          return const DevocionalAvisoDeCorte();
                        }
                        return DevocionalBalcaoDeMensagem(
                          mensagem: mensagens[i - 1 - (cortada ? 1 : 0)],
                          persona: widget.persona,
                        );
                      },
                    );
                  },
                ),
              ),
              if (respondendo)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DevocionalEspacamento.sp16,
                    DevocionalEspacamento.sp4,
                    DevocionalEspacamento.sp16,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: DevocionalBolha(
                      avatar: widget.persona.foto,
                      child: SizedBox(
                        width: DevocionalEspacamento.sp18,
                        height: DevocionalEspacamento.sp18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              if (conversador?.erro != null)
                DevocionalErroDeResposta(
                  persona: widget.persona,
                  mensagem: conversador!.erro!,
                  aoTentarDeNovo: conversador.repetir,
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DevocionalEspacamento.sp12,
                    DevocionalEspacamento.sp6,
                    DevocionalEspacamento.sp12,
                    DevocionalEspacamento.sp10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(avisoDeIa, style: tema.labelMedium),
                      const SizedBox(height: DevocionalEspacamento.sp6),
                      TextField(
                        controller: _controller.controle,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _controller.enviar(),
                        decoration: InputDecoration(
                          // Enquanto a resposta vem, o campo diz o estado em vez de
                          // engolir o envio em silêncio; o rascunho continua lá.
                          hintText: respondendo
                              ? 'aguarde a resposta...'
                              : 'Escreva para ${widget.persona.nome}...',
                          suffixIcon: respondendo
                              ? const Padding(
                                  padding: EdgeInsets.all(DevocionalEspacamento.sp12),
                                  child: SizedBox(
                                    width: DevocionalEspacamento.sp18,
                                    height: DevocionalEspacamento.sp18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Enviar',
                                  icon: FaIcon(
                                    FontAwesomeIcons.paperPlane,
                                    color: cor.primary,
                                  ),
                                  onPressed: _controller.enviar,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
