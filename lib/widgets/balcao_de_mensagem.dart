import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/modelos.dart';
import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import '../estilo/toque.dart';
import 'fala_da_persona.dart';

/// Uma mensagem da conversa: a resposta da persona entra como citação das
/// introduções (fundo chapado e fio do metal à esquerda), e a pergunta do
/// visitante recua em pergaminho com um fio mais discreto. Nada aqui é
/// elevado nem usa o metal como fundo: a palavra da persona é o elemento
/// mais alto da página, não a caixa do visitante.
class TabernaculoBalcaoDeMensagem extends StatelessWidget {
  const TabernaculoBalcaoDeMensagem({
    super.key,
    required this.mensagem,
    required this.persona,
    this.aoDenunciar,
  });

  final Mensagem mensagem;
  final Persona persona;

  /// Só as respostas da IA têm denúncia: a pergunta é do visitante e não é
  /// conteúdo gerado. null na tela que não oferece o caminho (a conversa é a
  /// mesma, mas o teste e a prévia não precisam do botão).
  final VoidCallback? aoDenunciar;

  static const _larguraMaxima = 460.0;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final usuario = mensagem.doUsuario;

    final estilo = tema.bodyMedium?.copyWith(color: cor.onSurface, height: 1.5);

    final bolha = usuario
        // A pergunta do visitante recua em pergaminho, com fio fechado e
        // discreto. Text puro: ela já está no campo de entrada, é só rolar.
        ? Container(
            constraints: const BoxConstraints(maxWidth: _larguraMaxima),
            padding: const EdgeInsets.symmetric(
              horizontal: TabernaculoEspacamento.sp14,
              vertical: TabernaculoEspacamento.sp10,
            ),
            decoration: BoxDecoration(
              color: cor.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cor.primary.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(mensagem.texto, style: estilo),
          )
        // A resposta da persona é selecionável: copiar um trecho (ou
        // mandar para o app de Notas pela folha nativa do aparelho) é o
        // jeito de guardar o que ela disse, já que a conversa mora só
        // neste aparelho.
        : TabernaculoFalaDaPersona(
            persona: persona,
            larguraMaxima: _larguraMaxima,
            // Altura mínima de alvo: o texto selecionável aceita toque
            // longo, e uma resposta de uma linha só ficava com 46.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TabernaculoToque.minimo,
              ),
              child: SelectableText(mensagem.texto, style: estilo),
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: TabernaculoEspacamento.sp10),
      child: Align(
        alignment: usuario ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: usuario
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            bolha,
            if (!usuario && aoDenunciar != null)
              TextButton.icon(
                onPressed: aoDenunciar,
                icon: const FaIcon(FontAwesomeIcons.flag, size: 12),
                label: const Text('Denunciar resposta'),
                style: TextButton.styleFrom(
                  foregroundColor: cor.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TabernaculoEspacamento.sp4,
                  ),
                  minimumSize: const Size(0, TabernaculoToque.minimo),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: tema.labelMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
