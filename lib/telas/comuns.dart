import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/lembretes.dart';
import '../data/modelos.dart';
import '../data/nuvem.dart';
import '../data/personas.dart';
import '../data/planos_nuvem.dart';
import '../data/recursos.dart';
import '../data/voz.dart';
import '../spacing.dart';
import 'faixa.dart';

/// Um [SelectionArea] com "Compartilhar" a mais no menu de seleção. O texto
/// vira selecionável e copiável de fábrica (o próprio SelectionArea resolve
/// isso), e o mesmo clique forte que hoje abre a seleção nativa passa a
/// mostrar, junto com Copiar, um botão que compartilha o trecho escolhido —
/// sem um gesto novo. Sem formatação de referência: o trecho selecionado
/// pode ser parte de um versículo, um parágrafo do devocional ou da
/// introdução, sem uma referência única por trás. Usada igual nas três
/// telas de leitura (Bíblia, Devocional, Introdução).
class AreaDeSelecaoComCompartilhar extends StatefulWidget {
  const AreaDeSelecaoComCompartilhar({super.key, required this.child});

  final Widget child;

  @override
  State<AreaDeSelecaoComCompartilhar> createState() =>
      _AreaDeSelecaoComCompartilharState();
}

class _AreaDeSelecaoComCompartilharState
    extends State<AreaDeSelecaoComCompartilhar> {
  // SelectableRegionState não expõe o texto selecionado publicamente; captura
  // aqui pelo onSelectionChanged, e o menu lê o valor mais recente ao montar.
  String? _selecionado;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (conteudo) => _selecionado = conteudo?.plainText,
      contextMenuBuilder: (context, estado) {
        final botoes = List.of(estado.contextMenuButtonItems);
        final selecionado = _selecionado;
        if (selecionado != null && selecionado.isNotEmpty) {
          botoes.add(
            ContextMenuButtonItem(
              label: 'Compartilhar',
              onPressed: () {
                estado.hideToolbar();
                SharePlus.instance.share(ShareParams(text: selecionado));
              },
            ),
          );
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: estado.contextMenuAnchors,
          buttonItems: botoes,
        );
      },
      child: widget.child,
    );
  }
}

/// Divulgação de que o chat responde por inteligência artificial. O mesmo
/// texto em todo lugar em que uma IA fala: rodapé do chat, boas-vindas e
/// histórico vazio — repetir é o que o torna um aviso, não um enfeite.
const avisoDeIa = 'Respostas geradas por inteligência artificial';

/// Quanto tempo um aviso de snackbar fica na tela antes de fechar sozinho. Um
/// valor só em todo o projeto: se a duração mudar um dia, muda aqui.
const duracaoDeAviso = Duration(seconds: 3);

/// Mostra um aviso na snackbar e o fecha sozinho depois de [duracaoDeAviso].
///
/// O ScaffoldMessenger tem um timer próprio para isso, mas ele nunca nasce
/// quando o SnackBar tem ação (bug do Flutter 3.44.9, reproduzido em teste):
/// um "Desfazer" ou um "Tentar de novo" deixava o aviso na tela para sempre.
/// Então o fechamento sai daqui, e o `closed` do aviso garante que um fechar
/// tardio não leva junto um aviso mais novo mostrado no meio do caminho.
///
/// Quem mostra um aviso sempre passa por aqui: assim a duração é uma só, a de
/// [duracaoDeAviso], e o comportamento é o mesmo em toda parte.
void mostrarAviso(
  BuildContext context,
  String texto, {
  String? rotuloDeAcao,
  VoidCallback? aoAgir,
}) => mostrarAvisoNo(
  ScaffoldMessenger.of(context),
  texto,
  rotuloDeAcao: rotuloDeAcao,
  aoAgir: aoAgir,
);

/// O mesmo que [mostrarAviso], mas com o messenger já em mãos — o caso das
/// telas que capturam o messenger antes de um `await` e só mostram o aviso
/// depois, quando o contexto pode não estar mais montado.
void mostrarAvisoNo(
  ScaffoldMessengerState mensageiro,
  String texto, {
  String? rotuloDeAcao,
  VoidCallback? aoAgir,
}) {
  mensageiro.hideCurrentSnackBar();
  final aviso = mensageiro.showSnackBar(
    SnackBar(
      content: Text(texto),
      duration: duracaoDeAviso,
      action: rotuloDeAcao == null
          ? null
          : SnackBarAction(
              label: rotuloDeAcao,
              onPressed: () {
                aoAgir?.call();
                mensageiro.hideCurrentSnackBar();
              },
            ),
    ),
  );
  var fechou = false;
  aviso.closed.whenComplete(() => fechou = true);
  Future<void>.delayed(duracaoDeAviso, () {
    if (!fechou) {
      mensageiro.hideCurrentSnackBar();
    }
  });
}

/// As linhas do cartão "Como usar" da Hoje. A mesma ajuda reaparece em Sobre,
/// porque quem dispensou o cartão na primeira visita não tem como vê-lo de
/// novo — e o caminho para a ajuda não pode depender só do primeiro dia.
const linhasDeAjuda = [
  'Na Bíblia, deslize o dedo para virar o capítulo; com mouse e teclado, '
      'use as setas.',
  'O Devocional traz Manhã, Promessas e Noite, e vira sozinho com o horário.',
  '"Ler tudo" abre a leitura do dia inteira.',
  'Na aba Conversas, o chat com Spurgeon e com Felipe: pergunte sobre a '
      'Palavra, peça uma aplicação, desabafe.',
  'O retrato de Spurgeon no começo do capítulo e da introdução lê o texto '
      'na voz dele: toque para ouvir, e toque de novo para encerrar.',
  'No computador, a tecla P também começa e encerra a leitura, e a barra de '
      'cima ganha um botão de parar enquanto ela toca.',
  'No Plano, marque o dia quando terminar a leitura.',
];

