import 'package:flutter/material.dart';
// ScrollCacheExtent ainda não é reexportado por material.dart nesta versão.
import 'package:flutter/rendering.dart';

import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/nuvem.dart';
import '../data/planos.dart';
import '../data/recursos.dart';
import '../spacing.dart';
import 'comuns.dart';
import 'meu_plano.dart';
import 'novo_plano.dart';

/// Cronograma anual agrupado por mês, com marcação de lido — e, na aba Meus
/// Planos, os planos de leitura que o usuário cria, compartilha e acompanha.
class TelaPlano extends StatefulWidget {
  const TelaPlano({super.key, this.hoje});

  /// Só o teste passa data: é o que permite verificar o cronograma bissexto sem
  /// esperar 2028. Em produção fica nulo e vale o relógio.
  final DateTime? hoje;

  @override
  State<TelaPlano> createState() => _TelaPlanoState();
}

class _TelaPlanoState extends State<TelaPlano> {
  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);

    final acaoDeAjustes = IconButton(
      tooltip: 'Tamanho do texto e aparência',
      icon: const Icon(Icons.tune),
      onPressed: () => ajustesDeLeitura(context, estado),
    );

    // Sem plano personalizado, ou sem conta para guardá-lo na nuvem, a tela
    // não tem o que dividir em abas: só o cronograma anual. A aba Meus
    // Planos depende de conta porque compartilhar um plano depende dela.
    return ListenableBuilder(
      listenable: Nuvem.instancia,
      builder: (context, _) {
        if (!Recursos.planoPersonalizado || !Nuvem.instancia.logado) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Plano'),
              actions: [acaoDeAjustes],
            ),
            body: _AbaDoCronograma(hoje: widget.hoje),
          );
        }
        return _AbasDoPlano(hoje: widget.hoje, acaoDeAjustes: acaoDeAjustes);
      },
    );
  }
}

/// As duas abas de quem tem conta: o cronograma anual e os planos próprios.
class _AbasDoPlano extends StatelessWidget {
  const _AbasDoPlano({required this.hoje, required this.acaoDeAjustes});

  final DateTime? hoje;
  final Widget acaoDeAjustes;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Plano'),
          actions: [acaoDeAjustes],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cronograma'),
              Tab(text: 'Meus planos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AbaDoCronograma(hoje: hoje),
            const _AbaDosMeusPlanos(),
          ],
        ),
      ),
    );
  }
}

/// O cronograma anual: a régua de meses e a lista de dias.
///
/// Vive com `AutomaticKeepAliveClientMixin` porque o TabBarView desmonta a
/// aba que sai da tela: sem isto, trocar para Meus Planos e voltar
/// recomeçaria o mês em janeiro e perderia a rolagem.
class _AbaDoCronograma extends StatefulWidget {
  const _AbaDoCronograma({required this.hoje});

  final DateTime? hoje;

  @override
  State<_AbaDoCronograma> createState() => _AbaDoCronogramaState();
}

