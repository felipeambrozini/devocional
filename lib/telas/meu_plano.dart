import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../data/estado.dart';
import '../data/nuvem.dart';
import '../data/planos.dart';
import '../data/planos_nuvem.dart';
import '../spacing.dart';
import 'comuns.dart';

/// A tela de um plano do usuário: o que se lê dia a dia, o progresso
/// próprio e, num plano compartilhado, o progresso de cada participante.
///
/// Funciona em dois modos:
/// - plano local: tudo vem do [Estado], e marcar um dia só grava ali;
/// - plano compartilhado: o documento `planos/{id}` do Firestore é a
///   verdade — participantes e dias lidos de cada um — e esta tela assina o
///   stream dele. O espelho local continua sendo atualizado, para a lista de
///   Meus Planos mostrar o progresso sem depender da rede.
///
/// Aberta por link (sem [plano]), a tela primeiro entra no plano — escreve a
/// própria participação — e só então lê o documento. Sem conta, mostra o
/// caminho para entrar.
class TelaDeUmPlano extends StatefulWidget {
  const TelaDeUmPlano({
    super.key,
    required this.estado,
    required this.planoId,
    this.plano,
  });

  final Estado estado;
  final String planoId;

  /// A cópia local do plano, quando a tela veio da lista de Meus Planos.
  /// Nula quando veio de um link: aí o plano só existe na nuvem.
  final PlanoDoUsuario? plano;

  @override
  State<TelaDeUmPlano> createState() => _TelaDeUmPlanoState();
}

class _TelaDeUmPlanoState extends State<TelaDeUmPlano> {
  /// A cópia viva do plano: começa na de [TelaDeUmPlano.plano] e acompanha
  /// a nuvem, para a tela saber quando um plano local passou a compartilhado.
  late PlanoDoUsuario? _plano = widget.plano;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _assinatura;
  DocumentSnapshot<Map<String, dynamic>>? _doc;
  bool _carregando = true;
  String? _erro;

  /// Um plano aberto por link é compartilhado por definição.
  bool get _compartilhado => _plano?.compartilhado ?? true;

  PlanoDoUsuario get _planoOuObrigatorio => _plano!;

  @override
  void initState() {
    super.initState();
    // A tela chega pelo widget.estado, fora do alcance do InheritedNotifier
    // quando aberta por link no Navigator raiz: sem este listener, marcar um
    // dia gravava mas a tela não redesenhava o contador nem o visto do cartão.
    widget.estado.addListener(_aoMudarEstado);
    _iniciar();
  }