/// Capa da Bíblia de Estudo Charles Haddon Spurgeon, trocada conforme o tema claro/escuro.
String capaBibliaSpurgeon(BuildContext context) {
  final escuro = Theme.of(context).brightness == Brightness.dark;
  return escuro
      ? 'assets/images/capa_biblia_spurgeon_dark.webp'
      : 'assets/images/capa_biblia_spurgeon_light.webp';
}

/// A mesma altura em pixels lógicos ocupa bem menos da tela num monitor
/// (janela de navegador) do que num celular, então a capa parece pequena mesmo já
/// aumentada. Escala para cima quando a largura disponível passa de 600px.
double alturaCapa(BuildContext context, double base) {
  final largura = MediaQuery.sizeOf(context).width;
  return largura >= 720 ? base * 1.4 : base;
}

/// Cartão com título em Cinzel na cor do tema. Repete em quase toda tela.
class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    this.titulo,
    this.acessorio,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.sp16),
  });

  final String? titulo;
  final Widget? acessorio;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ?acessorio,
                ],
              ),
              const SizedBox(height: Spacing.sp12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// FutureBuilder que cria o future uma vez e só o refaz quando [chave] muda.
///
/// Escrever `FutureBuilder(future: Conteudo.instancia.algo(...))` dentro do `build`
/// entrega um future novo a cada redesenho, porque função `async` devolve outro
/// objeto Future a cada chamada, ainda que os dados já estejam em memória. O
/// FutureBuilder compara por identidade, vê um future diferente e volta ao estado de
/// carregando. Como toda tela lê o Estado, e o Estado notifica a árvore inteira,
/// favoritar um versículo redesenhava a tela da Bíblia e o capítulo inteiro virava
/// um spinner por um frame. Aqui o future nasce no initState e sobrevive aos
/// redesenhos.
///
/// [chave] é o que identifica o pedido: mudou a chave, mudou o pedido, e só então o
/// future é refeito. É a mesma ideia dos ValueKey que já marcavam esses
/// FutureBuilder, agora decidindo o que importa em vez de só trocar o State.
///
/// Não memoizar dentro do [Conteudo]: guardar o Future amarra ele à zona de quem
/// chamou primeiro, e um future criado no `tester.runAsync` nunca entrega o valor
/// para quem se inscreve pela zona de tempo falso do teste.
class CarregaUmaVez<T> extends StatefulWidget {
  const CarregaUmaVez({
    super.key,
    required this.chave,
    required this.carregar,
    required this.construir,
  });

  final String chave;
  final Future<T> Function() carregar;
  final AsyncWidgetBuilder<T> construir;

  @override
  State<CarregaUmaVez<T>> createState() => _CarregaUmaVezState<T>();
}

class _CarregaUmaVezState<T> extends State<CarregaUmaVez<T>> {
  late Future<T> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = widget.carregar();
  }

  @override
  void didUpdateWidget(CarregaUmaVez<T> anterior) {
    super.didUpdateWidget(anterior);
    if (widget.chave != anterior.chave) _futuro = widget.carregar();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<T>(future: _futuro, builder: widget.construir);
}

/// Filete do metal do tema, usado para separar seções sem o peso de um Divider
/// comum. Dourado no escuro, bronze no claro.
class Filete extends StatelessWidget {
  const Filete({super.key, this.largura = 48});

  final double largura;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Container(
      width: largura,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cor.primary, cor.outline]),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// Estado de "ainda não há texto para isto", em vez de uma tela em branco.
class AvisoVazio extends StatelessWidget {
  const AvisoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.detalhe,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String? detalhe;

  /// A próxima ação do estado vazio, quando existe: "Tentar de novo" num
  /// erro, "Exportar" numa lista vazia que tem saída.
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 44, color: cor.outline),
            const SizedBox(height: Spacing.sp16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (detalhe != null) ...[
              const SizedBox(height: Spacing.sp8),
              Text(
                detalhe!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (acao != null) ...[const SizedBox(height: Spacing.sp12), acao!],
          ],
        ),
      ),
    );
  }
}

/// Falha ao ler um asset.
///
/// Existe porque nenhuma tela olhava `snapshot.hasError`: um JSON corrompido ou
/// ausente deixava o CircularProgressIndicator girando para sempre, sem saída e
/// sem dizer o que houve. Girar é promessa de que algo vai chegar; quando não
/// vai, a tela precisa dizer isso.
class AvisoDeErro extends StatelessWidget {
  const AvisoDeErro({super.key, this.detalhe});

  final String? detalhe;

  @override
  Widget build(BuildContext context) => AvisoVazio(
    icone: Icons.error_outline,
    titulo: 'Não foi possível carregar',
    detalhe:
        detalhe ??
        'Feche e abra o aplicativo. Se continuar, pode faltar um arquivo de conteúdo.',
  );
}

/// Editor de nota de um versículo. Devolve o texto salvo, ou nulo se cancelado.
Future<String?> editarNota(
  BuildContext context, {
  required String referencia,
  required String notaAtual,
}) {
  final controle = TextEditingController(text: notaAtual);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(referencia, style: Theme.of(context).textTheme.headlineSmall),
      content: TextField(
        controller: controle,
        autofocus: true,
        maxLines: 6,
        minLines: 3,
        decoration: const InputDecoration(hintText: 'Sua anotação'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controle.text),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

/// Confirmação antes de remover uma marcação. Devolve true só se o usuário confirmar.
Future<bool> confirmarRemocao(
  BuildContext context, {
  required String referencia,
  required bool comNota,
}) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remover dos favoritos?'),
      content: Text(
        comNota
            ? '$referencia e a anotação serão removidos. Essa ação não pode ser desfeita.'
            : '$referencia será removido dos favoritos. Essa ação não pode ser desfeita.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remover'),
        ),
      ],
    ),
  );
  return confirmou ?? false;
}

