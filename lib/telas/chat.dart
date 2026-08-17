import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/conversador.dart';
import '../data/estado.dart';
import '../data/ia.dart';
import '../data/modelos.dart';
import '../data/personas.dart';
import 'comuns.dart';

/// A conversa com uma persona, enquadrada como carta da Estante.
///
/// THESIS: a conversa recusa a casca de messenger: sem sombra, sem metal em
/// área grande, sem ponta de balão. É uma página do livro: abre-se pelo
/// Filete, a palavra da persona entra como citação das introduções e o texto
/// do visitante recua em pergaminho.
/// OWN-WORLD: chapado sobre chapado; fio do metal no lugar da sombra; citação
/// com fio esquerdo de 3 (a gramática das introduções em `comuns.dart`);
/// rostos recortados sempre pelo topo; Cinzel nos títulos, Montserrat no
/// corpo.
/// STORY: quem chega vê o retrato, o Filete e a primeira palavra da persona
/// como quem abre uma página; o erro tem o rosto de quem respondeu; uma
/// resposta interrompida espera com "Tentar de novo".
/// FIRST VIEWPORT: AppBar com o retrato e o título; a conversa abre com o
/// Filete de 64; respostas à esquerda na gramática da citação, perguntas à
/// direita recuadas; rodapé com o campo e a nota da IA.
/// FORM: redesenho da superfície do chat no mundo estabelecido da Estante,
/// direção fixada pelo usuário (carta enquadrada pelo Filete); sem sorteio.
/// FINISH: unreviewed and undocumented is unfinished; this build ends with
/// the finish review, the verdict, and DESIGN.md.

/// Quantas camadas flutuantes estão abertas (folha de ajustes, diálogo, o
/// próprio chat). Os balões somem quando o número passa de zero: não faz
/// sentido ter o botão do chat por cima do próprio chat, nem por cima de uma
/// folha que precisa da tela inteira. Quem soma e subtrai: o observador de
/// rotas em `main.dart` para folhas e diálogos, e a [TelaChat] para si mesma.
final camadasFlutuantes = ValueNotifier<int>(0);

/// Balão circular com o retrato da persona, o botão flutuante do chat.
///
/// Fica pendurado por cima de todas as telas (ver o `builder` em `main.dart`),
/// no canto do próprio dono: Spurgeon à esquerda, Felipe à direita.
class BalaoDeChat extends StatelessWidget {
  const BalaoDeChat({super.key, required this.persona, required this.onTap});

