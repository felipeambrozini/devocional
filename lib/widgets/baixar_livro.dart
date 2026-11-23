import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/audio_offline.dart';
import '../dados/canon.dart';
import '../dados/config_admin.dart';
import '../dados/recursos.dart';
import '../dados/registro.dart';
import '../dados/voz.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import 'botao.dart';
import 'progresso_fino.dart';

/// "~12,3 MB" para [bytes] por arquivo vezes [arquivos], ou `null` sem
/// amostra (melhor não mostrar número nenhum do que um inventado).
String? estimativaEmMb(int? bytes, int arquivos) {
  if (bytes == null || arquivos <= 0) return null;
  final mb = bytes * arquivos / (1024 * 1024);
  return '~${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// Pede confirmação e apaga o áudio de [nome], guardado em [pasta]. Baixar um
/// livro pode levar minutos de rede, então um toque solto não apaga.
Future<void> _apagarComConfirmacao(
  BuildContext context,
  String pasta,
  String nome,
) async {
  final apagar = await confirmar(
    context,
    titulo: 'Apagar o áudio de $nome?',
    conteudo:
        'O áudio sai do aparelho e volta a tocar só com internet. Dá para baixar de novo depois.',
    rotuloDaAcao: 'Apagar',
  );
  if (apagar) await AudioOffline.instancia.apagarLivro(pasta);
}

/// Onde está o áudio de um livro: o que já baixou, se está baixando agora e
/// quanto falta, tudo lido do [AudioOffline].
class _SituacaoDoLivro {
  _SituacaoDoLivro(AudioOffline off, String pasta, List<String> chaves)
    : total = chaves.length,
      baixados = math.min(off.contagemDoLivro(pasta) ?? 0, chaves.length),
      baixandoEste = off.baixando && off.loteAtivo == pasta,
      outroBaixando = off.baixando && off.loteAtivo != pasta,
      progresso = off.progresso,
      erro = off.loteDoErro == pasta ? off.erro : null,
      estimativa = estimativaEmMb(
        off.tamanhoMedioDoLivro(pasta) ??
            (pasta.startsWith('biblia/')
                ? off.tamanhoMedioPorCategoria['biblia']
                : null),
        chaves.length -
            math.min(off.contagemDoLivro(pasta) ?? 0, chaves.length),
      );

  final int total;
  final int baixados;
  final bool baixandoEste;
  final bool outroBaixando;
  final double progresso;
  final String? erro;
  final String? estimativa;

  bool get pronto => total > 0 && baixados >= total;
  bool get comecado => baixados > 0 && !pronto;
}

/// Confere uma vez se o áudio do livro está no Storage (um HEAD no primeiro
/// capítulo, com o cache de [Voz.disponibilidadeRemota]) e conta o que já
/// está no aparelho. O bucket não deixa listar pastas: os livros ganham áudio
/// inteiros, então o primeiro capítulo responde pelo livro todo.
///
/// Some na web (não há disco) e com o Ouvir desligado no painel, como a seção
/// de áudio offline dos ajustes.
class _ComAudioDoLivro extends StatefulWidget {
  const _ComAudioDoLivro({
    required this.pasta,
    required this.chaves,
    required this.amostrarTamanho,
    required this.construir,
  });

  final String pasta;
  final List<String> chaves;

  /// Se faz um HEAD a mais para estimar o MB deste livro. A lista da Bíblia
  /// usa a média da categoria, já amostrada pela folha de ajustes, em vez de
  /// 66 pedidos.
  final bool amostrarTamanho;

  /// Monta o conteúdo. `noStorage` é `null` enquanto confere.
  final Widget Function(BuildContext context, bool? noStorage) construir;

  @override
  State<_ComAudioDoLivro> createState() => _ComAudioDoLivroState();
}

class _ComAudioDoLivroState extends State<_ComAudioDoLivro> {
  bool? _noStorage;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) unawaited(_conferir());
  }

  @override
  void didUpdateWidget(covariant _ComAudioDoLivro antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.pasta != widget.pasta) {
      _noStorage = null;
      if (!kIsWeb) unawaited(_conferir());
    }
  }

  Future<void> _conferir() async {
    final pasta = widget.pasta;
    final chaves = widget.chaves;
    final off = AudioOffline.instancia;
    if (off.contagemDoLivro(pasta) == null) await off.contarLivro(pasta);
    if (chaves.isEmpty) return;
    var remoto = DisponibilidadeRemota.semRede;
    try {
      remoto = await Voz.instancia.disponibilidadeRemota(chaves.first);
    } catch (erro, pilha) {
      Registro.erro('AudioOffline: conferir $pasta no Storage', erro, pilha);
    }
    if (!mounted || pasta != widget.pasta) return;
    setState(() => _noStorage = remoto == DisponibilidadeRemota.existe);
    if (remoto == DisponibilidadeRemota.existe && widget.amostrarTamanho) {
      unawaited(off.estimarLivro(pasta, chaves));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([
        AudioOffline.instancia,
        ConfigAdmin.instancia,
      ]),
      builder: (context, _) {
        if (!Recursos.ouvirTextos) return const SizedBox.shrink();
        return widget.construir(context, _noStorage);
      },
    );
  }
}