/// Marca ou desmarca o dia como lido e oferece voltar no mesmo gesto.
///
/// O alternador é um toque só, e um toque errado num dia lido custaria o
/// registro sem aviso: o "Desfazer" devolve o estado anterior. É o mesmo
/// padrão do deslize de capítulo (`biblia.dart`): a ação tem sempre uma
/// saída de um toque. Usado pelo "Leitura de hoje" (`hoje.dart`).
void alternarLidoComDesfazer(
  BuildContext context,
  Estado estado,
  String chave,
) {
  final estavaLido = estado.foiLido(chave);
  estado.alternarLido(chave);
  // Confirmação de um toque só, não um erro: aparece e some sozinho, sem
  // depender do "Desfazer" para fechar.
  mostrarAviso(
    context,
    estavaLido ? 'Dia desmarcado.' : 'Dia marcado como lido.',
    rotuloDeAcao: 'Desfazer',
    aoAgir: () => estado.alternarLido(chave),
  );
}

/// Abre os ajustes de leitura. Usado onde não há AppBar para pendurar a ação,
/// que hoje é só a tela Hoje.
class BotaoDeAjustes extends StatelessWidget {
  const BotaoDeAjustes({super.key, required this.estado});

  final Estado estado;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Tamanho do texto e aparência',
    icon: Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
    onPressed: () => ajustesDeLeitura(context, estado),
  );
}

/// Ajustes de leitura: tamanho do texto e claro ou escuro, a dica dos botões
/// de conversa, lembretes — e Sobre, que deixou de ser aba e voltou
/// para a folha quando a URL das conversas passou a ser refletida no
/// navegador (ver `main.dart`, `optionURLReflectsImperativeAPIs`).
///
/// A conta saiu daqui: o botão de entrar mora no cabeçalho da Hoje
/// (`hoje.dart`, `_BotaoDeConta`), onde a mudança de estado se vê na
/// saudação ao lado.
///
/// Fica numa folha acionada pela AppBar do leitor, e não numa tela de Ajustes,
/// porque é onde o efeito se vê: muda o passo e o versículo atrás muda junto,
/// muda o tema e a página inteira vira embaixo da folha. Uma tela separada
/// obrigaria a sair da leitura para escolher e voltar para conferir.
Future<void> ajustesDeLeitura(BuildContext context, Estado estado) {
  return showModalBottomSheet<void>(
    context: context,
    // Sem isScrollControlled a folha fica limitada a ~9/16 da tela: com ele, o
    // conteúdo (Tamanho, Aparência, Conversas, Lembretes, Conta e Sobre) crescia
    // até quase a tela inteira no celular. O SingleChildScrollView rola o que
    // não couber em vez de estourar o layout.
    builder: (folha) => SafeArea(
      child: ListenableBuilder(
        listenable: estado,
        builder: (context, _) {
          final tema = Theme.of(context).textTheme;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sp20,
                    Spacing.sp8,
                    Spacing.sp20,
                    Spacing.sp12,
                  ),
                  child: Text('Tamanho do texto', style: tema.headlineSmall),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sp20),
                  child: Wrap(
                    spacing: Spacing.sp8,
                    runSpacing: Spacing.sp8,
                    children: [
                      for (final (i, escala) in escalasDeLeitura.indexed)
                        ChoiceChip(
                          label: Text(rotulosDeEscala[i]),
                          selected: escala == estado.escalaDeLeitura,
                          showCheckmark: false,
                          onSelected: (_) =>
                              estado.definirEscalaDeLeitura(escala),
                        ),
                    ],
                  ),
                ),
                // O efeito da escolha se vê antes de fechar a folha: o corpo
                // de leitura escala com o tema, e a linha abaixo é a amostra.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sp20,
                    Spacing.sp12,
                    Spacing.sp20,
                    Spacing.sp4,
                  ),
                  child: Text(
                    'O texto de leitura fica deste tamanho.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sp20,
                    Spacing.sp24,
                    Spacing.sp20,
                    Spacing.sp12,
                  ),
                  child: Text('Aparência', style: tema.headlineSmall),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sp20),
                  child: Wrap(
                    spacing: Spacing.sp8,
                    runSpacing: Spacing.sp8,
                    children: [
                      for (final modo in ModoDoTema.values)
                        ChoiceChip(
                          label: Text(modo.rotulo),
                          selected: modo == estado.modoDoTema,
                          showCheckmark: false,
                          onSelected: (_) => estado.definirModoDoTema(modo),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sp20,
                    Spacing.sp24,
                    Spacing.sp20,
                    Spacing.sp4,
                  ),
                  child: Text('Conversas', style: tema.headlineSmall),
                ),
                ListTile(
                  leading: Icon(
                    Icons.tips_and_updates_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Reexibir dica dos botões de conversa'),
                  subtitle: const Text(
                    'Mostra novamente a dica "Toque em Spurgeon para conversar sobre o capítulo".',
                  ),
                  onTap: () async {
                    await estado.reexibirDicaDosBaloes();
                    if (!context.mounted) return;
                    mostrarAviso(
                      context,
                      'Dica dos botões de conversa reexibida.',
                    );
                  },
                ),
                // Só em Android: é a única plataforma do projeto com um agendador
                // de sistema que o plugin de fato controla. Ver lembretes.dart.
                if (lembretesSuportados)
                  ..._SecaoDeLembretes(estado: estado).montar(context),
                // Sobre no fim da folha: as escolhas do dia ficam na frente,
                // e fontes, canais e privacidade esperam quem rola até o fim.
                ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Sobre'),
                  subtitle: const Text('Fontes do texto, canais e privacidade'),
                  onTap: () {
                    // Sai da folha antes do push: uma rota sobre a folha
                    // deixaria a folha embaixo da tela de Sobre no Android.
                    final roteador = GoRouter.of(folha);
                    Navigator.pop(folha);
                    roteador.push('/sobre');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.help_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Perguntas frequentes'),
                  onTap: () {
                    final roteador = GoRouter.of(folha);
                    Navigator.pop(folha);
                    roteador.push('/faq');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Política de privacidade'),
                  onTap: () {
                    final roteador = GoRouter.of(folha);
                    Navigator.pop(folha);
                    roteador.push('/privacidade');
                  },
                ),
                const SizedBox(height: Spacing.sp8),
              ],
            ),
          );
        },
      ),
    ),
  );
}

