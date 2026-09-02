import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/audio_offline.dart';
import '../data/estado.dart';
import '../data/eventos.dart';
import '../data/lembretes.dart';
import '../data/modelos.dart';
import '../funcoes/aviso.dart';
import '../funcoes/lembretes_acoes.dart';
import '../estilo/spacing.dart';
import 'filete.dart';

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
/// de conversa, lembretes - e Sobre, que deixou de ser aba e voltou
/// para a folha quando a URL das conversas passou a ser refletida no
/// navegador (ver `main.dart`, `optionURLReflectsImperativeAPIs`).
///
/// A folha fala dois assuntos e um Filete os divide: o que se ajusta na
/// leitura (tamanho, aparência e, na web, as setas do rodapé) vem antes;
/// o que é do app inteiro (conversas, lembretes, Sobre) vem depois. Quem
/// abriu da AppBar do leitor encontra o assunto da leitura sem rolar.
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
  // Varre o disco (contagem e tamanho) e amostra o MB estimado uma vez, ao
  // abrir — não a cada notificação de progresso do download, que é o que
  // travava a folha (ver AudioOffline.atualizarContagens/estimarTamanhos).
  if (!kIsWeb) {
    unawaited(AudioOffline.instancia.atualizarContagens());
    unawaited(AudioOffline.instancia.estimarTamanhos());
  }
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
                // Setas de virar capítulo são assunto da web: no celular o
                // rodapé nem existe. Leitura é o assunto do bloco de cima,
                // por isso as setas fecham este primeiro grupo.
                if (kIsWeb) ..._SecaoDasSetas(estado: estado).montar(context),
                // O Filete divide os dois assuntos da folha: o que se ajusta
                // na leitura (acima) e o que é do app inteiro (abaixo).
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sp20,
                    Spacing.sp24,
                    Spacing.sp20,
                    0,
                  ),
                  child: const Filete(largura: 64),
                ),
                // Lembrete exclusivo do Android: alarme agendado no próprio
                // aparelho (ver lembretes.dart). iOS e web ficam de fora.
                if (lembretesSuportados)
                  ..._SecaoDeLembretes(estado: estado).montar(context),
                // Áudio offline: download dos MP3 pré-gerados para uso sem rede.
                // Ordem pedida: Bíblia, Introdução, Manhã e Noite, Promessas.
                if (!kIsWeb) ..._SecaoAudioOffline().montar(context),
                // Sobre no fim da folha: as escolhas do dia ficam na frente,
                // e fontes, canais e privacidade esperam quem rola até o fim.
                _ItemDeNavegacaoDaFolha(
                  folha: folha,
                  icone: Icons.info_outline,
                  titulo: 'Sobre',
                  subtitulo: 'Fontes do texto, canais e privacidade',
                  rota: '/sobre',
                ),
                _ItemDeNavegacaoDaFolha(
                  folha: folha,
                  icone: Icons.help_outline,
                  titulo: 'Perguntas frequentes',
                  rota: '/faq',
                ),
                _ItemDeNavegacaoDaFolha(
                  folha: folha,
                  icone: Icons.privacy_tip_outlined,
                  titulo: 'Política de privacidade',
                  rota: '/privacidade',
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

/// Uma entrada da folha de ajustes que abre uma tela com URL própria: sai da
/// folha antes do push — uma rota sobre a folha a deixaria embaixo da tela
/// nova no Android.
class _ItemDeNavegacaoDaFolha extends StatelessWidget {
  const _ItemDeNavegacaoDaFolha({
    required this.folha,
    required this.icone,
    required this.titulo,
    required this.rota,
    this.subtitulo,
  });

  final BuildContext folha;
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final String rota;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icone, color: Theme.of(context).colorScheme.primary),
      title: Text(titulo),
      subtitle: subtitulo == null ? null : Text(subtitulo!),
      onTap: () {
        final roteador = GoRouter.of(folha);
        Navigator.pop(folha);
        roteador.push(rota);
      },
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
        subtitle: const Text('Quatro horários independentes.'),
        value: estado.lembretesAtivos,
        onChanged: (novo) => _alternar(context, novo),
      ),
      if (estado.lembretesAtivos) ...[
        _linhaDeHorario(
          context,
          titulo: 'Leitura do Dia',
          minutos: estado.minutosLembreteLeitura,
          aoEscolher: (minutos) =>
              aplicarHorarioDeLembrete(estado, minutosLeitura: minutos),
        ),
        _linhaDeHorario(
          context,
          titulo: 'Manhã',
          minutos: estado.minutosLembreteManha,
          aoEscolher: (minutos) =>
              aplicarHorarioDeLembrete(estado, minutosManha: minutos),
        ),
        _linhaDeHorario(
          context,
          titulo: 'Promessas',
          minutos: estado.minutosLembretePromessas,
          aoEscolher: (minutos) =>
              aplicarHorarioDeLembrete(estado, minutosPromessas: minutos),
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
    final hora = horaDeMinutos(minutos);
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
      mostrarErro(
        context,
        'Permissão de notificação negada. Ative em Configurações do '
        'aparelho para usar os lembretes.',
      );
    }
  }
}

