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

/// Pede confirmação e apaga o áudio de [livro]. Baixar um livro pode levar
/// minutos de rede, então um toque solto não apaga.
Future<void> _apagarComConfirmacao(
  BuildContext context,
  LivroParaBaixar livro,
) async {
  final apagar = await confirmar(
    context,
    titulo: 'Apagar o áudio de ${livro.titulo}?',
    conteudo:
        'O áudio sai do aparelho e volta a tocar só com internet. Dá para baixar de novo depois.',
    rotuloDaAcao: 'Apagar',
  );
  if (apagar) await AudioOffline.instancia.apagarLivro(livro);
}

/// Onde está o áudio de um livro: o que já baixou, se está baixando agora e
/// quanto falta, tudo lido do [AudioOffline].
class _SituacaoDoLivro {
  _SituacaoDoLivro(AudioOffline off, LivroParaBaixar livro)
    : total = livro.chaves.length,
      baixados = math.min(off.contagemDoLivro(livro) ?? 0, livro.chaves.length),
      baixandoEste = off.estaBaixando(livro),
      outroBaixando = off.baixando && !off.estaBaixando(livro),
      progresso = off.progresso,
      erro = off.erroDo(livro),
      // Livro da Bíblia sem amostra própria (a lista dos 66 não faz um HEAD
      // por livro) usa a média da categoria, amostrada pela folha de ajustes.
      _bytesPorArquivo =
          off.tamanhoMedioDoLivro(livro) ??
          (livro.pasta.startsWith('biblia/')
              ? off.tamanhoMedioPorCategoria['biblia']
              : null);

  final int total;
  final int baixados;
  final bool baixandoEste;
  final bool outroBaixando;
  final double progresso;
  final String? erro;
  final int? _bytesPorArquivo;

  bool get pronto => total > 0 && baixados >= total;
  bool get comecado => baixados > 0 && !pronto;
  String? get estimativa => estimativaEmMb(_bytesPorArquivo, total - baixados);
}

enum _Forma { botao, linha }

/// Baixar, parar ou apagar o áudio de um livro inteiro, da Bíblia ou da
/// Biblioteca: o mesmo componente nos dois lugares, pelo [LivroParaBaixar].
///
/// - [TabernaculoBaixarLivro.new], o botão da página do livro: o sumário de um
///   livro da Biblioteca e o seletor de capítulos da Bíblia. Some quando o
///   livro não tem áudio no Storage e nada dele está no aparelho.
/// - [TabernaculoBaixarLivro.emLista], a linha da lista "Livros da Bíblia" dos
///   ajustes: o nome do livro fica sempre, e a ação aparece só quando há o que
///   baixar ou apagar.
///
/// O Storage não deixa listar pastas, então um HEAD no primeiro capítulo (com
/// o cache de [Voz.disponibilidadeRemota]) responde pelo livro: os livros
/// ganham áudio inteiros. Some onde não há onde guardar o áudio (web sem
/// service worker, ver [AudioOffline.suportado]) e com o Ouvir desligado no
/// painel, como a seção de áudio offline dos ajustes.
class TabernaculoBaixarLivro extends StatefulWidget {
  const TabernaculoBaixarLivro({
    super.key,
    required this.livro,
    this.alinhamento = Alignment.centerLeft,
  }) : _forma = _Forma.botao;

  const TabernaculoBaixarLivro.emLista({super.key, required this.livro})
    : alinhamento = Alignment.centerLeft,
      _forma = _Forma.linha;

  final LivroParaBaixar livro;

  /// Onde fica o botão de baixar. O seletor da Bíblia centraliza, como o
  /// título e o "Todos os livros" acima dele. Não vale para [emLista].
  final AlignmentGeometry alinhamento;

  final _Forma _forma;

  @override
  State<TabernaculoBaixarLivro> createState() => _BaixarLivroState();
}

class _BaixarLivroState extends State<TabernaculoBaixarLivro> {
  /// Se o áudio do livro está no Storage; `null` enquanto confere.
  bool? _noStorage;

  LivroParaBaixar get _livro => widget.livro;

  @override
  void initState() {
    super.initState();
    if (AudioOffline.instancia.suportado) unawaited(_conferir());
  }

