import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/voz.dart';
import 'ancora_de_foco.dart';
import 'layout_leitura.dart';

/// Uma aba da [DevocionalMoldura]: o que a barra de navegação mostra, o
/// caminho da rota e a tela que a rota abre (as rotas ficam em `main.dart`).
class DestinoDaMoldura {
  const DestinoDaMoldura(
    this.rotulo,
    this.caminho,
    this.icone,
    this.iconeAtivo,
    this.tela,
  );

  final String rotulo;

  /// Sem acento de propósito, ainda que o rótulo tenha ("Bíblia"): é o que
  /// vira caminho na URL, e o resto do app (canon.dart, chaves de Leitura)
  /// também evita acento em identificador para não depender de como cada
  /// camada decide escapar.
  final String caminho;
  final FaIconData icone;
  final FaIconData iconeAtivo;
  final Widget tela;
}

/// Casca de navegação. Barra inferior no celular, trilho lateral em tela larga.
/// O corte em 720 px é onde seis rótulos deixam de caber com folga na horizontal.
///
/// Sem estado próprio: quem sabe a aba atual é o [navigationShell], do
/// GoRouter — duplicar isso num `_indice` local só criaria duas fontes de
/// verdade para a mesma coisa.
class DevocionalMoldura extends StatelessWidget {
  const DevocionalMoldura({
    super.key,
    required this.navigationShell,
    required this.destinos,
    required this.escoposDasAbas,
  });

  final StatefulNavigationShell navigationShell;

  /// As abas, na ordem dos ramos do [navigationShell].
  final List<DestinoDaMoldura> destinos;

  /// O nó de foco de cada aba, na mesma ordem de [destinos]: os mesmos nós
  /// que as rotas de `main.dart` põem em volta de cada tela.
  final List<FocusScopeNode> escoposDasAbas;