TimeOfDay _horaDe(int minutos) =>
    TimeOfDay(hour: minutos ~/ 60, minute: minutos % 60);

/// O retrato de uma persona num anel do metal, para as entradas de conversa:
/// a carta da aba Conversas (`telas/conversas.dart`) e o topo do histórico.
/// A mesma gramática do [BalaoDeChat] de `chat.dart`, sem a placa de nome nem
/// a dica, que o nome da carta já nomeia.
class RetratoDePersona extends StatelessWidget {
  const RetratoDePersona({super.key, required this.persona, this.tamanho = 38});

  final Persona persona;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cor.primary, width: 1.5),
      ),
      padding: const EdgeInsets.all(Spacing.sp2),
      child: ClipOval(
        child: Image.asset(
          persona.foto,
          width: tamanho,
          height: tamanho,
          fit: BoxFit.cover,
          // A foto é mais alta que larga e o cabelo encosta na borda
          // superior; o corte alinhado ao topo preserva o cabelo.
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) => Container(
            color: cor.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Text(
              persona.nomeCurto.characters.first,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: cor.primary,
                fontSize: tamanho * 0.42,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Liga ou desliga os três lembretes diários. Pede permissão antes de ligar;
/// devolve false sem mudar nada se ela for negada.
///
/// Pública, e não escondida na folha de ajustes: é a mesma regra que
/// `test/lembretes_test.dart` verifica com uma `Lembretes` falsa, sem precisar
/// desmontar a UI para chegar nela.
Future<bool> alternarLembretes(Estado estado, bool ligar) async {
  if (!ligar) {
    await estado.definirLembretesAtivos(false);
    await Lembretes.instancia.cancelar();
    return true;
  }
  final concedida = await Lembretes.instancia.pedirPermissao();
  if (!concedida) return false;
  await estado.definirLembretesAtivos(true);
  await Lembretes.instancia.agendar(
    manhaEPromessas: _horaDe(estado.minutosLembreteManha),
    noite: _horaDe(estado.minutosLembreteNoite),
  );
  return true;
}

/// Grava o novo horário e reagenda de verdade — só se os lembretes estiverem
/// ligados. O guard fica aqui, e não em quem chama: a folha de ajustes só
/// mostra os campos de hora com o interruptor já ligado, mas essa função não
/// deveria depender de a UI garantir isso por fora.
Future<void> aplicarHorarioDeLembrete(
  Estado estado, {
  int? minutosManha,
  int? minutosNoite,
}) async {
  await estado.definirHorariosDeLembrete(
    minutosManha: minutosManha ?? estado.minutosLembreteManha,
    minutosNoite: minutosNoite ?? estado.minutosLembreteNoite,
  );
  if (!estado.lembretesAtivos) return;
  await Lembretes.instancia.agendar(
    manhaEPromessas: _horaDe(estado.minutosLembreteManha),
    noite: _horaDe(estado.minutosLembreteNoite),
  );
}

/// Reagenda os lembretes no início do app, só se não houver nenhum agendado.
///
/// Cobre o reboot do aparelho, que apaga os alarmes do sistema — mas só
/// nesse caso. Chamar isto incondicionalmente a cada abertura do app faria
/// `agendar` cancelar um lembrete do dia que ainda não disparou (a entrega é
/// inexata, pode levar a janela toda) sempre que o app abrisse entre o
/// horário marcado e a entrega de verdade — bem o que acontece ao abrir o
/// app de manhã para ver se a notificação chegou.
Future<void> reagendarLembretesSeNecessario(Estado estado) async {
  if (!estado.lembretesAtivos) return;
  if (await Lembretes.instancia.agendados()) return;
  await Lembretes.instancia.agendar(
    manhaEPromessas: _horaDe(estado.minutosLembreteManha),
    noite: _horaDe(estado.minutosLembreteNoite),
  );
}

/// Confirma e exclui um plano — o compartilhado some da nuvem para todos
/// antes do espelho local sumir, o local só sai do espelho. Devolve se
/// excluiu de fato, para quem chama (a tela do plano) saber se ainda pode
/// sair dela.
///
/// Público porque a lixeira do cartão de "Meus Planos" (`plano.dart`) e o
/// menu de opções dentro do plano (`meu_plano.dart`) levam à mesma exclusão.
Future<bool> excluirPlano(
  BuildContext context,
  Estado estado,
  String planoId, {
  required bool compartilhado,
}) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Excluir plano?'),
      content: Text(
        compartilhado
            ? 'O plano será apagado para todos os participantes, junto com o '
                  'progresso de cada um. Essa ação não pode ser desfeita.'
            : 'O plano e o progresso dele serão apagados. Essa ação não pode '
                  'ser desfeita.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (confirmou != true) return false;
  if (compartilhado) {
    try {
      await PlanosNaNuvem.instancia.excluir(planoId);
    } on PlanosNaNuvemException catch (erro) {
      if (context.mounted) mostrarAviso(context, erro.mensagem);
      return false;
    }
  }
  await estado.removerPlano(planoId);
  return true;
}

/// Confirma e sai de um plano compartilhado: apaga só a própria participação
/// na nuvem, e o plano some do espelho local — mas continua existindo para
/// quem ficou. É o que a lixeira faz por quem não é o criador, que não tem o
/// poder de [excluirPlano] para todos.
Future<bool> sairDoPlano(
  BuildContext context,
  Estado estado,
  String planoId,
) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sair do plano?'),
      content: const Text(
        'Seu progresso deixa de aparecer para os outros; o plano continua '
        'para quem permaneceu.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  if (confirmou != true) return false;
  try {
    await PlanosNaNuvem.instancia.sair(planoId);
  } on PlanosNaNuvemException catch (erro) {
    if (context.mounted) mostrarAviso(context, erro.mensagem);
    return false;
  }
  await estado.removerPlano(planoId);
  return true;
}

/// Tenta o login e mostra o motivo quando não completa. Público porque dois
/// botões chamam isto: o do cabeçalho da Hoje (`hoje.dart`, `_BotaoDeConta`)
/// e o cartão de plano compartilhado (`meu_plano.dart`). Quem chama precisa
/// fazê-lo direto do `onTap`/`onPressed` (sem `await` antes): o navegador só
/// deixa abrir a janela do login dentro do gesto do usuário, e qualquer
/// espera antes do `signInWithPopup` consome esse gesto e a janela sai
/// bloqueada.
Future<void> entrarNaConta(BuildContext context, Nuvem nuvem) async {
  try {
    await nuvem.entrar();
  } on FirebaseAuthException catch (erro) {
    if (!context.mounted) return;
    mostrarAviso(
      context,
      erro.code == 'popup-closed-by-user'
          ? 'Login cancelado.'
          : 'Não foi possível entrar. Verifique se o navegador permite '
                'janelas deste site.',
    );
  } catch (_) {
    // Qualquer outra falha (Firebase sem inicializar, sem rede, App Check
    // recusando o token) não pode deixar o botão "Entrar" sem reação
    // nenhuma: melhor um aviso genérico do que o toque parecer ignorado.
    if (!context.mounted) return;
    mostrarAviso(context, 'Não foi possível entrar. Tente novamente.');
  }
}

/// A seção "Lembretes" da folha de ajustes: um interruptor para os três
/// lembretes diários, e um horário para Manhã+Promessas e outro para Noite.
///
/// Classe e não função solta, porque as ações precisam do `BuildContext` da
/// folha para `showTimePicker`/`SnackBar`, e `montar` devolve a lista de
/// widgets para entrar direto no `Column` de `ajustesDeLeitura` — não é uma
/// tela nem um widget próprio, só organização.
class _SecaoDeLembretes {
  const _SecaoDeLembretes({required this.estado});

  final Estado estado;

  List<Widget> montar(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sp20,
          Spacing.sp24,
          Spacing.sp20,
          Spacing.sp4,
        ),
        child: Text('Lembretes', style: tema.headlineSmall),
      ),
      SwitchListTile(
        title: const Text('Avisar no horário do devocional'),
        subtitle: const Text(
          'Manhã e Promessas de Deus num horário, Noite noutro.',
        ),
        value: estado.lembretesAtivos,
        onChanged: (novo) => _alternar(context, novo),
      ),
      if (estado.lembretesAtivos) ...[
        _linhaDeHorario(
          context,
          titulo: 'Manhã e Promessas',
          minutos: estado.minutosLembreteManha,
          aoEscolher: (minutos) =>
              aplicarHorarioDeLembrete(estado, minutosManha: minutos),
        ),
        _linhaDeHorario(
          context,
          titulo: 'Noite',
          minutos: estado.minutosLembreteNoite,
          aoEscolher: (minutos) =>
              aplicarHorarioDeLembrete(estado, minutosNoite: minutos),
        ),
      ],
    ];
  }

  Widget _linhaDeHorario(
    BuildContext context, {
    required String titulo,
    required int minutos,
    required ValueChanged<int> aoEscolher,
  }) {
    final hora = _horaDe(minutos);
    return ListTile(
      title: Text(titulo),
      trailing: TextButton(
        onPressed: () async {
          final escolhida = await showTimePicker(
            context: context,
            initialTime: hora,
            helpText: 'Horário de $titulo',
          );
          if (escolhida != null) {
            aoEscolher(escolhida.hour * 60 + escolhida.minute);
          }
        },
        child: Text(MaterialLocalizations.of(context).formatTimeOfDay(hora)),
      ),
    );
  }

  Future<void> _alternar(BuildContext context, bool novo) async {
    final concedida = await alternarLembretes(estado, novo);
    if (!concedida && context.mounted) {
      mostrarAviso(
        context,
        'Permissão de notificação negada. Ative em Configurações do '
        'aparelho para usar os lembretes.',
      );
    }
  }
}

