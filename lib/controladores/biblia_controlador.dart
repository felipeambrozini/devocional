import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../dados/canon.dart';
import '../dados/estado.dart';
import '../dados/voz.dart';
import '../funcoes/aviso.dart';
import '../telas/busca.dart';
import '../widgets/widgets.dart';

/// Estado e ações do leitor da Bíblia: livro e capítulo atuais, a rolagem, a
/// navegação entre capítulos (seta, deslize, grade) e a rolagem até o
/// versículo pedido por link, nota ou busca. A tela só monta a UI e escuta
/// este controller — toda decisão mora aqui.
class BibliaControlador extends ChangeNotifier {
  BibliaControlador({String? livroInicial, int? capituloInicial})
    : livro = livroInicial ?? 'genesis',
      capitulo = capituloInicial ?? 1;

  String livro;
  int capitulo;
  final rolagem = ScrollController();

  /// Uma única vez por instância: a aba retoma a última leitura, e quem
  /// chegou com destino explícito registra esse destino como última leitura.
  bool inicializada = false;

  /// Onde cai o versículo pedido por link, nota ou busca (`destacar` da
  /// tela). GlobalKey porque o `Scrollable.ensureVisible` precisa do item já
  /// construído; sem ele não há como achar o versículo dentro do capítulo.
  final chaveDoAlvoDeRolagem = GlobalKey();
  bool rolouAteOAlvo = false;

  /// Marcado no [dispose]: os loops de tentativa de [rolarAteOAlvo] rodam por
  /// vários frames, e o controller não tem `mounted` como um State para
  /// cortar o loop cedo quando a tela some no meio do caminho.
  bool _descartado = false;

  @override
  void dispose() {
    _descartado = true;
    rolagem.dispose();
    super.dispose();
  }

  Livro get livroAtual => livroPorSlug(livro) ?? canon.first;

  /// Se vale a pena gastar uma faixa do rodapé com os chevrons de capítulo.
  ///
  /// No celular não vale: deslizar já passa a página, e a barra ficava logo
  /// acima da barra de navegação repetindo o que o dedo faz. Na web vale,
  /// porque ali quem usa só o mouse não tem gesto: arrastar com o botão
  /// apertado funciona, mas ninguém descobre isso, e as setas do teclado também
  /// não se anunciam. Mesmo lá é escolha: quem navega pelo teclado esconde os
  /// botões na folha de ajustes ([Estado.setasDoRodape]).
  ///
  /// É a única ramificação por plataforma do app, e existe porque a forma de
  /// apontar muda de verdade entre elas. A web pode estar num desktop sem
  /// toque, então entra pelo pior caso.
  bool get semGestoDeToque => kIsWeb;