  /// Encolhe o rótulo da barra de baixo só o bastante para o mais longo caber
  /// numa linha. Com seis destinos cada um tem 65px a 390px, e "Devocional" a
  /// 11px já mede 64px antes da escala de fonte do sistema: o Flutter quebrava a
  /// palavra em "Devociona/l". Nulo mantém o estilo do tema quando já cabe.
  WidgetStateProperty<TextStyle?>? _rotuloQueCabeNaBarra(BuildContext context) {
    final doTema = NavigationBarTheme.of(context).labelTextStyle?.resolve({});
    final tamanho = doTema?.fontSize;
    if (doTema == null || tamanho == null) return null;
    // O rótulo herda o DefaultTextStyle do Material (bodyMedium), que traz o
    // letterSpacing da tipografia do Flutter: medir sem ele erra por ~2,5px.
    final estilo =
        Theme.of(context).textTheme.bodyMedium?.merge(doTema) ?? doTema;
    // Mesmo teto de escala que o NavigationBar aplica ao rótulo.
    final escala = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    // A barra fica dentro de uma SafeArea: o recorte lateral da tela come espaço.
    final larguraPorDestino =
        (MediaQuery.sizeOf(context).width -
            MediaQuery.paddingOf(context).horizontal) /
        destinos.length;
    double maisLongoCom(double tamanhoDaFonte) {
      var maisLongo = 0.0;
      for (final d in destinos) {
        final pintor = TextPainter(
          text: TextSpan(
            text: d.rotulo,
            style: estilo.copyWith(fontSize: tamanhoDaFonte),
          ),
          textScaler: escala,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        if (pintor.width > maisLongo) maisLongo = pintor.width;
        pintor.dispose();
      }
      return maisLongo;
    }

    final maisLongo = maisLongoCom(tamanho);
    if (maisLongo <= larguraPorDestino) return null;
    // A largura não cai na proporção do corpo (o letterSpacing não encolhe
    // junto): a proporção é só o ponto de partida, e a medida desce de 0,25 em
    // 0,25 até caber. Assim fica o maior tamanho possível, e quem usa a fonte
    // do sistema maior não perde mais do que o espaço obriga.
    var ajustado = tamanho * larguraPorDestino / maisLongo;
    while (ajustado > 6 && maisLongoCom(ajustado) > larguraPorDestino) {
      ajustado -= 0.25;
    }
    return WidgetStatePropertyAll(estilo.copyWith(fontSize: ajustado));
  }

  void _irParaAba(int i) {
    // A leitura para ao sair da Bíblia: o shell mantém as abas vivas em
    // Offstage, e o botão de parar sai da tela junto com o leitor. A mesma
    // regra do _ObservadorDaVoz (em `main.dart`) para as rotas empurradas por
    // cima.
    //
    // Pausada de fora (chamada, perda de foco de áudio), a sessão sobrevive
    // à troca de aba: nada está tocando, a regra do botão à vista não se
    // aplica, e quem volta encontra o "Pausado. Toque para retomar." no
    // lugar exato em que a interrupção o deixou.
    if (i != navigationShell.currentIndex && !Voz.instancia.pausado) {
      Voz.instancia.parar();
    }
    // Folhas e diálogos abertos moram no Navigator da aba (não no raiz), então
    // sobreviveriam à troca e reapareceriam ao voltar para ela.
    navigationShell
        .route
        .branches[navigationShell.currentIndex]
        .navigatorKey
        .currentState
        ?.popUntil((rota) => rota is! PopupRoute);
    navigationShell.goBranch(
      i,
      // A aba Plano sempre reabre em Meus Planos: diferente da Bíblia (que
      // preserva capítulo e rolagem de propósito), não faz sentido continuar
      // vendo um plano específico depois de ir para outra aba e voltar —
      // ver a lixeira e o resto da navegação de planos em telas/plano.dart.
      initialLocation:
          i == navigationShell.currentIndex || destinos[i].caminho == 'plano',
    );
    // Depois do frame: antes dele a aba de destino ainda não está na frente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final escopo = escoposDasAbas[i];
      // Pedir foco ao escopo deixava o foco no nó do próprio escopo, que fica
      // acima da tela: a tecla subia por fora dos atalhos dela e nada acontecia.
      // O foco precisa cair num nó de dentro, e invisível: no primeiro botão
      // da tela ele ganhava o realce de foco sem ninguém ter tocado nele. Os
      // descendentes vêm dos mais fundos para os de fora, então a âncora que
      // uma tela põe dentro dos próprios atalhos (Bíblia, leitor de livro)
      // ganha da que a rota põe em volta de toda tela.
      //
      // A busca é no Navigator da aba, não só no escopo da rota raiz: um
      // capítulo da Biblioteca ou um plano aberto são rotas próprias por cima
      // dela, e o foco caía no sumário escondido por baixo (as setas do
      // leitor paravam de responder). Só vale a âncora da rota à vista.
      final navegador =
          navigationShell.route.branches[i].navigatorKey.currentState;
      final ancora = navegador?.focusNode.descendants
          .whereType<NoDeAncoraDeFoco>()
          .where((no) {
            final contexto = no.context;
            return contexto != null &&
                (ModalRoute.of(contexto)?.isCurrent ?? false);
          })
          .firstOrNull;
      (ancora ?? escopo).requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => _conteudo(context);

  Widget _conteudo(BuildContext context) {
    final largo = telaLarga(context);

    // A DevocionalLarguraDeLeitura não fica aqui. Envolvendo o shell inteiro, ela prendia
    // também a AppBar e a régua de meses do Plano numa faixa de 720 px no meio da
    // janela, e deixava de fora as telas abertas por push (como "Sobre" e o
    // "Continuar leitura"), que nascem no Navigator raiz: o mesmo leitor ficava
    // com 720 px pela aba e com a janela inteira quando aberto por fora. Agora
    // cada tela limita o próprio corpo, e a moldura ocupa a janela como um app
    // da web deve.
    if (!largo) {
      // Em tela estreita as conversas moram na aba Conversas, e o texto de
      // leitura não disputa viewport com ninguém.
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex.clamp(
            0,
            destinos.length - 1,
          ),
          onDestinationSelected: _irParaAba,
          labelTextStyle: _rotuloQueCabeNaBarra(context),
          destinations: [
            for (final d in destinos)
              NavigationDestination(
                icon: FaIcon(d.icone),
                selectedIcon: FaIcon(d.iconeAtivo),
                label: d.rotulo,
              ),
          ],
        ),
      );
    }

    // Em telas largas a aba Conversas continua no trilho: uma entrada só
    // para o chat, sem atalho flutuante duplicado.
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _irParaAba,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in destinos)
                NavigationRailDestination(
                  icon: FaIcon(d.icone),
                  selectedIcon: FaIcon(d.iconeAtivo),
                  label: Text(d.rotulo),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
