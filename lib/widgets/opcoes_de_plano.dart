import 'package:flutter/material.dart';

import '../dados/canon.dart';
import '../estilo/espacamento.dart';

/// Os trechos iguais dos formulários de plano novo e de edição: os livros
/// escolhidos e a opção de incluir devocionais. Um lugar só, para os dois
/// formulários não vestirem o mesmo Material cru cada um à sua maneira.
///
/// Não inclui o botão "Escolher livros" nem os campos de nome e dias: esses
/// falam com o controlador de cada tela, e só a lista e a opção se repetem.
class DevocionalLivrosEscolhidos extends StatelessWidget {
  const DevocionalLivrosEscolhidos({
    super.key,
    required this.livros,
    required this.aoRemover,
  });

  final List<String> livros;
  final ValueChanged<String> aoRemover;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DevocionalEspacamento.sp8,
      runSpacing: DevocionalEspacamento.sp8,
      children: [
        for (final slug in livros)
          InputChip(
            label: Text(nomeDoLivro(slug)),
            // Sem o tique do Material: neste sistema chip não carrega
            // checkmark (ver o alternador de leitura).
            showCheckmark: false,
            onDeleted: () => aoRemover(slug),
          ),
      ],
    );
  }
}

/// A caixa de incluir devocionais com o antes/depois: o mesmo bloco nos dois
/// formulários, com o texto único da opção.
class DevocionalOpcaoDeDevocionais extends StatelessWidget {
  const DevocionalOpcaoDeDevocionais({
    super.key,
    required this.incluir,
    required this.antes,
    required this.aoMudarIncluir,
    required this.aoMudarOrdem,
  });

  final bool incluir;
  final bool antes;
  final ValueChanged<bool?> aoMudarIncluir;
  final ValueChanged<bool> aoMudarOrdem;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          // Explícito em vez do padrão do Material: o metal do tema é a
          // única cor de destaque do sistema.
          activeColor: cor.primary,
          title: const Text('Incluir devocionais dos livros'),
          subtitle: const Text(
            'Junto de cada capítulo, os devocionais de Manhã, '
            'Noite e Promessas de Deus que citam aquele texto.',
          ),
          value: incluir,
          onChanged: aoMudarIncluir,
        ),
        if (incluir) ...[
          const SizedBox(height: DevocionalEspacamento.sp8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DevocionalEspacamento.sp12),
            decoration: BoxDecoration(
              border: Border.all(
                color: cor.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: DevocionalEspacamento.sp8,
              runSpacing: DevocionalEspacamento.sp8,
              children: [
                ChoiceChip(
                  label: const Text('Antes do capítulo'),
                  selected: antes,
                  showCheckmark: false,
                  onSelected: (_) => aoMudarOrdem(true),
                ),
                ChoiceChip(
                  label: const Text('Depois do capítulo'),
                  selected: !antes,
                  showCheckmark: false,
                  onSelected: (_) => aoMudarOrdem(false),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
