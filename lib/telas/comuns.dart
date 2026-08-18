import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/lembretes.dart';
import '../data/modelos.dart';
import '../data/nuvem.dart';
import '../data/voz.dart';

/// A folga que as telas de leitura deixam no fim da lista para os balões de
/// conversa (88 de folga mais 52 de balão, em `main.dart`) não cobrirem a
/// última linha. Só entra em telas estreitas: em tela larga os balões ficam
/// fora da coluna de leitura, que é limitada por [LarguraDeLeitura].
const folgaDosBaloes = 152.0;

/// Divulgação de que o chat responde por inteligência artificial. O mesmo
/// texto em todo lugar em que uma IA fala: rodapé do chat, boas-vindas e
/// histórico vazio — repetir é o que o torna um aviso, não um enfeite.
const avisoDeIa = 'Respostas geradas por inteligência artificial';

/// As linhas do cartão "Como usar" da Hoje. A mesma ajuda reaparece em Sobre,
/// porque quem dispensou o cartão na primeira visita não tem como vê-lo de
/// novo — e o caminho para a ajuda não pode depender só do primeiro dia.
const linhasDeAjuda = [
  'Na Bíblia, desliza o dedo para virar o capítulo; com mouse e teclado, '
      'usa as setas.',
  'O Devocional traz Manhã, Promessas e Noite, e vira sozinho com o horário.',
  '"Ler tudo" abre a leitura do dia inteira.',
  'Os retratos de Spurgeon e de Felipe nas bordas da tela abrem as '
      'conversas: pergunte sobre a Palavra, peça uma aplicação, desabafe.',
  'O retrato de Spurgeon no começo do capítulo e da introdução lê o texto '
      'na voz dele: toque para ouvir, e toque de novo para encerrar.',
  'No computador, a tecla P também começa e encerra a leitura, e a barra de '
      'cima ganha um botão de parar enquanto ela toca.',
  'No Plano, marca o dia quando terminares a leitura.',
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
    this.padding = const EdgeInsets.all(16),
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
              const SizedBox(height: 12),
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
  });

  final IconData icone;
  final String titulo;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 44, color: cor.outline),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (detalhe != null) ...[
              const SizedBox(height: 8),
              Text(
                detalhe!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
      title: const Text('Remover marcação?'),
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

/// Ajustes de leitura: tamanho do texto e claro ou escuro, botões de
/// conversa, lembretes, conta — e Sobre, que deixou de ser aba e voltou para
/// a folha quando a URL das conversas passou a ser refletida no navegador
/// (ver `main.dart`, `optionURLReflectsImperativeAPIs`).
///
/// Fica numa folha acionada pela AppBar do leitor, e não numa tela de Ajustes,
/// porque é onde o efeito se vê: muda o passo e o versículo atrás muda junto,
/// muda o tema e a página inteira vira embaixo da folha. Uma tela separada
/// obrigaria a sair da leitura para escolher e voltar para conferir.
Future<void> ajustesDeLeitura(BuildContext context, Estado estado) {
  return showModalBottomSheet<void>(
    context: context,
    // Com a seção Lembretes (interruptor mais dois horários), o conteúdo passou
    // a ultrapassar a altura de telas baixas ou em paisagem. isScrollControlled
    // deixa a folha crescer até quase a tela inteira, e o SingleChildScrollView
    // rola o que não couber em vez de estourar o layout.
    isScrollControlled: true,
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text('Tamanho do texto', style: tema.headlineSmall),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text('Aparência', style: tema.headlineSmall),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                  child: Text('Conversas', style: tema.headlineSmall),
                ),
                SwitchListTile(
                  title: const Text('Mostrar botões de conversa'),
                  subtitle: const Text(
                    'Os retratos nas bordas das telas abrem as conversas com '
                    'Spurgeon e com Felipe.',
                  ),
                  value: estado.baloesVisiveis,
                  onChanged: (novo) => estado.definirBaloesVisiveis(novo),
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
                    await estado.dispensarBalcaoTooltip();
                    // Inverte para forçar reexibição (o método só define true, então
                    // precisamos resetar manualmente via SharedPreferences).
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('baloes_tooltip_dispensado', false);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dica dos botões de conversa reexibida.'),
                      ),
                    );
                  },
                ),
                // Só em Android: é a única plataforma do projeto com um agendador
                // de sistema que o plugin de fato controla. Ver lembretes.dart.
                if (lembretesSuportados)
                  ..._SecaoDeLembretes(estado: estado).montar(context),
                // Só na web: Android já guarda tudo no aparelho. Ver
                // nuvem.dart, mesma regra do lembretesSuportados acima.
                if (nuvemSuportada) ..._secaoDaConta(context),
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
                const SizedBox(height: 8),
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