  final Persona persona;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    // O mesmo retrato que serve o polegar no celular (52) se perde na janela
    // do navegador e no tablet: o balão cresce junto com a plataforma, no
    // mesmo limiar largo (720) que o resto do app usa para trocar de moldura.
    final tamanho = MediaQuery.sizeOf(context).width >= 720 ? 64.0 : 52.0;
    return Tooltip(
      message: 'Conversas com ${persona.nome}',
      child: Semantics(
        button: true,
        label: 'Abrir histórico de conversas com ${persona.nome}',
        child: Material(
          color: cor.surfaceContainer,
          // Chapado, como todo o app: a sombra era a única do sistema inteiro,
          // e o círculo com sombra flutuava sobre a leitura de Manhã.
          elevation: 0,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cor.primary, width: 1.5),
              ),
              // A folga entre o aro dourado e a foto, como no cabeçalho de
              // hoje.dart: sem ela a foto preenche o círculo até a borda e o
              // cabelo do Felipe encosta no aro. Com ela o aro fica limpo,
              // como o do Spurgeon, que tem folga própria na foto.
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Image.asset(
                    persona.foto,
                    width: tamanho,
                    height: tamanho,
                    fit: BoxFit.cover,
                    // A foto é mais alta que larga e o cabelo encosta na borda
                    // superior: qualquer corte em cima corta o cabelo. Alinhada
                    // ao topo, a sobra do BoxFit.cover cai toda na blusa.
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  final _controle = TextEditingController();
  final _rolagem = ScrollController();

  /// A conversa nova recebe o id só na primeira mensagem (o `Conversador`
  /// chama o Estado); quando isso acontece, a URL ganha o id no lugar de
  /// `/conversa`, para um F5 ou um link reabrirem a conversa de verdade.
  bool _rotaAtualizada = false;

  /// O turno da conversa: registra a pergunta, chama a IA e grava a resposta.
  ///
  /// Nasce depois do primeiro frame (precisa do [EscopoDoEstado], que não
  /// pode ser consultado no initState) e morre com a tela. Vive no lugar do
  /// `_respondendo`/`_erro`/`_ultimaPergunta` que o widget guardava: a tela
  /// só desenha, e o fluxo inteiro é testável (ver `test/conversador_test.dart`).
  Conversador? _conversador;

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
      _conversador = Conversador(
        persona: widget.persona,
        estado: EscopoDoEstado.de(context),
        chamar: perguntar,
        conversaId: widget.conversaId,
      );
      _conversador!.addListener(_aoMudarConversador);
      // Reabrir depois de uma resposta interrompida: a última pergunta ficou
      // pendente, e a tela oferece "Tentar de novo" em vez de deixar a
      // pergunta respondida pelo silêncio.
      _conversador!.retomarInterrompida();
    });
  }

  @override
  void dispose() {
    // O dispose também roda dentro do build (o do desmonte da rota), então a
    // contagem volta depois do frame, como no initState.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => camadasFlutuantes.value--);
    _conversador?.removeListener(_aoMudarConversador);
    _conversador?.dispose();
    _controle.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  /// O conversador notificou (resposta chegou, erro, interrupção): redesenhar
  /// o rodapé e rolar para o fim quando uma resposta começa a vir.
  void _aoMudarConversador() {
    if (!mounted) return;
    setState(() {});
    if (_conversador?.respondendo ?? false) _rolarParaOFim();
    // A conversa nova acabou de ganhar o id; a URL precisa acompanhar, para
    // um F5 ou um link compartilhado reabrirem esta conversa e não outra.
    final id = _conversador?.id;
    if (id != null && widget.conversaId == null && !_rotaAtualizada) {
      _rotaAtualizada = true;
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.replace('/${widget.persona.slug}/conversa/$id');
      }
    }
  }

  Future<void> _enviar() async {
    final texto = _controle.text.trim();
    final conversador = _conversador;
    if (texto.isEmpty || conversador == null || conversador.respondendo) {
      return;
    }
    _controle.clear();
    await conversador.enviar(texto);
  }

  Future<void> _limparConversa() async {
    final id = _conversador?.id;
    if (id == null) return;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar esta conversa?'),
        content: const Text(
          'Só esta conversa será apagada deste aparelho, e da cópia na nuvem '
          'se houver. As outras conversas ficam. Essa ação não pode ser '
          'desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    await EscopoDoEstado.de(context).limparConversa(widget.persona.id, id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _rolarParaOFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rolagem.hasClients) return;
      _rolagem.jumpTo(_rolagem.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);
    final conversador = _conversador;
    final respondendo = conversador?.respondendo ?? false;
    // A conversa aberta: a que veio na rota (existe antes do conversador
    // nascer) ou a que nasceu na primeira pergunta de uma conversa nova.
    final conversaId = conversador?.id ?? widget.conversaId;
    // O corte do teto de mensagens acontece no Estado; a tela só pergunta se
    // a conversa aberta foi cortada para mostrar o aviso quieto no topo.
    final cortada = conversaId != null &&
        (estado.conversaDe(widget.persona.id, conversaId)?.cortada ?? false);

    return Scaffold(
      appBar: AppBar(
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
            const SizedBox(width: 10),
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
              icon: const Icon(Icons.delete_outline),
              onPressed: _limparConversa,
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
                  return _BoasVindas(persona: widget.persona);
                }
                // O cabeçalho (o Filete) é o índice 0; as mensagens vêm depois.
                return ListView.builder(
                  controller: _rolagem,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: mensagens.length + 1 + (cortada ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      // A conversa abre como página: o Filete que abre cada
                      // leitura da Estante sinaliza onde o fio começa.
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: Center(child: Filete(largura: 64)),
                      );
                    }
                    if (cortada && i == 1) {
                      // A conversa passou do teto e as falas mais antigas
                      // saíram do histórico: a nota quieta explica por que a
                      // conversa não começa na primeira pergunta.
                      return const _AvisoDeCorte();
                    }
                    return _BalcaoDeMensagem(
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Bolha(
                  avatar: widget.persona.foto,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cor.secondary,
                    ),
                  ),
                ),
              ),
            ),
          if (conversador?.erro != null)
            _ErroDeResposta(
              persona: widget.persona,
              mensagem: conversador!.erro!,
              aoTentarDeNovo: conversador.repetir,
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Respostas geradas por inteligência artificial',
                    style: tema.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _controle,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviar(),
                    decoration: InputDecoration(
                      // Enquanto a resposta vem, o campo diz o estado em vez de
                      // engolir o envio em silêncio; o rascunho continua lá.
                      hintText: respondendo
                          ? 'aguarde a resposta...'
                          : 'Escreva para ${widget.persona.nome}...',
                      suffixIcon: respondendo
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Enviar',
                              icon: Icon(Icons.send, color: cor.primary),
                              onPressed: _enviar,
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
  }
}

