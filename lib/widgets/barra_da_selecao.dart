import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/canon.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import '../funcoes/cartao_imagem.dart';

/// A barra de baixo do modo de seleção: quantos versículos estão marcados e
/// as ações que valem para todos eles. Copiar e Compartilhar usam o mesmo
/// texto da folha de um versículo só, com a referência em faixa
/// ("João 3:16-18") e o link do primeiro versículo marcado.
class DevocionalBarraDaSelecao extends StatelessWidget {
  const DevocionalBarraDaSelecao({
    super.key,
    required this.capitulo,
    required this.selecionados,
    required this.aoFechar,
  });

  final Capitulo capitulo;
  final Set<int> selecionados;
  final VoidCallback aoFechar;

  String get _referencia =>
      referenciaDeVersiculos(capitulo.referencia, selecionados);

  /// Os textos dos marcados na ordem do capítulo, não na ordem dos toques.
  String get _texto => capitulo.versiculos
      .where((v) => selecionados.contains(v.$1))
      .map((v) => v.$2)
      .join(' ');

  String get _link => linkDoVersiculo(
    capitulo.livro,
    capitulo.numero,
    (selecionados.toList()..sort()).first,
  );

  Future<void> _copiar(BuildContext context) async {
    final mensageiro = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(
        text: textoCitado(texto: _texto, referencia: _referencia, link: _link),
      ),
    );
    aoFechar();
    mostrarAvisoNo(mensageiro, 'Versículos copiados.');
  }

  Future<void> _compartilhar(BuildContext context) async {
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      await compartilharCartao(
        texto: '"$_texto"',
        referencia: _referencia,
        link: _link,
        textoParaAcompanhar: textoCitado(
          texto: _texto,
          referencia: _referencia,
          link: _link,
        ),
      );
    } catch (_) {
      mostrarErroNo(mensageiro, 'Não foi possível compartilhar.');
    }
    aoFechar();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Material(
      color: cor.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DevocionalEspacamento.sp8,
            vertical: DevocionalEspacamento.sp4,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancelar seleção',
                onPressed: aoFechar,
                icon: const FaIcon(FontAwesomeIcons.xmark),
              ),
              Expanded(
                child: Text(
                  selecionados.length == 1
                      ? '1 versículo'
                      : '${selecionados.length} versículos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Copiar',
                onPressed: () => _copiar(context),
                icon: FaIcon(FontAwesomeIcons.copy, color: cor.primary),
              ),
              IconButton(
                tooltip: 'Compartilhar',
                onPressed: () => _compartilhar(context),
                icon: FaIcon(
                  FontAwesomeIcons.arrowUpFromBracket,
                  color: cor.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