/// Uma linha por versículo-base de um devocional: a citação entre aspas seguida
/// da referência em caixa alta.
///
/// A maioria dos dias tem um só versículo-base. O raro dia cuja epígrafe
/// encadeia mais de um, como o de 12 de julho (Judas 1:1, 1 Coríntios 1:2, 1
/// Pedro 1:2), mostra uma linha para cada, na mesma ordem em que aparecem no
/// devocional original.
List<InlineSpan> spansDeCitacao(
  Devocional dev, {
  required TextStyle? estiloCitacao,
  required TextStyle? estiloReferencia,
}) {
  final pares = [(dev.referencia, dev.versiculo), ...dev.outrosVersiculos];
  final spans = <InlineSpan>[];
  for (final (referencia, versiculo) in pares) {
    if (referencia.isEmpty && versiculo.isEmpty) continue;
    if (spans.isNotEmpty) spans.add(const TextSpan(text: '\n'));
    if (versiculo.isNotEmpty) {
      spans.add(TextSpan(text: '"$versiculo" ', style: estiloCitacao));
    }
    if (referencia.isNotEmpty) {
      spans.add(
        TextSpan(text: referencia.toUpperCase(), style: estiloReferencia),
      );
    }
  }
  return spans;
}

/// Abertura de um livro: a introdução de Spurgeon, recolhida por padrão.
///
/// Recolhida porque o texto é longo e quem já leu a introdução quer chegar ao
/// texto sem rolar páginas. Expandida, lê inteira ali mesmo. Aparece tanto no
/// leitor da Bíblia quanto no devocional, por isso vive aqui e não numa tela só.
class AberturaDeLivro extends StatefulWidget {
  const AberturaDeLivro({super.key, required this.slug});

  final String slug;