class _AbaDoCronogramaState extends State<_AbaDoCronograma>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Getter, não `late final`: o IndexedStack da moldura mantém esta tela viva
  // indefinidamente (ver main.dart), e um valor fixado na primeira leitura
  // travaria "hoje" no dia em que a tela foi aberta, inclusive na virada do
  // ano. Mesmo raciocínio de `_semGestoDeToque` em `lib/telas/biblia.dart`.
  DateTime get _hoje => widget.hoje ?? DateTime.now();
  late int _mes = _hoje.month;

  final _rolagem = ScrollController();

  /// Uma chave por mês, para a régua rolar até o chip do mês escolhido
  /// (espelho do que `_rolarAteHoje` faz com a lista).
  final _chavesDeMes = List.generate(12, (_) => GlobalKey());

  /// Marca o cartão de hoje na lista, para poder rolar até ele.
  final _chaveDeHoje = GlobalKey();

  /// Em qual mês a rolagem automática já aconteceu, para não refazê-la a cada
  /// redesenho nem roubar a posição de quem já rolou a lista com a mão.
  int? _mesJaCentralizado;

  @override
  void initState() {
    super.initState();
    // Na abertura, o mês corrente precisa estar à vista na régua: em agosto,
    // o chip de agosto começava fora da tela enquanto a lista já mostrava
    // agosto (a régua sempre abria em janeiro).
    WidgetsBinding.instance.addPostFrameCallback((_) => _centralizarMes());
  }

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  /// Traz o chip do mês selecionado para o centro da régua. A régua é um
  /// SingleChildScrollView próprio, que não rola junto com a lista: sem isto,
  /// escolher dezembro deixava o chip de dezembro fora da tela.
  void _centralizarMes() {
    if (!mounted) return;
    final contexto = _chavesDeMes[_mes - 1].currentContext;
    if (contexto == null) return;
    Scrollable.ensureVisible(
      contexto,
      alignment: 0.5,
      duration: MediaQuery.disableAnimationsOf(contexto)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// A borda dourada acha o dia de hoje de relance, mas no dia 28 ainda são
  /// vinte e sete cartões de rolagem até chegar nele. Aqui a lista abre já
  /// mostrando o dia, e só no mês corrente: nos outros o topo é o certo.
  void _rolarAteHoje() {
    if (_mes != _hoje.month || _mesJaCentralizado == _mes) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alvo = _chaveDeHoje.currentContext;
      if (!mounted || alvo == null) return;
      _mesJaCentralizado = _mes;
      Scrollable.ensureVisible(
        alvo,
        alignment: 0.15,
        duration: MediaQuery.disableAnimationsOf(alvo)
            ? Duration.zero
            : const Duration(milliseconds: 350),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final estado = EscopoDoEstado.de(context);
    final hoje = _hoje;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sp12,
            vertical: Spacing.sp8,
          ),
          child: Row(
            children: [
              for (var m = 1; m <= 12; m++)
                Padding(
                  key: _chavesDeMes[m - 1],
                  padding: const EdgeInsets.only(right: Spacing.sp8),
                  child: ChoiceChip(
                    label: Text(meses[m - 1]),
                    selected: m == _mes,
                    onSelected: (_) {
                      setState(() => _mes = m);
                      _centralizarMes();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LarguraDeLeitura(
            child: CarregaUmaVez<List<DiaDoPlano>>(
              // A tela mostra o cronograma do ano corrente, então segue a mesma variante
              // que o resto do app: em ano bissexto, a de 366 dias, com 29 de fevereiro
              // como dia próprio. Sem isto, esta tela mostrava sempre a de 365 e
              // discordava de Hoje e do Devocional a partir de março de um ano bissexto.
              //
              // A chave leva o ano porque é ele que escolhe o arquivo; o mês não, porque a
              // filtragem por mês é feita sobre a lista já carregada.
              chave: 'plano/${hoje.year}',
              carregar: () => Conteudo.instancia.plano(
                bissexto: Conteudo.ehBissexto(hoje.year),
              ),
              construir: (context, snap) {
                if (snap.hasError) return const AvisoDeErro();
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final dias = snap.data!.where((d) => d.mes == _mes).toList();
                final lidosNoMes =
                    dias.where((d) => estado.foiLido(d.data)).length;
                _rolarAteHoje();

                return ListView.separated(
                  controller: _rolagem,
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sp16,
                    Spacing.sp12,
                    Spacing.sp16,
                    Spacing.sp32,
                  ),
                  // ponytail: monta o mês inteiro de uma vez em vez de só o visível.
                  // São no máximo 31 cartões leves, e é o que faz o cartão de hoje já
                  // existir na árvore quando _rolarAteHoje procura por ele; sem isso o
                  // GlobalKey de um dia lá embaixo ainda não tem contexto. Se um dia a
                  // lista crescer, o caminho é scrollable_positioned_list.
                  scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
                  itemCount: dias.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: Spacing.sp10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sp6),
                        child: Text(
                          '$lidosNoMes de ${dias.length} dias concluídos em '
                          '${meses[_mes - 1]}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      );
                    }
                    final dia = dias[i - 1];
                    final ehHoje =
                        dia.mes == hoje.month && dia.dia == hoje.day;
                    return CartaoDeDia(
                      key: ehHoje ? _chaveDeHoje : null,
                      numero: dia.dia,
                      rotulo: dia.rotulo,
                      faixas: dia.faixas,
                      lido: estado.foiLido(dia.data),
                      destacar: ehHoje,
                      aoAlternar: () => estado.alternarLido(dia.data),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// A aba Meus Planos: a lista dos planos do usuário e o caminho para criar
/// um novo.
class _AbaDosMeusPlanos extends StatelessWidget {
  const _AbaDosMeusPlanos();

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    final planos = estado.planosDoUsuario;

    return LarguraDeLeitura(
      child: planos.isEmpty
          ? AvisoVazio(
              icone: Icons.edit_calendar_outlined,
              titulo: 'Nenhum plano de leitura ainda',
              detalhe:
                  'Escolha um ou mais livros e em quantos dias quer lê-los: '
                  'o plano se monta sozinho, dia por dia.',
              acao: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Criar plano'),
                onPressed: () => _abrirNovoPlano(context, estado),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sp16,
                Spacing.sp12,
                Spacing.sp16,
                Spacing.sp32,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Seus planos',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Criar plano'),
                      onPressed: () => _abrirNovoPlano(context, estado),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sp12),
                for (final plano in planos) ...[
                  _CartaoDePlano(plano: plano),
                  const SizedBox(height: Spacing.sp10),
                ],
              ],
            ),
    );
  }

  Future<void> _abrirNovoPlano(BuildContext context, Estado estado) async {
    final criado = await Navigator.push<PlanoDoUsuario>(
      context,
      MaterialPageRoute(builder: (_) => TelaNovoPlano(estado: estado)),
    );
    if (criado == null || !context.mounted) return;
    _abrirDetalhe(context, estado, criado);
  }

  void _abrirDetalhe(
    BuildContext context,
    Estado estado,
    PlanoDoUsuario plano,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TelaDeUmPlano(estado: estado, planoId: plano.id, plano: plano),
      ),
    );
  }
}

/// Cartão de um plano na lista de Meus Planos: o que se lê, em quanto tempo
/// e o progresso. Tocar abre o plano; excluir e compartilhar vivem na tela
/// do plano.
class _CartaoDePlano extends StatelessWidget {
  const _CartaoDePlano({required this.plano});

  final PlanoDoUsuario plano;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);
    final dias = plano.diasDoPlano.length;
    final lidos = estado.diasLidosDoPlano(plano.id);
    // Sem criadoPor (plano local, ou o eco de um compartilhar ainda não
    // sincronizado) trata como criador: é sempre este aparelho que o criou.
    final souCriador =
        !plano.compartilhado ||
        plano.criadoPor == null ||
        plano.criadoPor == Nuvem.instancia.uid;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cor.outline.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelaDeUmPlano(
              estado: estado,
              planoId: plano.id,
              plano: plano,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sp14,
            Spacing.sp12,
            Spacing.sp8,
            Spacing.sp12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      plano.titulo,
                      style: tema.titleMedium,
                    ),
                  ),
                  if (plano.compartilhado)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.sp2),
                      child: Tooltip(
                        message: 'Plano compartilhado por link',
                        child: Icon(
                          Icons.group_outlined,
                          size: 18,
                          color: cor.primary,
                        ),
                      ),
                    ),
                  // Lixeira direto no cartão: excluir (ou sair, para quem só
                  // participa) não deveria exigir abrir o plano e achar o
                  // menu de três pontinhos lá dentro. Sem caixa encolhedora:
                  // o alvo de toque fica nos 48dp padrão do IconButton.
                  IconButton(
                    tooltip: souCriador ? 'Excluir plano' : 'Sair do plano',
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: cor.onSurfaceVariant,
                    ),
                    onPressed: () => souCriador
                        ? excluirPlano(
                            context,
                            estado,
                            plano.id,
                            compartilhado: plano.compartilhado,
                          )
                        : sairDoPlano(context, estado, plano.id),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sp2),
              Text(
                listaDosLivros(plano.livros),
                style: tema.bodySmall?.copyWith(color: cor.onSurfaceVariant),
              ),
              Text(
                '${plano.dias} dias · ${plano.totalDeCapitulos} capítulos',
                style: tema.labelMedium?.copyWith(color: cor.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.sp10),
              Text(
                '$lidos de $dias dias lidos',
                style: tema.labelMedium,
              ),
              const SizedBox(height: Spacing.sp6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: dias == 0 ? 0 : lidos / dias,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}