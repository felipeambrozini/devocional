import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Avisa uma vez quando a pessoa chega ao fim de um capítulo, para o leitor
/// marcar a leitura sozinho: o capítulo de um livro da Biblioteca e o dia do
/// plano na Bíblia.
///
/// Envolve a rolagem do capítulo ([child]) e conta como fim:
/// - rolar até embaixo com o dedo, a roda do mouse, o teclado (PageDown,
///   setas, espaço) ou o leitor de tela. Rolagem feita pelo app sozinha não
///   conta: a Biblioteca volta ao ponto em que se parou com um `jumpTo`, e a
///   Bíblia leva ao versículo pedido com `ensureVisible`; uma posição salva no
///   fim marcaria o capítulo só por abri-lo. Com leitor de tela, o foco de
///   leitura rola a página do mesmo jeito que o app, então ali qualquer
///   chegada ao fim conta;
/// - ou, num capítulo curto que cabe na tela sem rolar, ficar com ele aberto
///   por [esperaSemRolagem], com o app à vista e nada aberto por cima (o
///   seletor, as notas). Sem isso, capítulo curto nunca seria marcado.
///
/// Avisa no máximo uma vez por capítulo: se a pessoa desmarcar à mão depois,
/// não marca de novo. Trocar [chave] (outro capítulo na mesma tela, como a
/// Bíblia faz com o mesmo controlador de rolagem) recomeça do zero.
class TabernaculoVigiaDoFim extends StatefulWidget {
  const TabernaculoVigiaDoFim({
    super.key,
    required this.chave,
    required this.rolagem,
    required this.aoChegarAoFim,
    required this.child,
  });

  /// O que se lê agora ("joao.3", o índice do capítulo).
  final Object chave;

  /// A rolagem de [child], para saber se o capítulo cabe na tela.
  final ScrollController rolagem;

  final VoidCallback aoChegarAoFim;

  final Widget child;

  /// Quanto um capítulo que cabe na tela precisa ficar aberto. Testes trocam
  /// por um valor curto, como os outros `...ParaTeste` do projeto.
  static Duration esperaSemRolagem = const Duration(seconds: 20);

  @override
  State<TabernaculoVigiaDoFim> createState() => _VigiaDoFimState();
}

class _VigiaDoFimState extends State<TabernaculoVigiaDoFim>
    with WidgetsBindingObserver {
  bool _avisou = false;
  bool _usuarioRolou = false;
  Timer? _espera;
  bool _appAVista = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conferirSeCabeNaTela();
  }

  @override
  void didUpdateWidget(covariant TabernaculoVigiaDoFim antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.chave != widget.chave) {
      _avisou = false;
      _usuarioRolou = false;
      _espera?.cancel();
      _conferirSeCabeNaTela();
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState ciclo) {
    _appAVista = ciclo == AppLifecycleState.resumed;
  }

  /// Depois do quadro, quando a rolagem já sabe o tamanho do capítulo.
  void _conferirSeCabeNaTela() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _avisou) return;
      final rolagem = widget.rolagem;
      if (!rolagem.hasClients) return;
      if (rolagem.position.maxScrollExtent > 0) return;
      _espera?.cancel();
      _espera = Timer(TabernaculoVigiaDoFim.esperaSemRolagem, _aoAcabarAEspera);
    });
  }

  void _aoAcabarAEspera() {
    if (!mounted || _avisou) return;
    final rolagem = widget.rolagem;
    // O capítulo cresceu (comentários carregados, letra maior): agora o fim
    // é rolar até embaixo.
    if (rolagem.hasClients && rolagem.position.maxScrollExtent > 0) return;
    // App em segundo plano ou outra tela por cima: ninguém está lendo. Tenta
    // de novo depois, em vez de desistir de vez.
    if (!_appAVista || ModalRoute.of(context)?.isCurrent == false) {
      _espera = Timer(TabernaculoVigiaDoFim.esperaSemRolagem, _aoAcabarAEspera);
      return;
    }
    _avisar();
  }

  void _avisar() {
    _avisou = true;
    _espera?.cancel();
    widget.aoChegarAoFim();
  }

  bool _aoRolar(ScrollNotification aviso) {
    // Só a rolagem do capítulo, não uma lista de dentro dele.
    if (aviso.depth != 0 || _avisou) return false;
    // Dedo e roda do mouse avisam a direção do usuário.
    if (aviso is UserScrollNotification &&
        aviso.direction != ScrollDirection.idle) {
      _usuarioRolou = true;
    }
    if (MediaQuery.accessibleNavigationOf(context)) _usuarioRolou = true;
    // No fim da rolagem, não a cada passo: a lista da Bíblia é preguiçosa e só
    // sabe a altura de verdade quando o fim já foi montado.
    if (aviso is ScrollEndNotification &&
        _usuarioRolou &&
        aviso.metrics.maxScrollExtent > 0 &&
        aviso.metrics.extentAfter <= 1) {
      _avisar();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _aoTeclar,
    child: NotificationListener<ScrollNotification>(
      onNotification: _aoRolar,
      child: widget.child,
    ),
  );

  /// Teclado: PageDown, setas e espaço rolam com animação, sem a direção do
  /// usuário. Qualquer tecla com o foco dentro do capítulo conta como a pessoa
  /// mexendo nele; o evento segue adiante para quem o trata.
  KeyEventResult _aoTeclar(FocusNode _, KeyEvent evento) {
    if (evento is KeyDownEvent) _usuarioRolou = true;
    return KeyEventResult.ignored;
  }
}