/// Primeira visita: o retrato, o nome e a fala de boas-vindas da persona, no
/// lugar da lista vazia.
class _BoasVindas extends StatelessWidget {
  const _BoasVindas({required this.persona});

  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cor.primary, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Image.asset(
                    persona.foto,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // A carta de boas-vindas também é página: abre pelo Filete, como
            // toda leitura da Estante.
            const Filete(largura: 64),
            const SizedBox(height: 12),
            Text(persona.nome, style: tema.headlineSmall),
            const SizedBox(height: 10),
            Text(
              persona.boasVindas,
              textAlign: TextAlign.center,
              style: tema.bodyLarge?.copyWith(
                color: cor.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma mensagem da conversa: a resposta da persona entra como citação das
/// introduções (fundo chapado e fio do metal à esquerda), e a pergunta do
/// visitante recua em pergaminho com um fio mais discreto. Nada aqui é
/// elevado nem usa o metal como fundo: a palavra da persona é o elemento
/// mais alto da página, não a caixa do visitante.
class _BalcaoDeMensagem extends StatelessWidget {
  const _BalcaoDeMensagem({required this.mensagem, required this.persona});

  final Mensagem mensagem;
  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final usuario = mensagem.doUsuario;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            usuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!usuario) ...[
            ClipOval(
              child: Image.asset(
                persona.foto,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: usuario
                    ? cor.surfaceContainer
                    : cor.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: usuario
                    ? Border.all(
                        color: cor.primary.withValues(alpha: 0.4),
                        width: 1,
                      )
                    : Border(
                        left: BorderSide(color: cor.primary, width: 3),
                      ),
              ),
              child: Text(
                mensagem.texto,
                style: tema.bodyMedium?.copyWith(
                  color: cor.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bolha pequena usada pelo indicador de "pensando": avatar e recipiente
/// idênticos aos das mensagens, para o rodapé não parecer elemento diferente.
class _Bolha extends StatelessWidget {
  const _Bolha({required this.avatar, required this.child});

  final String avatar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipOval(
          child: Image.asset(
            avatar,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            // Mesmo recorte das mensagens: o cabelo encosta na borda de cima
            // da foto, e qualquer corte desloca o rosto para fora do centro.
            alignment: Alignment.topCenter,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cor.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: cor.primary, width: 3),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// A conversa passou do teto de mensagens e as falas mais antigas saíram do
/// histórico. A nota quieta mora no topo da lista, logo abaixo do Filete,
/// explicando por que a conversa não começa na primeira pergunta.
class _AvisoDeCorte extends StatelessWidget {
  const _AvisoDeCorte();

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: cor.primary, width: 3),
          ),
        ),
        child: Text(
          'As falas mais antigas saíram quando esta conversa passou do '
          'limite de mensagens.',
          style: tema.bodySmall?.copyWith(
            color: cor.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// O aviso de resposta que não veio, com o motivo e o botão de tentar de
/// novo. Não é parte do histórico: some sozinho quando a próxima tentativa
/// começa.
class _ErroDeResposta extends StatelessWidget {
  const _ErroDeResposta({
    required this.persona,
    required this.mensagem,
    required this.aoTentarDeNovo,
  });

  final Persona persona;
  final String mensagem;

  /// Refaz a última pergunta (o `Conversador` guarda o texto dela).
  final Future<void> Function() aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipOval(
              child: Image.asset(
                // O rosto de quem não respondeu: no chat do Felipe, o erro não
                // pode mostrar o Spurgeon.
                persona.foto,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                decoration: BoxDecoration(
                  color: cor.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(color: cor.primary, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mensagem,
                      style: tema.bodyMedium?.copyWith(
                        color: cor.error,
                        height: 1.4,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => aoTentarDeNovo(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar de novo'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}