  @override
  void didUpdateWidget(covariant TabernaculoBaixarLivro antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.livro != widget.livro) {
      _noStorage = null;
      if (AudioOffline.instancia.suportado) unawaited(_conferir());
    }
  }

  Future<void> _conferir() async {
    final livro = _livro;
    final off = AudioOffline.instancia;
    if (off.contagemDoLivro(livro) == null) await off.contarLivro(livro);
    if (livro.chaves.isEmpty) return;
    var remoto = DisponibilidadeRemota.semRede;
    try {
      remoto = await Voz.instancia.disponibilidadeRemota(livro.chaves.first);
    } catch (erro, pilha) {
      Registro.erro(
        'AudioOffline: conferir ${livro.pasta} no Storage',
        erro,
        pilha,
      );
    }
    if (!mounted || livro != _livro) return;
    setState(() => _noStorage = remoto == DisponibilidadeRemota.existe);
    // Na lista dos 66 seria um HEAD por livro: ela usa a média da categoria.
    if (remoto == DisponibilidadeRemota.existe &&
        widget._forma == _Forma.botao) {
      unawaited(off.estimarLivro(livro));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AudioOffline.instancia.suportado) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([
        AudioOffline.instancia,
        ConfigAdmin.instancia,
      ]),
      builder: (context, _) {
        if (!Recursos.ouvirTextos) return const SizedBox.shrink();
        final s = _SituacaoDoLivro(AudioOffline.instancia, _livro);
        return switch (widget._forma) {
          _Forma.botao => _botao(context, s),
          _Forma.linha => _linha(context, s),
        };
      },
    );
  }

  void _baixar() => AudioOffline.instancia.baixarLivro(_livro);

  Widget _botao(BuildContext context, _SituacaoDoLivro s) {
    if (_noStorage != true && s.baixados == 0 && !s.baixandoEste) {
      return const SizedBox.shrink();
    }
    final off = AudioOffline.instancia;
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
                const SizedBox(height: TabernaculoEspacamento.sp6),
                TabernaculoProgressoFino(
                  valor: s.progresso,
                  rotulo: 'Baixando o áudio de ${_livro.titulo}',
                ),
              ],
            ),
          ),
          const SizedBox(width: TabernaculoEspacamento.sp12),
          TabernaculoBotaoTerciario(
            onPressed: off.cancelar,
            child: const Text('Parar'),
          ),
        ],
      );
    } else if (s.pronto) {
      linha = Row(
        children: [
          FaIcon(FontAwesomeIcons.circleCheck, size: 16, color: cor.primary),
          const SizedBox(width: TabernaculoEspacamento.sp8),
          Expanded(
            child: Text(
              kIsWeb
                  ? 'Áudio neste navegador, toca sem internet'
                  : 'Áudio no aparelho, toca sem internet',
              style: tema.bodyMedium,
            ),
          ),
          TabernaculoBotaoTerciario(
            onPressed: s.outroBaixando
                ? null
                : () => _apagarComConfirmacao(context, _livro),
            child: const Text('Apagar'),
          ),
        ],
      );
    } else {
      linha = Align(
        alignment: widget.alinhamento,
        child: TabernaculoBotaoTerciario.icon(
          // Outro download em andamento: um lote por vez.
          onPressed: s.outroBaixando || _noStorage != true ? null : _baixar,
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
    // liveRegion só no fim (baixado ou erro): no botão parado ele atropelava o
    // título do seletor ao trocar de livro, e durante o download cada passo
    // da barra seria reanunciado. Quem tocou em Baixar já sabe que começou.
    final centralizado = widget.alinhamento == Alignment.center;
    return Padding(
      padding: const EdgeInsets.only(top: TabernaculoEspacamento.sp8),
      child: Semantics(
        liveRegion: s.pronto || s.erro != null,
        child: Column(
          crossAxisAlignment: centralizado
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            linha,
            if (s.erro != null)
              Text(
                s.erro!,
                textAlign: centralizado ? TextAlign.center : TextAlign.start,
                style: tema.bodySmall?.copyWith(color: cor.error),
              ),
          ],
        ),
      ),
    );
  }

  Widget _linha(BuildContext context, _SituacaoDoLivro s) {
    final off = AudioOffline.instancia;
    final tema = Theme.of(context).textTheme;
    final nome = _livro.titulo;
    final capitulos = s.total == 1 ? '1 capítulo' : '${s.total} capítulos';
    final Widget subtitulo;
    if (s.baixandoEste) {
      subtitulo = Padding(
        padding: const EdgeInsets.only(top: TabernaculoEspacamento.sp6),
        child: TabernaculoProgressoFino(
          valor: s.progresso,
          rotulo: 'Baixando $nome',
        ),
      );
    } else if (s.erro != null) {
      subtitulo = Text(
        s.erro!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    } else if (s.pronto) {
      subtitulo = const Text('Baixado');
    } else if (s.comecado) {
      subtitulo = Text('${s.baixados} de ${s.total} capítulos');
    } else if (_noStorage == false) {
      subtitulo = Text('$capitulos · sem áudio ainda');
    } else {
      subtitulo = Text([capitulos, ?s.estimativa].join(' · '));
    }
    final Widget? acao;
    if (s.baixandoEste) {
      acao = TabernaculoBotaoTerciario(
        onPressed: off.cancelar,
        child: const Text('Parar'),
      );
    } else if (s.pronto) {
      acao = IconButton(
        icon: const FaIcon(FontAwesomeIcons.trash, size: 18),
        tooltip: 'Apagar $nome',
        onPressed: s.outroBaixando
            ? null
            : () => _apagarComConfirmacao(context, _livro),
      );
    } else if (_noStorage == true) {
      acao = IconButton(
        icon: const FaIcon(FontAwesomeIcons.download, size: 18),
        tooltip: s.comecado ? 'Continuar $nome' : 'Baixar $nome',
        onPressed: s.outroBaixando ? null : _baixar,
      );
    } else {
      acao = null;
    }
    return ListTile(
      title: Text(nome),
      // Anuncia o fim (baixado ou erro), como o botão da página do livro.
      subtitle: Semantics(
        liveRegion: s.pronto || s.erro != null,
        child: DefaultTextStyle.merge(style: tema.bodySmall, child: subtitulo),
      ),
      trailing: acao,
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
                  TabernaculoEspacamento.sp20,
                  TabernaculoEspacamento.sp8,
                  TabernaculoEspacamento.sp20,
                  TabernaculoEspacamento.sp4,
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
                  horizontal: TabernaculoEspacamento.sp20,
                ),
                child: Text(
                  'Baixe só os livros que vai ouvir',
                  style: tema.bodySmall,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: TabernaculoEspacamento.sp8),
            ),
            SliverList.builder(
              itemCount: canon.length,
              itemBuilder: (context, i) => TabernaculoBaixarLivro.emLista(
                livro: LivroParaBaixar.daBiblia(canon[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