  void _aoMudarEstado() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.estado.removeListener(_aoMudarEstado);
    _assinatura?.cancel();
    super.dispose();
  }

  Future<void> _iniciar() async {
    if (!_compartilhado) {
      // Dentro do initState não há o que reconstruir ainda: os campos bastam.
      _carregando = false;
      return;
    }
    if (!Nuvem.instancia.logado) {
      // Sem conta não há documento para ler: o cartão de entrar aparece.
      _carregando = false;
      return;
    }
    try {
      // Participantes leem o documento; quem ainda não é participante recebe
      // erro de permissão — é o sinal de que precisa entrar primeiro.
      final doc = await FirebaseFirestore.instance
          .collection('planos')
          .doc(widget.planoId)
          .get();
      if (!doc.exists) {
        // O plano sumiu da nuvem: sai também do espelho local.
        await widget.estado.removerPlano(widget.planoId);
        throw const PlanosNaNuvemException(
          'Este plano não existe mais. Ele pode ter sido excluído por quem o criou.',
        );
      }
      _aplicarAoEspelho(doc);
      _assinar();
    } catch (erro) {
      try {
        await PlanosNaNuvem.instancia.entrar(widget.planoId);
        _assinar();
      } catch (entrada) {
        if (!mounted) return;
        setState(() {
          _erro = entrada is PlanosNaNuvemException
              ? entrada.mensagem
              : 'Não foi possível abrir o plano. Verifique a conexão.';
          _carregando = false;
        });
      }
    }
  }

  void _assinar() {
    _assinatura = PlanosNaNuvem.instancia
        .deUmPlano(widget.planoId)
        .listen((doc) {
          if (!mounted) return;
          if (!doc.exists) {
            setState(() {
              _doc = null;
              _carregando = false;
              _erro = 'Este plano não existe mais.';
            });
            return;
          }
          _aplicarAoEspelho(doc);
          setState(() {
            _doc = doc;
            _carregando = false;
            _erro = null;
          });
        }, onError: (_) {
          if (!mounted) return;
          setState(() {
            _erro = 'Não foi possível carregar o plano. Verifique a conexão.';
            _carregando = false;
          });
        });
  }

  /// Espelha no [Estado] o que chegou da nuvem: o plano em si e os dias
  /// lidos, para a lista de Meus Planos não depender da rede.
  void _aplicarAoEspelho(DocumentSnapshot<Map<String, dynamic>> doc) {
    final dados = doc.data();
    if (dados == null) return;
    final criadoEm = dados['criadoEm'] is Timestamp
        ? (dados['criadoEm'] as Timestamp).toDate()
        : DateTime.now();
    final plano = PlanoDoUsuario.doJsonDaNuvem(
      dados,
      id: widget.planoId,
      criadoEm: criadoEm,
    );
    final atualizado = widget.estado.planoDoUsuario(widget.planoId);
    if (atualizado != null) _plano = atualizado;
    unawaited(
      widget.estado.aplicarPlanoDaNuvem(plano, lidos: _lidosDe(dados)),
    );
  }

  /// O uid da conta, só onde a nuvem existe. Num plano local não há conta
  /// envolvida, e em plataformas sem Firebase (Android, testes) chamar o
  /// FirebaseAuth derrubaria a tela.
  String? get _uid {
    if (!_compartilhado || !nuvemSuportada) return null;
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Os dias lidos do usuário corrente, segundo a verdade de cada modo.
  Set<int> _lidosDe(Map<String, dynamic> dados) {
    final uid = _uid;
    if (uid == null) return const {};
    final participantes =
        dados['participantes'] as Map<String, dynamic>? ?? const {};
    final minha = participantes[uid];
    if (minha is! Map<String, dynamic> || minha['lidos'] is! List) {
      return const {};
    }
    return {
      for (final dia in minha['lidos'] as List)
        if (dia is int) dia,
    };
  }

  Set<int> _meusLidos() {
    final dados = _doc?.data();
    if (dados != null) return _lidosDe(dados);
    final plano = _plano;
    if (plano == null) return const {};
    return {
      for (final dia in plano.diasDoPlano)
        if (widget.estado.foiLidoNoPlano(plano.id, dia.numero)) dia.numero,
    };
  }

  Future<void> _alternarDia(int dia) async {
    final estado = widget.estado;
    if (_compartilhado) {
      if (!Nuvem.instancia.logado) {
        if (mounted) {
          mostrarAviso(context, 'Entre na sua conta para marcar dias.');
        }
        return;
      }
      // A verdade é o documento: o novo conjunto parte do que ele diz, não
      // do espelho, senão um espelho velho apagaria dias marcados noutro
      // aparelho.
      final atual = {..._meusLidos()};
      final novo = {...atual};
      if (!novo.remove(dia)) novo.add(dia);
      await estado.substituirLidosDoPlano(widget.planoId, novo);
      try {
        await PlanosNaNuvem.instancia.gravarDias(
          widget.planoId,
          novo.toList()..sort(),
        );
      } on PlanosNaNuvemException catch (erro) {
        // Devolve o espelho ao que o documento diz: sem rede a marcação não
        // aconteceu de verdade.
        await estado.substituirLidosDoPlano(widget.planoId, atual);
        if (mounted) mostrarAviso(context, erro.mensagem);
      }
    } else {
      await estado.alternarLidoNoPlano(widget.planoId, dia);
    }
  }

  Future<void> _compartilhar() async {
    final nuvem = Nuvem.instancia;
    if (!nuvem.logado) {
      await entrarNaConta(context, nuvem);
      if (!mounted || !nuvem.logado) return;
    }
    try {
      final link = await PlanosNaNuvem.instancia.compartilhar(
        _planoOuObrigatorio,
      );
      await widget.estado.marcarCompartilhado(_planoOuObrigatorio.id);
      if (!mounted) return;
      setState(() {
        _plano = widget.estado.planoDoUsuario(_planoOuObrigatorio.id);
      });
      await _mostrarLink(context, link);
    } on PlanosNaNuvemException catch (erro) {
      if (mounted) mostrarAviso(context, erro.mensagem);
    }
  }

  Future<void> _copiarLink() async {
    final link = linkDoPlano(widget.planoId);
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) mostrarAviso(context, 'Link copiado.');
  }

  Future<void> _mostrarLink(BuildContext context, String link) async {
    final copiou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plano compartilhado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quem abrir este link entra no plano e o progresso de cada '
              'participante aparece para todos.',
            ),
            const SizedBox(height: Spacing.sp12),
            SelectableText(link),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );
    if (copiou == true && context.mounted) {
      mostrarAviso(context, 'Link copiado.');
    }
  }

  Future<void> _sairDoPlano() async {
    final confirmou = await _confirmar(
      titulo: 'Sair do plano?',
      detalhe:
          'Seu progresso deixa de aparecer para os outros; o plano continua '
          'para quem permaneceu.',
      rotulo: 'Sair',
    );
    if (confirmou != true || !mounted) return;
    try {
      await PlanosNaNuvem.instancia.sair(widget.planoId);
      await widget.estado.removerPlano(widget.planoId);
      if (mounted) Navigator.pop(context);
    } on PlanosNaNuvemException catch (erro) {
      if (mounted) mostrarAviso(context, erro.mensagem);
    }
  }

  Future<void> _excluirPlano({required bool compartilhado}) async {
    final confirmou = await _confirmar(
      titulo: 'Excluir plano?',
      detalhe: compartilhado
          ? 'O plano será apagado para todos os participantes, junto com o '
                'progresso de cada um. Essa ação não pode ser desfeita.'
          : 'O plano e o progresso dele serão apagados. Essa ação não pode '
                'ser desfeita.',
      rotulo: 'Excluir',
    );
    if (confirmou != true || !mounted) return;
    if (compartilhado) {
      try {
        await PlanosNaNuvem.instancia.excluir(widget.planoId);
      } on PlanosNaNuvemException catch (erro) {
        if (mounted) mostrarAviso(context, erro.mensagem);
        return;
      }
    }
    await widget.estado.removerPlano(widget.planoId);
    if (mounted) Navigator.pop(context);
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String detalhe,
    required String rotulo,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(titulo),
          content: Text(detalhe),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(rotulo),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final plano = _plano;
    final dados = _doc?.data();
    final uid = _uid;
    final criador = dados?['criadoPor'] as String?;
    final souCriador = _compartilhado && criador != null && criador == uid;
    final diaCount = plano?.diasDoPlano.length ?? 0;
    final lidos = _meusLidos().length;

    return Scaffold(
      appBar: AppBar(
        title: Text(plano?.titulo ?? 'Plano'),
        actions: [
          if (_compartilhado && dados != null) ...[
            PopupMenuButton<String>(
              tooltip: 'Opções do plano',
              onSelected: (opcao) {
                switch (opcao) {
                  case 'copiar':
                    _copiarLink();
                  case 'sair':
                    _sairDoPlano();
                  case 'excluir':
                    _excluirPlano(compartilhado: true);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'copiar',
                  child: ListTile(
                    leading: Icon(Icons.link),
                    title: Text('Copiar link do plano'),
                  ),
                ),
                if (!souCriador)
                  const PopupMenuItem(
                    value: 'sair',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Sair do plano'),
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'excluir',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Excluir plano'),
                    ),
                  ),
              ],
            ),
          ] else if (!_compartilhado)
            PopupMenuButton<String>(
              tooltip: 'Opções do plano',
              onSelected: (opcao) {
                if (opcao == 'excluir') {
                  _excluirPlano(compartilhado: false);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'excluir',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Excluir plano'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _corpo(dados, plano, diaCount, lidos),
    );
  }

  Widget _corpo(
    Map<String, dynamic>? dados,
    PlanoDoUsuario? plano,
    int diaCount,
    int lidos,
  ) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return AvisoVazio(
        icone: Icons.error_outline,
        titulo: _erro!,
        acao: FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar de novo'),
          onPressed: () {
            setState(() {
              _erro = null;
              _carregando = true;
            });
            _iniciar();
          },
        ),
      );
    }
    final planoLocal = _plano;
    if (planoLocal == null) {
      // Link aberto sem conta: o plano não pôde ser lido.
      return _CartaoDeEntrar(onEntrar: _iniciar);
    }

    final dias = planoLocal.diasDoPlano;
    return LarguraDeLeitura(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sp16,
          Spacing.sp12,
          Spacing.sp16,
          Spacing.sp32,
        ),
        itemCount: dias.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.sp10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CabecalhoDoPlano(
                  plano: planoLocal,
                  lidos: lidos,
                  totalDeDias: diaCount,
                ),
                if (_compartilhado && nuvemSuportada) ...[
                  const SizedBox(height: Spacing.sp10),
                  _CartaoDeCompartilhar(
                    compartilhado: true,
                    aoCompartilhar: _copiarLink,
                  ),
                ] else if (nuvemSuportada) ...[
                  const SizedBox(height: Spacing.sp10),
                  _CartaoDeCompartilhar(
                    compartilhado: false,
                    aoCompartilhar: _compartilhar,
                  ),
                ],
                if (_compartilhado && dados != null) ...[
                  const SizedBox(height: Spacing.sp10),
                  _SecaoDeParticipantes(
                    dados: dados,
                    meuUid: _uid,
                    totalDeDias: diaCount,
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sp6),
                  child: Text(
                    '$lidos de $diaCount dias concluídos',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            );
          }
          final dia = dias[i - 1];
          return CartaoDeDia(
            numero: dia.numero,
            rotulo: dia.rotulo,
            faixas: dia.faixas,
            lido: _meusLidos().contains(dia.numero),
            aoAlternar: () => _alternarDia(dia.numero),
          );
        },
      ),
    );
  }
}