  /// Decide a leitura inicial da aba (ou registra o destino explícito) sempre
  /// que as dependências do widget mudam. `ativa` vem do `TickerMode` do
  /// context: o go_router envolve cada aba em Offstage + TickerMode, e a
  /// troca de aba liga e desliga o TickerMode, o que acorda este método
  /// quando a aba Bíblia volta à frente.
  void aoChangeDependencies({
    required BuildContext context,
    required bool ativa,
    required String? livroInicial,
    required int? capituloInicial,
    required Estado estado,
  }) {
    final ultima = estado.ultimaLeitura;

    if (livroInicial != null) {
      // Quem chegou com destino explícito (link, busca, nota, faixa) também
      // está lendo: esse destino vira a última leitura, para a aba Bíblia
      // abrir nele na próxima vez.
      if (!inicializada) {
        inicializada = true;
        final destinoLivro = livroInicial;
        final destinoCapitulo = capituloInicial ?? 1;
        // Depois do frame: registrarLeitura avisa a árvore, e avisar no meio
        // do ciclo de build é proibido.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            estado.registrarLeitura(destinoLivro, destinoCapitulo);
          }
        });
      }
      return;
    }

    // A aba: na primeira vez retoma a última leitura; nas seguintes, reabre
    // o último livro quando ele mudou por fora (tela empurrada, link, toque
    // de lembrete) e a aba volta à frente.
    if (!inicializada) {
      inicializada = true;
      if (ultima != null) {
        livro = ultima.$1;
        capitulo = ultima.$2;
      }
    } else if (ativa &&
        ultima != null &&
        (ultima.$1 != livro || ultima.$2 != capitulo)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) irPara(context, ultima.$1, ultima.$2);
      });
    }
  }

  void irPara(BuildContext context, String novoLivro, int novoCapitulo) {
    // Um áudio tocando do capítulo antigo não pode continuar: o botão de
    // parar dele saiu da tela, e a leitura nova começa do zero. Um preparo em
    // curso não para aqui: o áudio ainda não toca, e o "Desfazer" do deslize
    // devolve a voz que ficou pronta.
    if (Voz.instancia.tocando || Voz.instancia.pausado) {
      Voz.instancia.parar();
    }
    livro = novoLivro;
    capitulo = novoCapitulo;
    notifyListeners();
    EscopoDoEstado.de(context).registrarLeitura(novoLivro, novoCapitulo);
    if (rolagem.hasClients) rolagem.jumpTo(0);
  }

  void passarCapitulo(BuildContext context, int passo) {
    final destino = capitulo + passo;
    if (destino >= 1 && destino <= livroAtual.capitulos) {
      irPara(context, livro, destino);
      return;
    }
    // Passa para o livro vizinho em vez de travar no fim do último capítulo.
    final ordem = posicaoNoCanon(livro);
    final vizinho = ordem + passo;
    if (vizinho < 0 || vizinho >= canon.length) return;
    final novoLivro = canon[vizinho];
    irPara(context, novoLivro.slug, passo > 0 ? 1 : novoLivro.capitulos);
  }

  void abrirBusca(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const TelaBusca()),
  );

  /// Grade de capítulos do livro aberto, direto pelo título do capítulo no
  /// corpo: um passo em vez dos dois do seletor de livros, e o caminho que
  /// não depende do deslize (que é invisível para quem chegou agora).
  Future<void> abrirGradeDeCapitulos(BuildContext context) async {
    final livroEscolhido = livroAtual;
    final capituloEscolhido = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => DevocionalFolhaDeCapitulos(livro: livroEscolhido),
    );
    if (capituloEscolhido != null && context.mounted) {
      irPara(context, livroEscolhido.slug, capituloEscolhido);
    }
  }

  Future<void> abrirSeletor(BuildContext context) async {
    final destino = await showModalBottomSheet<(String, int)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DevocionalSeletorDeLivro(livroAtual: livro),
    );
    if (destino != null && context.mounted) {
      irPara(context, destino.$1, destino.$2);
    }
  }

  /// Depois do capítulo aberto por link, nota ou busca, rola até o versículo
  /// pedido: quem chega por `?ler=joao.3.16` quer o versículo, não o topo do
  /// capítulo. Roda uma vez por abertura.
  void rolarAteOAlvoSePreciso((int, int)? destacar) {
    if (destacar == null || rolouAteOAlvo) return;
    rolouAteOAlvo = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => rolarAteOAlvo(destacar.$1),
    );
  }

  void rolarAteOAlvo(int versiculo) {
    var tentativas = 0;
    void tentar() {
      final contexto = chaveDoAlvoDeRolagem.currentContext;
      if (contexto != null) {
        Scrollable.ensureVisible(
          contexto,
          alignment: 0.3,
          duration: MediaQuery.disableAnimationsOf(contexto)
              ? Duration.zero
              : const Duration(milliseconds: 350),
        );
        return;
      }
      if (_descartado || ++tentativas >= 90 || !rolagem.hasClients) return;
      // Estimativa bruta primeiro: corpo em 17 com altura 1.6, mais o respiro
      // de 24 dp do versículo. Só precisa chegar perto do item; o
      // ensureVisible acima ajusta o resto.
      if (tentativas == 1) {
        rolagem.jumpTo(
          ((versiculo - 1) * 51)
              .clamp(0.0, rolagem.position.maxScrollExtent)
              .toDouble(),
        );
      } else if (tentativas > 3) {
        // A estimativa errou (uma introdução aberta, por exemplo): avança em
        // blocos até o item entrar na árvore.
        rolagem.jumpTo(
          (rolagem.offset + 400)
              .clamp(0.0, rolagem.position.maxScrollExtent)
              .toDouble(),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => tentar());
    }

    tentar();
  }

  void aoArrastarCapitulo(BuildContext context, DragEndDetails detalhe) {
    final horizontal = detalhe.primaryVelocity ?? 0;
    final vertical = detalhe.velocity.pixelsPerSecond.dy;
    // O corpo inteiro é um detector de arrasto horizontal em volta de uma
    // lista vertical. Sem dominância clara, um flick horizontal durante a
    // rolagem trocava de capítulo em silêncio; aqui o horizontal precisa
    // vencer o vertical por 2,5x para valer.
    if (horizontal.abs() < 250) return;
    if (vertical.abs() * 2.5 > horizontal.abs()) return;
    passarCapituloComDesfazer(context, horizontal < 0 ? 1 : -1);
  }

  /// Passa de capítulo pelo deslize e oferece voltar: o deslize é o único
  /// jeito de trocar de capítulo no toque, e um acidente não pode custar o
  /// lugar na Escritura sem um "Desfazer" à mão. Setas e chevrons não passam
  /// por aqui: são escolhas explícitas e não pedem volta.
  void passarCapituloComDesfazer(BuildContext context, int passo) {
    // O tooltip do deslize some quando o gesto acontece de verdade: um toque
    // distraído na alça não pode apagar o único aviso do gesto (o antigo
    // onPointerDown fazia isso); só o uso do gesto que ele ensina dispensa.
    final estado = EscopoDoEstado.de(context);
    if (!estado.swipeTooltipDispensado) {
      estado.dispensarSwipeTooltip();
    }
    final livroAnterior = livro;
    final capituloAnterior = capitulo;
    // A voz em curso (tocando, pausada ou no preparo) tem de voltar junto
    // com a página: desfazer o deslize sem devolver o áudio seria desfazer
    // pela metade.
    final chaveDaLeitura = Voz.instancia.tocandoChave;
    passarCapitulo(context, passo);
    mostrarAviso(
      context,
      '${livroAtual.nome} $capitulo',
      rotuloDeAcao: 'Desfazer',
      aoAgir: () {
        if (!context.mounted) return;
        irPara(context, livroAnterior, capituloAnterior);
        if (chaveDaLeitura != null) {
          Voz.instancia.retomar(
            chaveDeCapitulo(livroAnterior, capituloAnterior),
            de: Voz.instancia.desdeAParada,
          );
        }
      },
    );
  }
}
