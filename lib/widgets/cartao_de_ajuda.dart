import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../estilo/espacamento.dart';
import '../funcoes/linhas_de_ajuda.dart';
import '../telas/biblia.dart';
import 'botao.dart';
import 'cartao.dart';

/// Primeira visita: três linhas essenciais e nada mais, para a ajuda não
/// competir com a leitura que abre a tela. A lista completa continua em Sobre
/// ("Ver tudo"), junto com as fontes e a privacidade; o botão "Entendi" some
/// com o cartão para sempre (ver `Estado.ajudaDispensada`).
class DevocionalCartaoDeAjuda extends StatelessWidget {
  const DevocionalCartaoDeAjuda({super.key, required this.estado});

  final Estado estado;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return DevocionalCartao(
      titulo: 'Como usar',
      acessorio: FaIcon(
        FontAwesomeIcons.bookOpenReader,
        color: cor.primary,
        size: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final linha in linhasDeAjuda.take(3)) ...[
            Text(linha, style: tema.bodyMedium),
            const SizedBox(height: DevocionalEspacamento.sp6),
          ],
          if (!Nuvem.instancia.logado) ...[
            const SizedBox(height: DevocionalEspacamento.sp2),
            Semantics(
              hint: 'Abre o Evangelho de João, capítulo 1',
              child: DevocionalBotaoSecundario(
                onPressed: () => _abrirJoao1(context),
                child: const Text('Começar por João 1'),
              ),
            ),
          ],
          const SizedBox(height: DevocionalEspacamento.sp2),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: DevocionalEspacamento.sp8,
            children: [
              DevocionalBotaoTerciario(
                onPressed: () => context.push('/sobre'),
                child: const Text('Ver tudo'),
              ),
              DevocionalBotaoTerciario(
                onPressed: () => estado.dispensarAjuda(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _abrirJoao1(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TelaBiblia(
          livroInicial: 'joao',
          capituloInicial: 1,
          destacar: (1, 18),
        ),
      ),
    );
  }
}