/// A seção "Conta" da folha de ajustes. Duas linhas possíveis, nunca as duas:
/// convite para entrar, ou o e-mail de quem já entrou com o botão "Sair".
List<Widget> _secaoDaConta(BuildContext context) {
  final nuvem = Nuvem.instancia;
  return [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: Text('Conta', style: Theme.of(context).textTheme.headlineSmall),
    ),
    ListenableBuilder(
      listenable: nuvem,
      builder: (context, _) => nuvem.logado
          ? ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: Text(nuvem.email ?? 'Conectado'),
              subtitle: Text(
                nuvem.falhouAoEnviar
                    ? 'Não foi possível salvar na conta agora. A próxima '
                          'anotação tenta de novo.'
                    : 'Favoritos, anotações e progresso sobem sozinhos.',
              ),
              trailing: TextButton(
                onPressed: nuvem.sair,
                child: const Text('Sair'),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guarda favoritos, anotações e progresso na sua conta.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  // O "G" é o asset oficial do Google
                  // (developers.google.com/identity/images/g-logo.png), do
                  // jeito que as diretrizes de marca pedem: não redesenhado à
                  // mão. `flutter_signin_button` foi tentado antes e
                  // descartado — quebra em Flutter 3.44 porque `IconData`
                  // virou uma classe `final`, e nenhuma versão do
                  // `font_awesome_flutter` que ele usa por baixo resolve isso.
                  OutlinedButton.icon(
                    onPressed: () => entrarNaConta(context, nuvem),
                    icon: Image.asset(
                      'assets/images/google.webp',
                      width: 18,
                      height: 18,
                    ),
                    label: const Text('Entrar com Google'),
                  ),
                ],
              ),
            ),
    ),
  ];
}

/// Tenta o login e mostra o motivo quando não completa. Público porque dois
/// botões chamam isto: o da seção "Conta" aqui e o convite compacto ao lado
/// da saudação em `hoje.dart`. Quem chama precisa fazê-lo direto do `onTap`/
/// `onPressed` (sem `await` antes): o navegador só deixa abrir a janela do
/// login dentro do gesto do usuário, e qualquer espera antes do
/// `signInWithPopup` consome esse gesto e a janela sai bloqueada.
Future<void> entrarNaConta(BuildContext context, Nuvem nuvem) async {
  try {
    await nuvem.entrar();
  } on FirebaseAuthException catch (erro) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erro.code == 'popup-closed-by-user'
              ? 'Login cancelado.'
              : 'Não foi possível entrar. Verifique se o navegador permite '
                    'janelas deste site.',
        ),
      ),
    );
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permissão de notificação negada. Ative em Configurações do '
            'aparelho para usar os lembretes.',
          ),
        ),
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
          padding: const EdgeInsets.only(bottom: 24),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _aberta = !_aberta),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Introdução: ${livroPorSlug(widget.slug)!.tituloFormal}',
                                style: tema.titleLarge,
                              ),
                              const SizedBox(height: 4),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Filete(),
                        const SizedBox(height: 16),
                        // A voz de Spurgeon lê a introdução inteira, do
                        // título à frase; tocar de novo para a leitura.
                        BotaoDeVoz(
                          chave: 'introducao:${widget.slug}',
                          texto: textoDeIntroducao(introducao),
                          referencia: 'Introdução de ${introducao.livro}',
                        ),
                        const SizedBox(height: 16),
                        for (final (titulo, corpo) in introducao.secoes) ...[
                          Text(titulo, style: tema.headlineSmall),
                          const SizedBox(height: 8),
                          for (final paragrafo in corpo.split('\n\n')) ...[
                            Text(
                              paragrafo,
                              style: tema.bodyMedium?.copyWith(height: 1.7),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 12),
                        ],
                        if (introducao.frase.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
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
                                const SizedBox(height: 8),
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
/// o mesmo estado para o mesmo áudio, e ouvir um para o outro. [referencia]
/// nomeia o que terminou no aviso ("João 3"), para o fim da leitura não ser
/// um "Leitura concluída." genérico.
///
/// O botão escuta o fim da própria leitura para fechar o ciclo com a
/// confirmação "Leitura concluída.": parar no meio não é um fim, e não avisa.
class BotaoDeVoz extends StatefulWidget {
  const BotaoDeVoz({
    super.key,
    required this.chave,
    required this.texto,
    this.referencia,
  });

  final String chave;
  final String texto;
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              referencia == null
                  ? 'Leitura concluída.'
                  : 'Leitura concluída: $referencia.',
            ),
          ),
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
                      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
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
                                padding: const EdgeInsets.all(3),
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
                            const SizedBox(width: 10),
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
                          const SizedBox(width: 6),
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
                                    padding: const EdgeInsets.all(4),
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
      await voz.alternar(widget.chave, texto: widget.texto);
    } on VozException catch (erro) {
      if (context.mounted) _avisarErro(context, voz, erro);
    }
  }

  /// O aviso de erro com um "Tentar de novo" à mão: um erro de rede ou de
  /// serviço é momentâneo na maioria das vezes, e sem a ação o usuário teria
  /// de descobrir sozinho que tocar de novo é o caminho.
  void _avisarErro(BuildContext context, Voz voz, VozException erro) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(erro.mensagem),
          action: SnackBarAction(
            label: 'Tentar de novo',
            onPressed: () => _alternar(context, voz),
          ),
        ),
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

String dataLonga(DateTime data) =>
    '${data.day} de ${meses[data.month - 1].toLowerCase()}';
