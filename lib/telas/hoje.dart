import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/nuvem.dart';
import '../data/registro.dart';
import '../spacing.dart';
import 'biblia.dart';
import 'comuns.dart';
import 'devocional.dart';
import 'faixa.dart';

/// Tela de abertura: quem sou, o devocional da hora, a leitura do dia e o progresso.
class TelaHoje extends StatefulWidget {
  const TelaHoje({super.key});

  @override
  State<TelaHoje> createState() => _TelaHojeState();
}

class _TelaHojeState extends State<TelaHoje> {
  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final estado = EscopoDoEstado.de(context);
    final periodo = Periodo.pelaHora(agora.hour);

    return Scaffold(
      body: SafeArea(
        child: LarguraDeLeitura(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sp16,
              Spacing.sp8,
              Spacing.sp16,
              Spacing.sp32,
            ),
            children: [
              _Cabecalho(data: agora),
              const SizedBox(height: Spacing.sp20),
              // Ajuda só para quem chega: um cartão curto na primeira visita,
              // que some para sempre com "Entendi". Fica antes dos cards de
              // leitura, para orientar quem não conhece o app antes de mostrar
              // o conteúdo do dia.
              if (!estado.ajudaDispensada) ...[
                _CartaoDeAjuda(estado: estado),
                const SizedBox(height: Spacing.sp16),
              ],
              // A leitura do plano abre a tela, antes dos devocionais: é a
              // razão do app existir. A leitura da hora vem logo depois, no
              // cartão que ganha o filete; promessas mantém o cartão sem ele,
              // e o progresso do ano segue a leitura como quem a acompanha.
              _LeituraDeHoje(data: agora),
              const SizedBox(height: Spacing.sp16),
              _PreviaDaLeitura(
                data: agora,
                leitura: periodo == Periodo.manha
                    ? Leitura.manha
                    : Leitura.noite,
                destaque: true,
              ),
              const SizedBox(height: Spacing.sp16),
              _PreviaDaLeitura(data: agora, leitura: Leitura.promessas),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primeira visita: três linhas essenciais e nada mais, para a ajuda não
/// competir com a leitura que abre a tela. A lista completa continua em Sobre
/// ("Ver tudo"), junto com as fontes e a privacidade; o botão "Entendi" some
/// com o cartão para sempre (ver `Estado.ajudaDispensada`).
class _CartaoDeAjuda extends StatelessWidget {
  const _CartaoDeAjuda({required this.estado});

  final Estado estado;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Cartao(
      titulo: 'Como usar',
      acessorio: Icon(
        Icons.auto_stories_outlined,
        color: cor.primary,
        size: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final linha in linhasDeAjuda.take(3)) ...[
            Text(linha, style: tema.bodyMedium),
            const SizedBox(height: Spacing.sp6),
          ],
          const SizedBox(height: Spacing.sp2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context.push('/sobre'),
                child: const Text('Ver tudo'),
              ),
              const SizedBox(width: Spacing.sp8),
              TextButton(
                onPressed: () => estado.dispensarAjuda(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bom dia, boa tarde ou boa noite, só para a saudação — separado de
/// [Periodo], que decide qual devocional (Manhã ou Noite) aparece na
/// prévia. O conteúdo é binário porque Spurgeon só escreveu duas partes por
/// dia; a saudação não precisa seguir a mesma régua.
String _saudacaoPelaHora(int hora) {
  if (hora < 6) return 'Boa noite';
  if (hora < 12) return 'Bom dia';
  if (hora < 18) return 'Boa tarde';
  return 'Boa noite';
}

/// As opções da folha de `_escolherFoto`: as duas fontes do `ImagePicker`
/// mais "remover", que só faz sentido quando já existe uma foto.
enum _AcaoDeFoto { camera, galeria, remover }

/// Deixa escolher entre câmera, galeria ou remover a foto atual — tudo num
/// toque no avatar de `_Cabecalho`.
Future<void> _escolherFoto(BuildContext context) async {
  final temFoto = Nuvem.instancia.fotoUrl != null;
  final acao = await showModalBottomSheet<_AcaoDeFoto>(
    context: context,
    builder: (folha) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Câmera'),
            onTap: () => Navigator.pop(folha, _AcaoDeFoto.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galeria'),
            onTap: () => Navigator.pop(folha, _AcaoDeFoto.galeria),
          ),
          if (temFoto)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remover foto'),
              onTap: () => Navigator.pop(folha, _AcaoDeFoto.remover),
            ),
        ],
      ),
    ),
  );
  if (acao == null || !context.mounted) return;

  final mensageiro = ScaffoldMessenger.of(context);
  if (acao == _AcaoDeFoto.remover) {
    try {
      await Nuvem.instancia.removerFoto();
    } catch (erro, pilha) {
      Registro.erro('_escolherFoto', erro, pilha);
      mostrarErroNo(mensageiro, 'Não foi possível remover a foto.');
    }
    return;
  }

  final arquivo = await ImagePicker().pickImage(
    source: acao == _AcaoDeFoto.camera
        ? ImageSource.camera
        : ImageSource.gallery,
    // Foto de perfil não precisa da resolução da câmera; menor já poupa
    // banda no upload e no carregamento do avatar depois.
    maxWidth: 512,
    imageQuality: 85,
  );
  if (arquivo == null || !context.mounted) return;

  try {
    await Nuvem.instancia.atualizarFoto(await arquivo.readAsBytes());
  } catch (erro, pilha) {
    Registro.erro('_escolherFoto', erro, pilha);
    mostrarErroNo(mensageiro, 'Não foi possível atualizar a foto.');
  }
}

/// Confirma e executa o logout. Um toque no "Sair" não pode deslogar sem
/// pergunta: na web, o espelho na nuvem é a proteção contra o navegador
/// limpar o armazenamento local, e derrubar a sessão desarma essa proteção.
Future<void> _sairDaConta(BuildContext context) async {
  final confirmou = await confirmar(
    context,
    titulo: 'Sair da conta?',
    conteudo:
        'Favoritos, notas e progresso ficam neste aparelho, mas a cópia na '
        'nuvem para de se atualizar. Na web, é ela que devolve os dados se o '
        'navegador limpar o armazenamento.',
    rotuloDaAcao: 'Sair',
  );
  if (!confirmou || !context.mounted) return;
  final mensageiro = ScaffoldMessenger.of(context);
  try {
    await Nuvem.instancia.sair();
    mostrarAvisoNo(mensageiro, 'Você saiu da conta.');
  } catch (erro, pilha) {
    Registro.erro('_sairDaConta', erro, pilha);
    mostrarErroNo(mensageiro, 'Não foi possível sair agora. Tente de novo.');
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final saudacao = _saudacaoPelaHora(data.hour);

    return ListenableBuilder(
      listenable: Nuvem.instancia,
      builder: (context, _) {
        final nuvem = Nuvem.instancia;
        final nome = nuvem.primeiroNome;
        return Row(
          children: [
            // Avatar da própria conta Google de quem entrou; sem conta, sem
            // avatar — só a saudação, igual na web e no aparelho.
            if (nuvem.logado) ...[
              GestureDetector(
                onTap: () => _escolherFoto(context),
                child: CircleAvatar(
                  radius: 30,
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
              const SizedBox(width: Spacing.sp14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quem entrou com a conta Google ganha o próprio nome na
                  // saudação, em todas as plataformas: o botão de entrar mora
                  // no fim desta mesma linha. Sem conta, fica só a saudação.
                  Text(
                    nome != null ? '$saudacao, $nome' : saudacao,
                    style: tema.headlineMedium,
                  ),
                  const SizedBox(height: Spacing.sp4),
                  Text(dataLonga(data), style: tema.bodySmall),
                ],
              ),
            ),
            // Entrar ou sair da conta, no fim do cabeçalho: o convite para
            // entrar mora aqui (e não mais na folha de ajustes), porque o
            // estado da conta muda a saudação ao lado.
            _BotaoDeConta(),
            // Hoje não tem AppBar onde pendurar a ação, e sem isto os ajustes
            // só seriam alcançáveis de duas das seis abas.
            BotaoDeAjustes(estado: EscopoDoEstado.de(context)),
          ],
        );
      },
    );
  }
}

/// Entrar ou sair da conta, no fim do cabeçalho da Hoje. Uma linha só para
/// os dois estados, nunca os dois ao mesmo tempo: convite para entrar, ou o
/// botão "Sair" de quem já entrou (o e-mail fica no Sobre, em "Conta e
/// privacidade").
class _BotaoDeConta extends StatelessWidget {
  const _BotaoDeConta();

  @override
  Widget build(BuildContext context) {
    final nuvem = Nuvem.instancia;
    return ListenableBuilder(
      listenable: nuvem,
      builder: (context, _) => nuvem.logado
          ? TextButton.icon(
              onPressed: () => _sairDaConta(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair'),
            )
          : OutlinedButton.icon(
              onPressed: nuvem.entrando ? null : () => entrarNaConta(context, nuvem),
              icon: nuvem.entrando
                  ? const SizedBox(
                      width: Spacing.sp18,
                      height: Spacing.sp18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login, size: 18),
              label: const Text('Entrar'),
            ),
    );
  }
}

/// Texto de até 5 linhas que desvanece na última quando o corte é real.
///
/// A reticência sozinha parecia um fim de texto, e a prévia competia com o
/// resto do cartão: o corte vira um convite ao "Ler tudo" quando se lê como
/// corte. O `TextPainter` decide antes de pintar se o texto estoura; só então
/// o `ShaderMask` suaviza a quinta linha para o fundo (o `dstIn` usa só o
/// alfa do gradiente, preservando a cor do texto).
class _ComFadeAoFim extends StatelessWidget {
  const _ComFadeAoFim({required this.texto, required this.estilo});

  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: texto, style: estilo),
          maxLines: 5,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        if (!painter.didExceedMaxLines) {
          return Text(
            texto,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          );
        }
        return ShaderMask(
          shaderCallback: (limites) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.82, 0.95, 1.0],
          ).createShader(limites),
          blendMode: BlendMode.dstIn,
          child: Text(
            texto,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          ),
        );
      },
    );
  }
}

