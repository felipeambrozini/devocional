import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../data/conteudo.dart';
import '../data/modelos.dart';
import '../telas/biblia.dart';

/// Botão que abre a Bíblia numa faixa do cronograma.
///
/// Quando a faixa é por versículo, como "Salmos 119:1 a 56", abre o capítulo e
/// destaca só o recorte pedido; o resto do capítulo continua visível, apenas
/// esmaecido, para não perder o contexto.
class BotaoDeFaixa extends StatelessWidget {
  const BotaoDeFaixa({super.key, required this.faixa});

  final Faixa faixa;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const FaIcon(FontAwesomeIcons.bookOpen, size: 17),
      label: Text(faixa.rotulo),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaBiblia(
            livroInicial: faixa.livro,
            capituloInicial: faixa.deCapitulo,
            destacar: faixa.porVersiculo
                ? (faixa.deVersiculo!, faixa.ateVersiculo!)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Botão que abre o devocional (Manhã, Noite ou Promessas) citado por um
/// capítulo do plano, na data em que foi publicado — o conteúdo não depende
/// do ano, só do dia-mês (ver `Conteudo.chaveDoDia`).
class BotaoDeDevocional extends StatelessWidget {
  const BotaoDeDevocional({
    super.key,
    required this.tipo,
    required this.chaveDoDia,
  });

  final TipoDeDevocional tipo;
  final String chaveDoDia;

  FaIconData get _icone => switch (tipo) {
    TipoDeDevocional.manha => FontAwesomeIcons.sun,
    TipoDeDevocional.noite => FontAwesomeIcons.moon,
    TipoDeDevocional.promessa => FontAwesomeIcons.wandMagicSparkles,
  };

  /// Para Manhã e Noite, o nome do tipo. Para Promessas, o título da
  /// promessa do dia — "Promessa" sozinho não diz nada sobre o que ela é.
  String get _rotulo {
    if (tipo != TipoDeDevocional.promessa) return tipo.nome;
    final titulo = Conteudo.instancia.tituloDaPromessa(chaveDoDia);
    return titulo != null && titulo.isNotEmpty ? titulo : tipo.nome;
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: FaIcon(_icone, size: 17),
      label: Text(_rotulo),
      onPressed: () {
        final partes = chaveDoDia.split('-');
        final dia = int.parse(partes[0]);
        final mes = int.parse(partes[1]);
        final ano = DateTime.now().year;
        final parametroDeData =
            '$ano-${mes.toString().padLeft(2, '0')}-'
            '${dia.toString().padLeft(2, '0')}';
        GoRouter.of(context).go('/${tipo.rota}?data=$parametroDeData');
      },
    );
  }
}