/// O resumo do plano no topo da tela: livros, prazo e o progresso próprio.
class _CabecalhoDoPlano extends StatelessWidget {
  const _CabecalhoDoPlano({
    required this.plano,
    required this.lidos,
    required this.totalDeDias,
  });

  final PlanoDoUsuario plano;
  final int lidos;
  final int totalDeDias;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(resumoDosLivros(plano.livros), style: tema.titleMedium),
            const SizedBox(height: Spacing.sp4),
            Text(
              '${plano.dias} dias · ${plano.totalDeCapitulos} capítulos',
              style: tema.bodySmall?.copyWith(color: cor.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sp12),
            Text(
              '$lidos de $totalDeDias dias lidos',
              style: tema.labelMedium,
            ),
            const SizedBox(height: Spacing.sp6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: totalDeDias == 0 ? 0 : lidos / totalDeDias,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O convite a compartilhar, ou o atalho para copiar o link de novo.
class _CartaoDeCompartilhar extends StatelessWidget {
  const _CartaoDeCompartilhar({
    required this.compartilhado,
    required this.aoCompartilhar,
  });

  final bool compartilhado;
  final VoidCallback aoCompartilhar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compartilhado
                  ? 'Plano compartilhado'
                  : 'Compartilhe o plano',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Spacing.sp4),
            Text(
              compartilhado
                  ? 'Quem abrir o link entra no plano e o progresso de cada '
                        'um aparece para todos.'
                  : 'Quem abrir o link entra no plano, marca os próprios '
                        'dias e o progresso de cada um aparece para todos.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cor.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.sp10),
            OutlinedButton.icon(
              onPressed: aoCompartilhar,
              icon: Icon(
                compartilhado ? Icons.link : Icons.share,
              ),
              label: Text(compartilhado ? 'Copiar link' : 'Compartilhar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// O progresso de cada participante do plano compartilhado.
class _SecaoDeParticipantes extends StatelessWidget {
  const _SecaoDeParticipantes({
    required this.dados,
    required this.meuUid,
    required this.totalDeDias,
  });

  final Map<String, dynamic> dados;
  final String? meuUid;
  final int totalDeDias;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final participantes =
        dados['participantes'] as Map<String, dynamic>? ?? const {};
    final criador = dados['criadoPor'] as String?;
    if (participantes.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participantes (${participantes.length})',
              style: tema.titleSmall,
            ),
            const SizedBox(height: Spacing.sp8),
            for (final MapEntry(key: uid, value: entrada)
                in participantes.entries) ...[
              _LinhaDeParticipante(
                nome: _nomeDe(entrada),
                lidos: _lidosDe(entrada),
                ehVoce: uid == meuUid,
                ehCriador: uid == criador,
                totalDeDias: totalDeDias,
              ),
              const SizedBox(height: Spacing.sp10),
            ],
          ],
        ),
      ),
    );
  }

  String _nomeDe(Object? entrada) {
    if (entrada is Map<String, dynamic>) {
      final nome = entrada['nome'];
      if (nome is String && nome.trim().isNotEmpty) return nome;
    }
    return 'Participante';
  }

  Set<int> _lidosDe(Object? entrada) {
    if (entrada is Map<String, dynamic> && entrada['lidos'] is List) {
      return {
        for (final dia in entrada['lidos'] as List)
          if (dia is int) dia,
      };
    }
    return const {};
  }
}

/// Uma linha da lista de participantes: nome, marca de "Você" e o progresso.
class _LinhaDeParticipante extends StatelessWidget {
  const _LinhaDeParticipante({
    required this.nome,
    required this.lidos,
    required this.ehVoce,
    required this.ehCriador,
    required this.totalDeDias,
  });