/// Prévia de uma das três leituras do dia, com atalho para a tela inteira.
///
/// Serve às três porque só o que muda é de onde o texto vem e se há título e
/// versículo em destaque: Promessas de Deus tem os dois, Manhã e Noite não.
///
/// [destaque] marca a leitura do período da hora (a "de agora"): é a que
/// ganha o filete dourado embaixo do título, dizendo que uma leitura começa
/// ali. As outras leituras do dia mantêm o mesmo cartão, só sem o filete.
class _PreviaDaLeitura extends StatelessWidget {
  const _PreviaDaLeitura({
    required this.data,
    required this.leitura,
    this.destaque = false,
  });

  final DateTime data;
  final Leitura leitura;
  final bool destaque;

  String get _titulo => leitura.tituloCompleto;

  IconData get _icone => switch (leitura) {
    Leitura.manha => Icons.wb_sunny_outlined,
    Leitura.noite => Icons.nightlight_outlined,
    Leitura.promessas => Icons.auto_awesome_outlined,
  };

  Future<Devocional?> _futuro() {
    final periodo = leitura.periodo;
    return periodo == null
        ? Conteudo.instancia.promessa(data)
        : Conteudo.instancia.devocional(data, periodo);
  }

  void _abrir(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          TelaDevocional(dataInicial: data, leituraInicial: leitura),
    ),
  );

  /// Cartão de uma linha só, para quando ainda não há texto para mostrar.
  Widget _aviso(BuildContext context, String texto) => Cartao(
    titulo: _titulo,
    acessorio: Icon(
      _icone,
      color: Theme.of(context).colorScheme.primary,
      size: 20,
    ),
    child: Text(texto),
  );

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return CarregaUmaVez<Devocional?>(
      // A chave inclui a leitura e a data para reaproveitar o resultado certo.
      chave: '${leitura.name}/${Conteudo.chaveDoDia(data)}',
      carregar: _futuro,
      construir: (context, snap) {
        // Os três casos precisam ser separados. `snap.data` é nulo tanto enquanto
        // carrega quanto quando não existe leitura para a data, e tratar os dois
        // como um só deixava o cartão dizendo "Carregando..." para sempre num dia
        // sem devocional. É o mesmo guard que _LeituraDeHoje já usa logo abaixo.
        if (snap.hasError) {
          return _aviso(context, 'Não foi possível carregar esta leitura.');
        }
        if (snap.connectionState != ConnectionState.done) {
          return _aviso(context, 'Carregando...');
        }
        final dev = snap.data;
        if (dev == null) return _aviso(context, 'Sem leitura para esta data.');

        final spans = spansDeCitacao(
          dev,
          estiloCitacao: tema.bodyMedium?.copyWith(
            height: 1.6,
            fontStyle: FontStyle.italic,
            color: cor.secondary,
          ),
          estiloReferencia: tema.titleSmall?.copyWith(color: cor.secondary),
          // A prévia segue o cartão do devocional: a referência da epígrafe
          // abre a Bíblia no versículo citado.
          aoAbrirReferencia: (livro, capitulo, deVersiculo, ateVersiculo) =>
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TelaBiblia(
                    livroInicial: livro.slug,
                    capituloInicial: capitulo,
                    destacar: (deVersiculo, ateVersiculo),
                  ),
                ),
              ),
        );
        return Cartao(
          titulo: _titulo,
          acessorio: Icon(_icone, color: cor.primary, size: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O filete sob o título é a gramática da leitura que começa
              // ali, a mesma da capa do devocional: a prévia de agora tem o
              // mesmo gesto de chamada da leitura em si.
              if (destaque) ...[
                const Filete(),
                const SizedBox(height: Spacing.sp12),
              ],
              if (dev.titulo.isNotEmpty)
                Text(
                  dev.titulo,
                  style: tema.titleMedium?.copyWith(color: cor.primary),
                ),
              const SizedBox(height: Spacing.sp8),
              // A citação vem antes do nome do livro, e o nome do livro fica
              // ao lado do fim da citação, não numa linha própria embaixo.
              // Mais de uma linha no raro dia com mais de um versículo-base.
              if (spans.isNotEmpty) ...[
                Text.rich(TextSpan(children: spans)),
                const SizedBox(height: Spacing.sp8),
              ],
              // O corte em 5 linhas precisa ler como corte, não como fim do
              // texto: a prévia desvanece a última linha quando o texto
              // realmente não cabe.
              _ComFadeAoFim(
                texto: dev.texto,
                estilo: tema.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: Spacing.sp10),
              Align(
                alignment: Alignment.centerRight,
                // "Ler tudo" é TextButton em todo lugar (ação quieta, ver
                // DESIGN.md); esta prévia usava OutlinedButton e a mesma
                // ação tinha dois controles na mesma tela.
                child: TextButton.icon(
                  onPressed: () => _abrir(context),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Ler tudo'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeituraDeHoje extends StatelessWidget {
  const _LeituraDeHoje({required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    return CarregaUmaVez<DiaDoPlano?>(
      chave: Conteudo.chaveDoDia(data),
      carregar: () => Conteudo.instancia.diaDoPlano(data),
      construir: (context, snap) {
        if (snap.hasError) {
          return _CartaoLeituraProgressoErro(
            mensagem: 'Não foi possível carregar o cronograma.',
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const _CartaoLeituraProgressoCarregando();
        }
        final dia = snap.data!;
        return _CartaoLeituraProgresso(
          dia: dia,
          estado: estado,
          ano: data.year,
        );
      },
    );
  }
}

/// Cartão unificado: leitura de hoje + progresso do ano, no estilo devocional.
class _CartaoLeituraProgresso extends StatelessWidget {
  const _CartaoLeituraProgresso({
    required this.dia,
    required this.estado,
    required this.ano,
  });

  final DiaDoPlano dia;
  final Estado estado;
  final int ano;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final lido = estado.foiLido(dia.data);
    final total = Conteudo.diasDoAno(ano);
    final progresso = estado.progressoDoAno(total);

    return Cartao(
      padding: const EdgeInsets.all(Spacing.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com título e ação de marcar como lido
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Filete(),
                    const SizedBox(height: Spacing.sp12),
                    Text('Leitura de hoje', style: tema.titleLarge),
                  ],
                ),
              ),
              IconButton(
                tooltip: lido ? 'Desmarcar' : 'Marcar como lido',
                icon: Icon(
                  lido ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: lido ? cor.secondary : cor.onSurfaceVariant,
                ),
                onPressed: () =>
                    alternarLidoComDesfazer(context, estado, dia.data),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sp8),
          // Rótulo do dia (ex: "Dia 1 — Gênesis 1–2")
          Text(dia.rotulo, style: tema.bodyLarge),
          const SizedBox(height: Spacing.sp12),
          // Faixas do dia
          Wrap(
            spacing: Spacing.sp8,
            runSpacing: Spacing.sp8,
            children: [for (final f in dia.faixas) BotaoDeFaixa(faixa: f)],
          ),
          const SizedBox(height: Spacing.sp20),
          // Filete separador antes do progresso
          const Filete(),
          const SizedBox(height: Spacing.sp14),
          // Progresso do ano
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Progresso do ano', style: tema.labelMedium),
              const Spacer(),
              Text(
                '${estado.diasLidos}',
                style: tema.titleMedium?.copyWith(color: cor.primary),
              ),
              const SizedBox(width: Spacing.sp6),
              Text('de $total dias', style: tema.bodySmall),
            ],
          ),
          const SizedBox(height: Spacing.sp8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progresso.clamp(0.0, 1.0),
              minHeight: 5,
              color: cor.primary,
              backgroundColor: cor.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoLeituraProgressoErro extends StatelessWidget {
  const _CartaoLeituraProgressoErro({required this.mensagem});
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Cartao(
      padding: const EdgeInsets.all(Spacing.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Filete(),
          const SizedBox(height: Spacing.sp12),
          Text('Leitura de hoje', style: tema.titleLarge),
          const SizedBox(height: Spacing.sp8),
          Text(mensagem, style: tema.bodyMedium),
        ],
      ),
    );
  }
}

class _CartaoLeituraProgressoCarregando extends StatelessWidget {
  const _CartaoLeituraProgressoCarregando();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Cartao(
      padding: const EdgeInsets.all(Spacing.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Filete(),
          const SizedBox(height: Spacing.sp12),
          Text('Leitura de hoje', style: tema.titleLarge),
          const SizedBox(height: Spacing.sp8),
          Text('Carregando...', style: tema.bodyMedium),
        ],
      ),
    );
  }
}