/// Baixar o áudio de um livro da Biblioteca, no sumário dele. Só aparece
/// quando o áudio do livro já está no Storage, ou quando parte dele já está
/// no aparelho (para continuar ou apagar).
class DevocionalBaixarLivro extends StatelessWidget {
  const DevocionalBaixarLivro({
    super.key,
    required this.titulo,
    required this.pasta,
    required this.chaves,
  });

  /// O nome do livro, para a confirmação de apagar.
  final String titulo;

  /// A pasta do livro em `audio_offline/` ([pastaDoLivroDaBiblioteca]).
  final String pasta;

  /// As chaves da voz dos capítulos ([chavesDoLivroDaBiblioteca]).
  final List<String> chaves;

  @override
  Widget build(BuildContext context) {
    return _ComAudioDoLivro(
      pasta: pasta,
      chaves: chaves,
      amostrarTamanho: true,
      construir: (context, noStorage) {
        final off = AudioOffline.instancia;
        final s = _SituacaoDoLivro(off, pasta, chaves);
        if (noStorage != true && s.baixados == 0 && !s.baixandoEste) {
          return const SizedBox.shrink();
        }
        final cor = Theme.of(context).colorScheme;
        final tema = Theme.of(context).textTheme;
        final Widget linha;
        if (s.baixandoEste) {
          linha = Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Baixando o áudio', style: tema.bodyMedium),
                    const SizedBox(height: DevocionalEspacamento.sp6),
                    DevocionalProgressoFino(
                      valor: s.progresso,
                      rotulo: 'Baixando o áudio de $titulo',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DevocionalEspacamento.sp12),
              DevocionalBotaoTerciario(
                onPressed: off.cancelar,
                child: const Text('Parar'),
              ),
            ],
          );
        } else if (s.pronto) {
          linha = Row(
            children: [
              FaIcon(
                FontAwesomeIcons.circleCheck,
                size: 16,
                color: cor.primary,
              ),
              const SizedBox(width: DevocionalEspacamento.sp8),
              Expanded(
                child: Text(
                  'Áudio no aparelho, toca sem internet',
                  style: tema.bodyMedium,
                ),
              ),
              DevocionalBotaoTerciario(
                onPressed: s.outroBaixando
                    ? null
                    : () => _apagarComConfirmacao(context, pasta, titulo),
                child: const Text('Apagar'),
              ),
            ],
          );
        } else {
          linha = Align(
            alignment: Alignment.centerLeft,
            child: DevocionalBotaoTerciario.icon(
              // Outro download em andamento: um lote por vez.
              onPressed: s.outroBaixando || noStorage != true
                  ? null
                  : () => off.baixarLivro(pasta, chaves),
              icon: const FaIcon(FontAwesomeIcons.download, size: 16),
              label: Text(
                [
                  s.comecado
                      ? 'Continuar o download (${s.baixados} de ${s.total})'
                      : 'Baixar o áudio',
                  ?s.estimativa,
                ].join(' · '),
              ),
            ),
          );
        }
        // liveRegion: a troca de "Baixar" por "Baixando" e depois por "Áudio
        // no aparelho" (ou pelo erro) é anunciada ao leitor de tela.
        return Padding(
          padding: const EdgeInsets.only(top: DevocionalEspacamento.sp8),
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                linha,
                if (s.erro != null)
                  Text(
                    s.erro!,
                    style: tema.bodySmall?.copyWith(color: cor.error),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Abre a lista dos 66 livros da Bíblia para baixar ou apagar o áudio de
/// cada um, em vez da Bíblia inteira de uma vez.
Future<void> mostrarLivrosDaBibliaOffline(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _LivrosDaBibliaOffline(),
  );
}

class _LivrosDaBibliaOffline extends StatelessWidget {
  const _LivrosDaBibliaOffline();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    // Nome da rota: sem ele, a folha abre sem título no TalkBack e VoiceOver.
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Livros da Bíblia',
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, rolagem) => CustomScrollView(
          controller: rolagem,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DevocionalEspacamento.sp20,
                  DevocionalEspacamento.sp8,
                  DevocionalEspacamento.sp20,
                  DevocionalEspacamento.sp4,
                ),
                child: Semantics(
                  header: true,
                  child: Text('Livros da Bíblia', style: tema.headlineSmall),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DevocionalEspacamento.sp20,
                ),
                child: Text(
                  'Baixe só os livros que vai ouvir',
                  style: tema.bodySmall,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: DevocionalEspacamento.sp8),
            ),
            SliverList.builder(
              itemCount: canon.length,
              itemBuilder: (context, i) =>
                  _LinhaDoLivroOffline(livro: canon[i]),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaDoLivroOffline extends StatelessWidget {
  const _LinhaDoLivroOffline({required this.livro});

  final Livro livro;

  @override
  Widget build(BuildContext context) {
    final pasta = pastaDoLivroDaBiblia(livro.slug);
    final chaves = chavesDoLivroDaBiblia(livro);
    return _ComAudioDoLivro(
      pasta: pasta,
      chaves: chaves,
      amostrarTamanho: false,
      construir: (context, noStorage) {
        final off = AudioOffline.instancia;
        final s = _SituacaoDoLivro(off, pasta, chaves);
        final tema = Theme.of(context).textTheme;
        final capitulos = livro.capitulos == 1
            ? '1 capítulo'
            : '${livro.capitulos} capítulos';
        final Widget subtitulo;
        if (s.baixandoEste) {
          subtitulo = Padding(
            padding: const EdgeInsets.only(top: DevocionalEspacamento.sp6),
            child: DevocionalProgressoFino(
              valor: s.progresso,
              rotulo: 'Baixando ${livro.nome}',
            ),
          );
        } else if (s.pronto) {
          subtitulo = const Text('Baixado');
        } else if (s.comecado) {
          subtitulo = Text('${s.baixados} de ${s.total} capítulos');
        } else if (noStorage == false) {
          subtitulo = Text('$capitulos · sem áudio ainda');
        } else {
          subtitulo = Text([capitulos, ?s.estimativa].join(' · '));
        }
        final Widget? acao;
        if (s.baixandoEste) {
          acao = DevocionalBotaoTerciario(
            onPressed: off.cancelar,
            child: const Text('Parar'),
          );
        } else if (s.pronto) {
          acao = IconButton(
            icon: const FaIcon(FontAwesomeIcons.trash, size: 18),
            tooltip: 'Apagar ${livro.nome}',
            onPressed: s.outroBaixando
                ? null
                : () => _apagarComConfirmacao(context, pasta, livro.nome),
          );
        } else if (noStorage == true) {
          acao = IconButton(
            icon: const FaIcon(FontAwesomeIcons.download, size: 18),
            tooltip: s.comecado
                ? 'Continuar ${livro.nome}'
                : 'Baixar ${livro.nome}',
            onPressed: s.outroBaixando
                ? null
                : () => off.baixarLivro(pasta, chaves),
          );
        } else {
          acao = null;
        }
        return ListTile(
          title: Text(livro.nome),
          subtitle: DefaultTextStyle.merge(
            style: tema.bodySmall,
            child: subtitulo,
          ),
          trailing: acao,
        );
      },
    );
  }
}
