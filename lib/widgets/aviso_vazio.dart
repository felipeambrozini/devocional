import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../estilo/espacamento.dart';
import 'botao.dart';

/// Estado de "ainda não há texto para isto", em vez de uma tela em branco.
class DevocionalAvisoVazio extends StatelessWidget {
  const DevocionalAvisoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.detalhe,
    this.acao,
  });

  final FaIconData icone;
  final String titulo;
  final String? detalhe;

  /// A próxima ação do estado vazio, quando existe: "Tentar de novo" num
  /// erro, "Exportar" numa lista vazia que tem saída.
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icone, size: 44, color: cor.outline),
            const SizedBox(height: DevocionalEspacamento.sp16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (detalhe != null) ...[
              const SizedBox(height: DevocionalEspacamento.sp8),
              Text(
                detalhe!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (acao != null) ...[
              const SizedBox(height: DevocionalEspacamento.sp12),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Falha ao ler um asset.
///
/// Existe porque nenhuma tela olhava `snapshot.hasError`: um JSON corrompido ou
/// ausente deixava o CircularProgressIndicator girando para sempre, sem saída e
/// sem dizer o que houve. Girar é promessa de que algo vai chegar; quando não
/// vai, a tela precisa dizer isso.
class DevocionalAvisoDeErro extends StatelessWidget {
  const DevocionalAvisoDeErro({super.key, this.aoTentarDeNovo});

  /// Quando existe, o erro oferece "Tentar de novo" em vez de mandar fechar o
  /// aplicativo: a recuperação fica na tela onde a falha aconteceu.
  final VoidCallback? aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final tentarDeNovo = aoTentarDeNovo;
    return DevocionalAvisoVazio(
      icone: FontAwesomeIcons.triangleExclamation,
      titulo: 'Não foi possível carregar',
      detalhe: tentarDeNovo == null
          ? 'Feche e abra o aplicativo. Se continuar, pode faltar um arquivo de conteúdo.'
          : 'Tente de novo. Se continuar, feche e abra o aplicativo.',
      acao: tentarDeNovo == null
          ? null
          : DevocionalBotaoTerciario(
              onPressed: tentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
    );
  }
}