  final String nome;
  final Set<int> lidos;
  final bool ehVoce;
  final bool ehCriador;
  final int totalDeDias;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nome,
                style: tema.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (ehCriador)
              Padding(
                padding: const EdgeInsets.only(left: Spacing.sp8),
                child: Text(
                  'criador',
                  style: tema.labelSmall?.copyWith(color: cor.onSurfaceVariant),
                ),
              ),
            if (ehVoce)
              Padding(
                padding: const EdgeInsets.only(left: Spacing.sp8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp8,
                    vertical: Spacing.sp2,
                  ),
                  decoration: BoxDecoration(
                    color: cor.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Você',
                    style: tema.labelSmall?.copyWith(color: cor.primary),
                  ),
                ),
              ),
            const SizedBox(width: Spacing.sp8),
            Text(
              '${lidos.length}/$totalDeDias',
              style: tema.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: Spacing.sp4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: totalDeDias == 0 ? 0 : lidos.length / totalDeDias,
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

/// O caminho para entrar na conta quando o plano foi aberto por link e só
/// participantes o veem.
class _CartaoDeEntrar extends StatelessWidget {
  const _CartaoDeEntrar({required this.onEntrar});

  final VoidCallback onEntrar;

  @override
  Widget build(BuildContext context) {
    return LarguraDeLeitura(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sp20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Este plano é compartilhado por link',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Spacing.sp8),
                Text(
                  'Entre com sua conta para participar, marcar os dias lidos '
                  'e ver o progresso de todos.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Spacing.sp16),
                FilledButton.icon(
                  onPressed: () async {
                    await entrarNaConta(context, Nuvem.instancia);
                    onEntrar();
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar com Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}