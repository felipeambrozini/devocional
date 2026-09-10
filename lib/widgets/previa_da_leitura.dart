import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/conteudo.dart';
import '../dados/modelos.dart';
import '../estilo/spacing.dart';
import '../funcoes/citacao.dart';
import '../telas/biblia.dart';
import '../telas/devocional.dart';
import 'cartao.dart';
import 'carrega_uma_vez.dart';
import 'com_fade_ao_fim.dart';
import 'filete.dart';

/// Prévia de uma das três leituras do dia, com atalho para a tela inteira.
///
/// Serve às três porque só o que muda é de onde o texto vem e se há título e
/// versículo em destaque: Promessas de Deus tem os dois, Manhã e Noite não.
///
/// [destaque] marca a leitura do período da hora (a "de agora"): é a que
/// ganha o filete dourado embaixo do título, dizendo que uma leitura começa
/// ali. As outras leituras do dia mantêm o mesmo cartão, só sem o filete.
class DevocionalPreviaDaLeitura extends StatelessWidget {
  const DevocionalPreviaDaLeitura({
    super.key,
    required this.data,
    required this.leitura,
    this.destaque = false,
  });

  final DateTime data;
  final Leitura leitura;
  final bool destaque;

  String get _titulo => leitura.tituloCompleto;

  FaIconData get _icone => switch (leitura) {
    Leitura.manha => FontAwesomeIcons.sun,
    Leitura.noite => FontAwesomeIcons.moon,
    Leitura.promessas => FontAwesomeIcons.wandMagicSparkles,
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
  Widget _aviso(BuildContext context, String texto) => DevocionalCartao(
    titulo: _titulo,
    acessorio: FaIcon(
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
    return DevocionalCarregaUmaVez<Devocional?>(
      // A chave inclui a leitura e a data para reaproveitar o resultado certo.
      chave: '${leitura.name}/${Conteudo.chaveDoDia(data)}',
      carregar: _futuro,
      construir: (context, snap) {
        // A ordem importa: `snap.data` é nulo enquanto carrega, e só depois
        // de `done` é que nulo significa anomalia. Com os corpora completos
        // (366/366 verificados nos testes), erro de carga e entrada ausente
        // dizem a mesma coisa: conteúdo que devia estar ali não veio.
        if (snap.connectionState != ConnectionState.done) {
          return _aviso(context, 'Carregando...');
        }
        final dev = snap.data;
        if (snap.hasError || dev == null) {
          return _aviso(context, 'Não foi possível carregar esta leitura.');
        }

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
        return DevocionalCartao(
          titulo: _titulo,
          acessorio: FaIcon(_icone, color: cor.primary, size: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O filete sob o título é a gramática da leitura que começa
              // ali, a mesma da capa do devocional: a prévia de agora tem o
              // mesmo gesto de chamada da leitura em si.
              if (destaque) ...[
                const DevocionalFilete(),
                const SizedBox(height: DevocionalEspacamento.sp12),
              ],
              if (dev.titulo.isNotEmpty)
                Text(
                  dev.titulo,
                  style: tema.titleMedium?.copyWith(color: cor.primary),
                ),
              const SizedBox(height: DevocionalEspacamento.sp8),
              // A citação vem antes do nome do livro, e o nome do livro fica
              // ao lado do fim da citação, não numa linha própria embaixo.
              // Mais de uma linha no raro dia com mais de um versículo-base.
              if (spans.isNotEmpty) ...[
                Text.rich(TextSpan(children: spans)),
                const SizedBox(height: DevocionalEspacamento.sp8),
              ],
              // O corte em 5 linhas precisa ler como corte, não como fim do
              // texto: a prévia desvanece a última linha quando o texto
              // realmente não cabe.
              DevocionalComFadeAoFim(
                texto: dev.texto,
                estilo: tema.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: DevocionalEspacamento.sp10),
              Align(
                alignment: Alignment.centerRight,
                // "Ler tudo" é TextButton em todo lugar (ação quieta, ver
                // DESIGN.md); esta prévia usava OutlinedButton e a mesma
                // ação tinha dois controles na mesma tela.
                child: TextButton.icon(
                  onPressed: () => _abrir(context),
                  icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 16),
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