/// Áudio offline: baixa os MP3 pré-gerados para ouvir sem rede.
/// Ordem fixa pedida: Bíblia, Introdução, Manhã e Noite, Promessas.
/// Baixa a categoria e registra os dois eventos de uso ao redor do download
/// real (`AudioOffline.baixarCategoria` não sabe de Analytics — ver o
/// limite entre dado e coleta em lib/data/eventos.dart).
Future<void> _baixarComEvento(AudioOffline off, String categoria) async {
  unawaited(registrarDownloadIniciado(categoria));
  await off.baixarCategoria(categoria);
  if (off.erro == null) unawaited(registrarDownloadConcluido(categoria));
}

class _SecaoAudioOffline {
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
        child: Text('Áudio offline', style: tema.headlineSmall),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sp20),
        child: Text(
          'Baixe para ouvir sem internet. Na ordem: Bíblia, Introdução, Manhã e Noite, Promessas. O player usa o arquivo local quando existir, senão baixa da nuvem.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      const SizedBox(height: Spacing.sp8),
      ListenableBuilder(
        listenable: AudioOffline.instancia,
        builder: (context, _) {
          final off = AudioOffline.instancia;
          const ordem = ['biblia', 'introducao', 'manha_noite', 'promessas'];
          const rotulos = {
            'biblia': 'Bíblia (1.189 capítulos)',
            'introducao': 'Introduções (66 livros)',
            'manha_noite': 'Manhã e Noite (732)',
            'promessas': 'Promessas de Deus (366)',
          };
          const totais = {
            'biblia': 1189,
            'introducao': 66,
            'manha_noite': 732,
            'promessas': 366,
          };
          // Contagem, tamanho total e a amostra de MB já vêm prontos do
          // ListenableBuilder acima (AudioOffline.atualizarContagens/
          // estimarTamanhos rodam uma vez só, ao abrir a folha) — nenhuma
          // leitura de disco nem HEAD acontece durante o build.
          return Column(
            children: [
              for (final cat in ordem)
                Builder(
                  builder: (context) {
                    final baixados = off.contagemPorCategoria[cat] ?? 0;
                    final total = totais[cat]!;
                    final pronto = baixados >= total && total > 0;
                    final baixandoEste =
                        off.baixando && off.categoriaAtiva == cat;
                    final mediaBytes = off.tamanhoMedioPorCategoria[cat];
                    final faltam = total - baixados;
                    final estimativaMb = mediaBytes == null || faltam <= 0
                        ? null
                        : (mediaBytes * faltam / (1024 * 1024))
                              .toStringAsFixed(1);
                    return ListTile(
                      title: Text(rotulos[cat]!),
                      subtitle: baixandoEste
                          ? LinearProgressIndicator(value: off.progresso)
                          : Text(pronto ? 'Baixado' : '$baixados/$total'),
                      trailing: pronto
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Apagar',
                              onPressed: off.baixando
                                  ? null
                                  : () => off.apagarCategoria(cat),
                            )
                          : baixandoEste
                          ? OutlinedButton(
                              onPressed: off.cancelar,
                              child: const Text('Parar'),
                            )
                          : FilledButton(
                              onPressed: off.baixando
                                  ? null
                                  : () => _baixarComEvento(off, cat),
                              child: Text(
                                [
                                  baixados > 0 && baixados < total
                                      ? 'Continuar'
                                      : 'Baixar',
                                  if (estimativaMb != null)
                                    '(~$estimativaMb MB)',
                                ].join(' '),
                              ),
                            ),
                    );
                  },
                ),
              if (off.erro != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sp20),
                  child: Text(
                    off.erro!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Builder(
                builder: (context) {
                  final mb = (off.tamanhoTotalBytes / (1024 * 1024))
                      .toStringAsFixed(1);
                  return ListTile(
                    title: Text('Armazenamento: $mb MB'),
                    trailing: TextButton(
                      onPressed: off.baixando ? null : () => off.apagarTudo(),
                      child: const Text('Apagar tudo'),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    ];
  }
}

/// A seção "Navegação" da folha de ajustes: esconde (ou traz de volta) os
/// chevrons de capítulo do rodapé do leitor. Só existe na web — no celular a
/// barra nem é construída (`_semGestoDeToque`, em `biblia.dart`).
///
/// Ao esconder, avisa dos atalhos que ficam: as setas do teclado passam de
/// capítulo e Enter/espaço apertam o botão em foco — ninguém pode perder o
/// jeito de virar página por desligar um botão.
class _SecaoDasSetas {
  const _SecaoDasSetas({required this.estado});

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
        child: Text('Navegação', style: tema.headlineSmall),
      ),
      SwitchListTile(
        title: const Text('Setas para virar o capítulo'),
        subtitle: const Text(
          'Os botões ‹ › no rodapé da Bíblia. Sem elas, o teclado vira '
          'o capítulo: setas esquerda e direita, Enter ou espaço.',
        ),
        value: estado.setasDoRodape,
        onChanged: (novo) async {
          await estado.definirSetasDoRodape(novo);
          if (!novo && context.mounted) {
            mostrarAviso(
              context,
              'Setas escondidas. Para virar o capítulo sem elas: setas do '
              'teclado, Enter ou espaço.',
            );
          }
        },
      ),
    ];
  }
}
