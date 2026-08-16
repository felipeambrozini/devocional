import 'package:flutter/material.dart';

import '../data/estado.dart';
import '../data/ia.dart';
import '../data/modelos.dart';
import '../data/personas.dart';

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
    return Tooltip(
      message: 'Conversar com ${persona.nome}',
      child: Semantics(
        button: true,
        label: 'Abrir conversa com ${persona.nome}',
        child: Material(
          color: cor.surfaceContainer,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cor.primary, width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    persona.foto,
                    width: 52,
                    height: 52,
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
class TelaChat extends StatefulWidget {
  const TelaChat({super.key, required this.persona});

  final Persona persona;

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> {
  final _controle = TextEditingController();
  final _rolagem = ScrollController();

  bool _respondendo = false;

  /// Falha da última tentativa, mostrada num balão de erro no rodapé da
  /// conversa com o botão de tentar de novo. Vive só na tela: um erro não é
  /// parte do histórico e não deve ser persistido.
  String? _erro;

  /// A pergunta que está no ar, para o "Tentar de novo" refazê-la sem que o
  /// usuário precise redigitar.
  String _ultimaPergunta = '';

  @override
  void initState() {
    super.initState();
    // O chat é uma tela empurrada por cima das abas, e os balões são irmãos
    // do Navigator: sem isto, o botão do chat flutuaria por cima do chat.
    // O aviso precisa sair do meio do build: incrementar aqui dentro
    // notificaria os balões enquanto a árvore ainda monta o chat, e o
    // framework proíbe marcar um widget para reconstruir nessa fase (assert
    // em debug). Depois do frame o efeito é o mesmo, sem a exceção.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => camadasFlutuantes.value++);
  }

  @override
  void dispose() {
    // O dispose também roda dentro do build (o do desmonte da rota), então a
    // contagem volta depois do frame, como no initState.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => camadasFlutuantes.value--);
    _controle.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _controle.text.trim();
    if (texto.isEmpty || _respondendo) return;
    _controle.clear();
    final estado = EscopoDoEstado.de(context);
    await estado.registrarMensagem(
      widget.persona.id,
      Mensagem(
        id: novoIdDeMensagem(),
        papel: 'user',
        texto: texto,
        momento: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _perguntar(texto);
  }

  /// Chama a Gemini com a pergunta já registrada no histórico. Quem chama é o
  /// envio de uma mensagem nova ou o "Tentar de novo" depois de uma falha.
  Future<void> _perguntar(String pergunta) async {
    setState(() {
      _respondendo = true;
      _erro = null;
      _ultimaPergunta = pergunta;
    });
    _rolarParaOFim();

    final estado = EscopoDoEstado.de(context);
    try {
      final resposta = await perguntar(
        persona: widget.persona,
        historico: estado.mensagensDe(widget.persona.id),
        pergunta: pergunta,
      );
      if (!mounted) return;
      await estado.registrarMensagem(
        widget.persona.id,
        Mensagem(
          id: novoIdDeMensagem(),
          papel: 'assistant',
          texto: resposta,
          momento: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } on IaException catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagem);
    } finally {
      if (mounted) setState(() => _respondendo = false);
    }
  }

  Future<void> _limparConversa() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar a conversa?'),
        content: const Text(
          'Todo o histórico com esta pessoa será apagado deste aparelho. '
          'Essa ação não pode ser desfeita.',
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
    await EscopoDoEstado.de(context).limparConversa(widget.persona.id);
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.persona.nome, style: tema.titleLarge),
                Text(widget.persona.titulo, style: tema.labelMedium),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Apagar a conversa',
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
                final mensagens = estado.mensagensDe(widget.persona.id);
                if (mensagens.isEmpty) {
                  return _BoasVindas(persona: widget.persona);
                }
                return ListView.builder(
                  controller: _rolagem,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: mensagens.length,
                  itemBuilder: (context, i) => _BalcaoDeMensagem(
                    mensagem: mensagens[i],
                    persona: widget.persona,
                  ),
                );
              },
            ),
          ),
          if (_respondendo)
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
          if (_erro != null)
            _ErroDeResposta(
              mensagem: _erro!,
              pergunta: _ultimaPergunta,
              aoTentarDeNovo: _perguntar,
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Respostas geradas por inteligência artificial gratuita',
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
                      hintText: 'Escreva para ${widget.persona.nome}...',
                      suffixIcon: IconButton(
                        tooltip: 'Enviar',
                        icon: Icon(
                          Icons.send,
                          color: _respondendo ? cor.outline : cor.primary,
                        ),
                        onPressed: _respondendo ? null : _enviar,
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
            ClipOval(
              child: Image.asset(
                persona.foto,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(height: 18),
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

/// Um balão de mensagem: o do usuário à direita no metal do tema, o da
/// persona à esquerda com o retrato, no mesmo estilo de cartão do app.
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
                    ? cor.primary
                    : cor.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(usuario ? 14 : 4),
                  bottomRight: Radius.circular(usuario ? 4 : 14),
                ),
              ),
              child: Text(
                mensagem.texto,
                style: tema.bodyMedium?.copyWith(
                  color: usuario ? cor.onPrimary : cor.onSurface,
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
            alignment: const Alignment(0, -0.85),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cor.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(14),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// O balão de erro com o motivo e o botão de tentar de novo. Não é parte do
/// histórico: some sozinho quando a próxima tentativa começa.
class _ErroDeResposta extends StatelessWidget {
  const _ErroDeResposta({
    required this.mensagem,
    required this.pergunta,
    required this.aoTentarDeNovo,
  });

  final String mensagem;
  final String pergunta;
  final Future<void> Function(String pergunta) aoTentarDeNovo;

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
                'assets/images/spurgeon.webp',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                decoration: BoxDecoration(
                  color: cor.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(14),
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
                      onPressed: () => aoTentarDeNovo(pergunta),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar de novo'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
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