  @override
  State<AberturaDeLivro> createState() => _AberturaDeLivroState();
}

class _AberturaDeLivroState extends State<AberturaDeLivro> {
  bool _aberta = false;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;

    return CarregaUmaVez<Introducao?>(
      chave: widget.slug,
      carregar: () => Conteudo.instancia.introducao(widget.slug),
      construir: (context, snap) {
        final introducao = snap.data;
        // Sem introdução escrita, nada é mostrado: o texto começa direto.
        if (introducao == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sp24),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _aberta = !_aberta),
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.sp16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.asset(
                            capaBibliaSpurgeon(context),
                            height: alturaCapa(context, 104),
                            fit: BoxFit.cover,
                            // Decorativa: o título ao lado já nomeia a obra.
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(width: Spacing.sp14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Introdução: ${livroPorSlug(widget.slug)!.tituloFormal}',
                                style: tema.titleLarge,
                              ),
                              const SizedBox(height: Spacing.sp4),
                              Text(
                                'Bíblia de Estudo Charles Haddon Spurgeon',
                                style: tema.labelMedium,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _aberta ? Icons.expand_less : Icons.expand_more,
                          color: cor.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_aberta)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.sp16,
                      0,
                      Spacing.sp16,
                      Spacing.sp16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Filete(),
                        const SizedBox(height: Spacing.sp16),
                        // A voz de Spurgeon lê a introdução inteira, do
                        // título à frase; tocar de novo para a leitura.
                        BotaoDeVoz(
                          chave: 'introducao:${widget.slug}',
                          texto: textoDeIntroducao(introducao),
                          tipo: TipoConteudoAudio.introducao,
                          referencia: 'Introdução de ${introducao.livro}',
                        ),
                        const SizedBox(height: Spacing.sp16),
                        for (final (titulo, corpo) in introducao.secoes) ...[
                          Text(titulo, style: tema.headlineSmall),
                          const SizedBox(height: Spacing.sp8),
                          for (final paragrafo in corpo.split('\n\n')) ...[
                            Text(
                              paragrafo,
                              style: tema.bodyMedium?.copyWith(height: 1.7),
                            ),
                            const SizedBox(height: Spacing.sp10),
                          ],
                          const SizedBox(height: Spacing.sp12),
                        ],
                        if (introducao.frase.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(Spacing.sp14),
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
                                  '"${introducao.frase}"',
                                  style: tema.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: cor.secondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: Spacing.sp8),
                                Text(
                                  introducao.atribuicao,
                                  style: tema.labelMedium,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Botão de ouvir na voz de Spurgeon: o retrato dele no chat, num comprimido
/// que toca [texto] e, enquanto toca, mostra a leitura acontecendo.
///
/// [chave] identifica o que se ouve ("introducao:joao", "capitulo:joao.3"): a
/// voz é de app inteiro, então o botão da introdução e o do capítulo mostram
/// o mesmo estado para o mesmo áudio, e ouvir um para o outro. [tipo] decide
/// a voz e o ritmo da síntese ([TipoConteudoAudio]): quem sabe o que se está
/// ouvindo é quem monta o botão. [referencia] nomeia o que terminou no aviso
/// ("João 3"), para o fim da leitura não ser um "Leitura concluída." genérico.
///
/// O botão escuta o fim da própria leitura para fechar o ciclo com a
/// confirmação "Leitura concluída.": parar no meio não é um fim, e não avisa.
class BotaoDeVoz extends StatefulWidget {
  const BotaoDeVoz({
    super.key,
    required this.chave,
    required this.texto,
    required this.tipo,
    this.referencia,
  });

  final String chave;
  final String texto;
  final TipoConteudoAudio tipo;
  final String? referencia;

  @override
  State<BotaoDeVoz> createState() => _BotaoDeVozState();
}

class _BotaoDeVozState extends State<BotaoDeVoz> {
  StreamSubscription<String>? _conclusoes;

  @override
  void initState() {
    super.initState();
    _conclusoes = Voz.instancia.conclusoes.listen((chave) {
      if (chave != widget.chave || !mounted) return;
      final referencia = widget.referencia;
      mostrarAviso(
        context,
        referencia == null
            ? 'Leitura concluída.'
            : 'Leitura concluída: $referencia.',
      );
    });
  }

  @override
  void dispose() {
    _conclusoes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Recursos.ouvirTextos) return const SizedBox.shrink();
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Voz.instancia,
      builder: (context, _) {
        final voz = Voz.instancia;
        // O carregando fica ligado a leitura inteira (só se desliga no fim do
        // play): o preparo é "carregando sem tocar" — sem o !tocando, o
        // tooltip diria "Cancelar o preparo" com o áudio tocando.
        final preparando =
            voz.carregando && !voz.tocando && voz.tocandoChave == widget.chave;
        final ativo = voz.tocando && voz.tocandoChave == widget.chave;
        final pausado = voz.pausado && voz.tocandoChave == widget.chave;
        // A leitura fala como o pregador, não como painel de controle: quem
        // está lendo é uma pessoa, e o aviso completo vai no Semantics (o
        // rótulo visível é curto para caber na pílula em escala 2x).
        final rotulo = ativo
            ? 'O pregador está lendo. Toque para encerrar a leitura.'
            : pausado
            ? 'A leitura foi pausada. Toque para retomar.'
            : preparando
            ? 'Preparando a voz de Spurgeon. Toque para cancelar.'
            : 'Ouvir na voz de Spurgeon';
        final visivel = ativo
            ? 'O pregador está lendo…'
            : pausado
            ? 'Pausado. Toque para retomar.'
            : preparando
            ? 'Preparando a voz…'
            : 'Ouvir';
        return Tooltip(
          message: preparando
              ? 'Cancelar o preparo'
              : ativo
              ? 'Encerrar a leitura'
              : pausado
              ? 'Retomar a leitura'
              : 'Ouvir na voz de Spurgeon',
          child: Semantics(
            button: true,
            label: rotulo,
            child: Material(
              color: cor.surfaceContainerHighest,
              // Ativo, o comprimido usa o anel do metal em vez do metal cheio:
              // a pílula do metal cheio sobre o dourado da página empilhava
              // dourado sobre dourado, e o anel reserva o fill para o chip
              // escolhido, que é o alternador de leitura e de mês.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                // O anel acompanha a sessão viva: tocando ou pausada, a pílula
                // ainda pertence ao metal do tema.
                side: ativo || pausado
                    ? BorderSide(color: cor.primary, width: 1.5)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(30),
                    // Durante o preparo o botão continua vivo: o toque cancela
                    // em vez de prender quem tocou o capítulo errado num
                    // relógio de até 90 segundos. Pausada, a pílula é o
                    // próprio retomar: o toque volta à leitura de onde parou.
                    onTap: preparando
                        ? voz.parar
                        : () => _alternar(context, voz),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.sp6,
                        Spacing.sp6,
                        Spacing.sp16,
                        Spacing.sp6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // O retrato é o convite: quem já ouve (ou está
                          // pausado no meio) não precisa do rosto de novo ao
                          // lado do rótulo — a leitura em andamento é ação,
                          // não apresentação, e um sinal a menos deixa o
                          // estado falar mais alto.
                          if (!preparando && !ativo && !pausado) ...[
                            // O mesmo retrato do chat: aro dourado, e o cabelo,
                            // que encosta na borda de cima da foto, preservado
                            // pelo corte alinhado ao topo (ver BalaoDeChat).
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cor.primary,
                                  width: 1.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(Spacing.sp3),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/spurgeon.webp',
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                    // Decorativa: o rótulo ao lado já diz o que
                                    // o botão faz.
                                    excludeFromSemantics: true,
                                    alignment: Alignment.topCenter,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: Spacing.sp10),
                          ],
                          Icon(
                            ativo
                                ? Icons.stop_rounded
                                : preparando
                                ? Icons.hourglass_top_rounded
                                : Icons.play_arrow_rounded,
                            size: 20,
                            color: cor.primary,
                          ),
                          const SizedBox(width: Spacing.sp6),
                          // Flexible com reticências: em escala de texto 2x um
                          // rótulo comprido ("O pregador está lendo…") não
                          // pode estourar a largura da tela. Semantics: o
                          // rótulo completo já vive no Semantics acima, e o
                          // texto visível repetido faria o leitor de tela ler
                          // a frase duas vezes.
                          Flexible(
                            child: ExcludeSemantics(
                              child: Text(
                                visivel,
                                overflow: TextOverflow.ellipsis,
                                style: tema.labelLarge?.copyWith(
                                  color: ativo || pausado
                                      ? cor.primary
                                      : cor.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          // Uma sessão pausada precisa de um jeito de ser
                          // encerrada sem trocar de página: sem o X, o sócio
                          // pausado vira um invisital — e pausa que não se pode
                          // fechar é uma gaiola. O X mata a sessão; o corpo da
                          // pílula continua retomando.
                          if (pausado)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 6,
                              ),
                              child: Tooltip(
                                message: 'Encerrar a leitura pausada',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(30),
                                  onTap: voz.parar,
                                  child: Padding(
                                    padding: const EdgeInsets.all(Spacing.sp4),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: cor.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // A linha fina de progresso, na borda de baixo da pílula:
                  // quem ouve um capítulo de vinte minutos sabe quanto falta.
                  // Pausada, ela mostra onde a leitura parou. Durante o
                  // preparo ela é indeterminada (o valor é nulo até a duração
                  // chegar): até 90 segundos de espera não podem parecer um
                  // botão morto, e sem a duração não há o que preencher.
                  if (preparando || ativo || pausado)
                    ExcludeSemantics(child: _ProgressoDeLeitura(voz: voz)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _alternar(BuildContext context, Voz voz) async {
    try {
      await voz.alternar(widget.chave, texto: widget.texto, tipo: widget.tipo);
    } on VozException catch (erro) {
      if (context.mounted) _avisarErro(context, voz, erro);
    }
  }

  /// O aviso de erro com um "Tentar de novo" à mão: um erro de rede ou de
  /// serviço é momentâneo na maioria das vezes, e sem a ação o usuário teria
  /// de descobrir sozinho que tocar de novo é o caminho.
  void _avisarErro(BuildContext context, Voz voz, VozException erro) {
    mostrarAviso(
      context,
      erro.mensagem,
      rotuloDeAcao: 'Tentar de novo',
      aoAgir: () => _alternar(context, voz),
    );
  }
}

/// O indicador "há leitura no ar" na barra de cima: aparece quando a chave
/// desta tela está tocando ou se preparando, para quem rolou para longe do
/// botão ainda saber que o toque pegou e poder encerrar (ou cancelar) a
/// leitura. A mesma peça na Bíblia e na introdução: uma leitura não pode
/// ficar sem o botão de parar à vista.
class IndicadorDeVozNaBarra extends StatelessWidget {
  const IndicadorDeVozNaBarra({super.key, required this.chave});

  /// A chave de voz desta tela ("capitulo:joao.3", "introducao:joao"): só o
  /// áudio dela aparece aqui; o de outra tela não rouba a barra.
  final String chave;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Voz.instancia,
      builder: (context, _) {
        final voz = Voz.instancia;
        final aqui =
            (voz.tocando || voz.carregando || voz.pausado) &&
            voz.tocandoChave == chave;
        if (!aqui) return const SizedBox.shrink();
        // Preparando, o indicador mostra o preparo em curso: quem espera
        // ainda pode cancelar. O carregando continua ligado durante a
        // leitura (só se desliga no fim do play), por isso o preparo é
        // "carregando sem tocar".
        final preparando = voz.carregando && !voz.tocando;
        if (preparando) {
          // O anel gira enquanto o áudio não chegou — o que está parado no
          // "Cancelar" é a página, não a barra de cima: quem rolou para longe
          // ainda vê o preparo em andamento, e não um ícone congelado.
          return ExcludeSemantics(
            child: IconButton(
              tooltip: 'Cancelar o preparo',
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      value: null,
                      strokeWidth: 2,
                      color: cor.primary,
                      backgroundColor: cor.surfaceContainerHighest,
                    ),
                  ),
                  Icon(Icons.hourglass_top_rounded, size: 18),
                ],
              ),
              onPressed: voz.parar,
            ),
          );
        }
        // Pausada de fora, o anel é o retomar: quem rolou para longe da
        // pílula não pode ter de voltar ao topo para continuar a leitura, e
        // um toque que "encerrasse" aqui jogaria fora a posição da pausa.
        final retomar = voz.pausado && !voz.tocando;
        // Tocando ou pausada, o ícone ganha um anel de progresso: quem rolou
        // para longe do botão continua sabendo quanto falta (ou onde a
        // leitura parou) sem voltar ao topo.
        return ExcludeSemantics(
          child: StreamBuilder<Duration>(
            stream: voz.posicao,
            builder: (context, posicao) {
              final agora = posicao.data ?? Duration.zero;
              return StreamBuilder<Duration?>(
                stream: voz.duracao,
                builder: (context, duracao) {
                  final total = duracao.data;
                  // Sem duração conhecida o anel fica indeterminado (o
                  // CircularProgressIndicator anima sozinho).
                  final fracao = total == null || total.inMilliseconds == 0
                      ? null
                      : (agora.inMilliseconds / total.inMilliseconds).clamp(
                          0.0,
                          1.0,
                        );
                  return IconButton(
                    tooltip: retomar
                        ? 'Retomar a leitura'
                        : 'Encerrar a leitura',
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            value: fracao,
                            strokeWidth: 2,
                            color: cor.primary,
                            backgroundColor: cor.surfaceContainerHighest,
                          ),
                        ),
                        Icon(
                          retomar
                              ? Icons.play_circle_outline
                              : Icons.stop_circle_outlined,
                          size: 18,
                        ),
                      ],
                    ),
                    onPressed: retomar ? voz.retomarDaPausa : voz.parar,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// A linha fina de progresso da leitura: a posição do player sobre a duração
/// total. Só é montada enquanto toca ou prepara; sem player (testes) as
/// streams ficam vazias e nada é desenhado. Enquanto a duração não chega (o
/// preparo, o primeiro instante da leitura) o valor é nulo e a faixa vira a
/// indeterminada animada — o que se move é o que se espera.
class _ProgressoDeLeitura extends StatelessWidget {
  const _ProgressoDeLeitura({required this.voz});

  final Voz voz;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: voz.posicao,
      builder: (context, posicao) {
        final agora = posicao.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: voz.duracao,
          builder: (context, duracao) {
            final total = duracao.data;
            // Sem duração conhecida não há o que preencher: a faixa fica
            // indeterminada (o LinearProgressIndicator anima sozinho).
            final fracao = total == null || total.inMilliseconds == 0
                ? null
                : (agora.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
            return LinearProgressIndicator(
              value: fracao,
              minHeight: 3,
              color: cor.primary,
              // O trilho na cor da página se destaca do comprimido e deixa o
              // fio dourado de progresso visível em vez de sumir no próprio
              // fundo da pílula.
              backgroundColor: cor.surface,
            );
          },
        );
      },
    );
  }
}

/// Um dia de leitura: número, o que se lê e o botão de marcar como lido.
///
/// Serve o cronograma anual (com data e borda dourada no dia de hoje) e os
/// dias dos planos do usuário (uma sequência de 1 a N), porque são a mesma
/// peça de UI.
class CartaoDeDia extends StatelessWidget {
  const CartaoDeDia({
    super.key,
    required this.numero,
    required this.rotulo,
    required this.faixas,
    required this.lido,
    required this.aoAlternar,
    this.destacar = false,
  });

  final int numero;
  final String rotulo;
  final List<Faixa> faixas;
  final bool lido;

  /// Borda dourada plena, para o dia de hoje se achar de relance dentro de
  /// uma lista de trinta e um cartões parecidos.
  final bool destacar;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: destacar ? cor.primary : cor.outline.withValues(alpha: 0.35),
          width: destacar ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sp14,
          Spacing.sp12,
          Spacing.sp8,
          Spacing.sp12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$numero',
                style: tema.headlineSmall?.copyWith(
                  color: lido ? cor.secondary : cor.primary,
                ),
              ),
            ),
            const SizedBox(width: Spacing.sp8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: tema.bodyMedium?.copyWith(
                      decoration: lido ? TextDecoration.lineThrough : null,
                      color: lido ? cor.onSurfaceVariant : cor.onSurface,
                    ),
                  ),
                  const SizedBox(height: Spacing.sp10),
                  Wrap(
                    spacing: Spacing.sp8,
                    runSpacing: Spacing.sp8,
                    children: [for (final f in faixas) BotaoDeFaixa(faixa: f)],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: lido ? 'Desmarcar' : 'Marcar como lido',
              icon: Icon(
                lido ? Icons.check_circle : Icons.radio_button_unchecked,
                color: lido ? cor.secondary : cor.onSurfaceVariant,
              ),
              onPressed: aoAlternar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Limita a largura de leitura e centraliza, para a web não esticar texto
/// de ponta a ponta numa janela larga. No celular a tela já é mais estreita
/// que o limite, então nada muda.
class LarguraDeLeitura extends StatelessWidget {
  const LarguraDeLeitura({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Nomes dos meses, usados no cronograma e no calendário.
const meses = <String>[
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String dataLonga(DateTime data) {
  final base = '${data.day} de ${meses[data.month - 1].toLowerCase()}';
  // Sem ano no ano corrente ("17 de agosto"), com ano fora dele: na virada
  // do ano, "17 de agosto" de outro ano seria ambíguo por um instante.
  return data.year == DateTime.now().year ? base : '$base de ${data.year}';
}
