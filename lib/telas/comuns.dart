import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/lembretes.dart';
import '../data/modelos.dart';

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

/// Alternador entre BKJ e NVT, para a AppBar do leitor e do Devocional.
///
/// Era um SegmentedButton ocupando uma linha inteira em cada uma das duas telas,
/// e no Devocional ele vinha empilhado sob os chips das três leituras: dois
/// terços da primeira dobra do celular gastos em controle antes de qualquer
/// texto. Como são só duas versões e a escolha é persistida, um botão que mostra
/// a sigla atual e troca pela outra diz a mesma coisa em um canto da barra. O
/// tooltip nomeia o destino, que é o que um alternador de dois estados esconde.
class BotaoDeVersao extends StatelessWidget {
  const BotaoDeVersao({super.key, required this.atual, required this.ao});

  final Versao atual;
  final ValueChanged<Versao> ao;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final outra = Versao.values.firstWhere((v) => v != atual);
    return TextButton(
      onPressed: () => ao(outra),
      child: Tooltip(
        message: 'Lendo em ${atual.nome}. Trocar para ${outra.nome}.',
        child: Text(
          atual.sigla,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: cor.secondary),
        ),
      ),
    );
  }
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

/// Ajustes de leitura: tamanho do texto e claro ou escuro.
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
                // Só em Android e iOS: são as duas plataformas com um agendador
                // de sistema que o plugin de fato controla. Ver lembretes.dart.
                if (lembretesSuportados)
                  ..._SecaoDeLembretes(estado: estado).montar(context),
                const SizedBox(height: 20),
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
        final intro = snap.data;
        // Sem introdução escrita, nada é mostrado: o texto começa direto.
        if (intro == null) return const SizedBox.shrink();

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
                            'assets/images/capa_biblia_spurgeon.webp',
                            height: 52,
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
                                'Introdução — ${livroPorSlug(widget.slug)!.tituloFormal}',
                                style: tema.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bíblia de Estudo Spurgeon',
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
                        for (final (titulo, corpo) in intro.secoes) ...[
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
                        if (intro.frase.isNotEmpty)
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
                                  '"${intro.frase}"',
                                  style: tema.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: cor.secondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(intro.atribuicao, style: tema.labelMedium),
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

/// Limita a largura de leitura e centraliza, para o Windows não esticar texto
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
