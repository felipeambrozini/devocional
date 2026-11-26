import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../dados/planos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/conta_acoes.dart';
import '../funcoes/origem_do_destaque.dart';
import '../funcoes/planos_acoes.dart';
import '../funcoes/sair_da_conta.dart';
import '../widgets/widgets.dart';

/// O perfil, aberto pela foto no cabeçalho da Hoje: o que a conta guarda além
/// do dia a dia. Uma página só, nesta ordem: quem está na conta, o cronograma
/// de anos anteriores, os planos concluídos, favoritos e notas, e a conta
/// (Sair e Apagar). Cronograma e planos só aparecem quando há o que mostrar.
class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key, this.hoje});

  /// O dia que decide o que é "ano anterior"; sem ele, o relógio. Existe
  /// para os testes não dependerem da data em que rodam.
  final DateTime? hoje;

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  /// O Sair confirmado e ainda andando. Mora aqui, acima da troca entre o
  /// perfil e o convite de entrar: quando a conta sai, o perfil vira convite,
  /// e este estado precisa continuar montado para voltar à Hoje.
  bool _saindo = false;

  Future<void> _sair() async {
    final saiu = await sairDaConta(
      context,
      aoConfirmar: () => setState(() => _saindo = true),
    );
    if (!mounted) return;
    setState(() => _saindo = false);
    if (saiu) context.go('/hoje');
  }

  Future<void> _apagar() async {
    final apagou = await apagarContaDaNuvem(context);
    if (apagou && mounted) context.go('/hoje');
  }

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    return Scaffold(
      appBar: TabernaculoAppBar(
        title: const Text('Perfil'),
        actions: [TabernaculoBotaoDeAjustes(estado: estado)],
      ),
      body: ListenableBuilder(
        listenable: Nuvem.instancia,
        builder: (context, _) {
          final nuvem = Nuvem.instancia;
          if (nuvem.logado) return _perfil(context, estado);
          // Durante a restauração da sessão, nada: o convite piscaria para
          // quem já está logado (mesma regra do cronograma).
          if (nuvem.carregandoConta) return const SizedBox.shrink();
          return const TabernaculoCartaoDeEntrar(
            titulo: 'Entre para ver seu perfil',
            descricao:
                'O perfil reúne o que fica na sua conta: o cronograma de '
                'anos anteriores, os planos concluídos, os favoritos e as '
                'notas.',
          );
        },
      ),
    );
  }

  Widget _perfil(BuildContext context, Estado estado) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    final hoje = widget.hoje ?? DateTime.now();
    final anos = estado.anosAnterioresComLeitura(anoAtual: hoje.year);
    final concluidos = _planosConcluidos(estado);
    final (:favoritos, :notas) = contarFavoritosENotas(estado);
    final seta = FaIcon(
      FontAwesomeIcons.angleRight,
      size: 16,
      color: cor.onSurfaceVariant,
    );

    return TabernaculoLarguraDeLeitura(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          TabernaculoEspacamento.sp20,
          TabernaculoEspacamento.sp16,
          TabernaculoEspacamento.sp20,
          TabernaculoEspacamento.sp40,
        ),
        children: [
          _cabecalho(context),
          if (anos.isNotEmpty) ...[
            const SizedBox(height: TabernaculoEspacamento.sp32),
            _tituloDeSecao(context, 'Cronograma'),
            for (final ano in anos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '$ano · ${estado.diasLidosNoAno(ano)} de '
                  '${Conteudo.diasDoAno(ano)} dias',
                ),
                trailing: seta,
                onTap: () => context.push('/perfil/cronograma/$ano'),
              ),
          ],
          if (concluidos.isNotEmpty) ...[
            const SizedBox(height: TabernaculoEspacamento.sp32),
            _tituloDeSecao(context, 'Planos concluídos'),
            for (final plano in concluidos) ...[
              TabernaculoCartaoDePlano(
                plano: plano,
                rodape: _rodapeDoConcluido(context, estado, plano),
                aoAbrir: () => context.go('/plano/${plano.id}'),
              ),
              const SizedBox(height: TabernaculoEspacamento.sp10),
            ],
          ],
          const SizedBox(height: TabernaculoEspacamento.sp32),
          _tituloDeSecao(context, 'Favoritos e notas'),
          if (favoritos == 0)
            Text(
              'Nenhum favorito nem nota ainda',
              style: tema.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
            )
          else ...[
            Text('Favoritos $favoritos · Notas $notas', style: tema.bodyLarge),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ver todos'),
              trailing: seta,
              onTap: () => context.push('/notas?aba=todas'),
            ),
          ],
          const SizedBox(height: TabernaculoEspacamento.sp32),
          _tituloDeSecao(context, 'Conta'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FaIcon(
              _saindo
                  ? FontAwesomeIcons.hourglassHalf
                  : FontAwesomeIcons.rightFromBracket,
              color: cor.primary,
            ),
            title: const Text('Sair'),
            // O Sair espera tudo chegar à conta, o que pode levar uns
            // segundos: sem o aviso, o toque parecia ignorado. Sem onTap
            // enquanto isso, para não pedir outro Sair por cima.
            subtitle: _saindo
                ? Semantics(
                    liveRegion: true,
                    child: const Text('Salvando na conta antes de sair'),
                  )
                : null,
            onTap: _saindo ? null : _sair,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FaIcon(FontAwesomeIcons.trash, color: cor.error),
            title: const Text('Apagar conta e dados da nuvem'),
            subtitle: const Text(
              'Apaga sua conta no app e tudo o que ela guarda. O que está '
              '$ondeFicaACopiaLocal não é tocado.',
            ),
            onTap: _saindo ? null : _apagar,
          ),
        ],
      ),
    );
  }

  /// Foto (ou inicial), nome e e-mail de quem está na conta.
  Widget _cabecalho(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme;
    final nuvem = Nuvem.instancia;
    final aparado = nuvem.nome?.trim();
    final nome = aparado == null || aparado.isEmpty ? null : aparado;
    final email = nuvem.email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // A foto é enfeite: o nome está ao lado.
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 36,
                backgroundImage: nuvem.fotoUrl != null
                    ? NetworkImage(nuvem.fotoUrl!)
                    : null,
                child: nuvem.fotoUrl == null
                    ? Text(
                        (nome ?? '?').substring(0, 1).toUpperCase(),
                        style: tema.headlineMedium?.copyWith(
                          color: cor.primary,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: TabernaculoEspacamento.sp14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      nome ?? 'Sua conta',
                      style: tema.headlineMedium,
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: TabernaculoEspacamento.sp4),
                    Text(
                      email,
                      style: tema.bodySmall?.copyWith(
                        color: cor.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: TabernaculoEspacamento.sp14),
        const TabernaculoFilete(largura: 64),
      ],
    );
  }

  Widget _tituloDeSecao(BuildContext context, String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: TabernaculoEspacamento.sp10),
    child: Semantics(
      header: true,
      child: Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );

  /// A data em que o plano foi concluído e o "Fazer de novo", que o devolve a
  /// Meus planos sem nenhum dia lido.
  Widget _rodapeDoConcluido(
    BuildContext context,
    Estado estado,
    PlanoDoUsuario plano,
  ) {
    final data = estado.concluidoEm(plano.id);
    return Row(
      children: [
        Expanded(
          child: data == null
              ? const SizedBox.shrink()
              : Text(
                  'Concluído em ${_dataNumerica(data)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
        ),
        TabernaculoBotaoTerciario.icon(
          onPressed: () => fazerPlanoDeNovo(context, estado, plano),
          icon: const FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 16),
          label: const Text('Fazer de novo'),
        ),
      ],
    );
  }
}

/// Os planos concluídos, do concluído mais recentemente ao mais antigo. Sem
/// data (não deveria acontecer: o Estado dá a data ao notar a conclusão) vai
/// para o fim.
List<PlanoDoUsuario> _planosConcluidos(Estado estado) {
  final concluidos = [
    for (final plano in estado.planosParaExibir)
      if (estado.planoEstaConcluido(plano)) plano,
  ];
  concluidos.sort((a, b) {
    final dataA = estado.concluidoEm(a.id);
    final dataB = estado.concluidoEm(b.id);
    if (dataA == null) return dataB == null ? 0 : 1;
    if (dataB == null) return -1;
    return dataB.compareTo(dataA);
  });
  return concluidos;
}

/// "02/09/2026".
String _dataNumerica(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/'
    '${data.month.toString().padLeft(2, '0')}/${data.year}';
