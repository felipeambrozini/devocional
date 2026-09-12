import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../dados/personas.dart';
import '../estilo/espacamento.dart';

/// Uma mensagem da conversa: a resposta da persona entra como citação das
/// introduções (fundo chapado e fio do metal à esquerda), e a pergunta do
/// visitante recua em pergaminho com um fio mais discreto. Nada aqui é
/// elevado nem usa o metal como fundo: a palavra da persona é o elemento
/// mais alto da página, não a caixa do visitante.
class DevocionalBalcaoDeMensagem extends StatelessWidget {
  const DevocionalBalcaoDeMensagem({
    super.key,
    required this.mensagem,
    required this.persona,
  });

  final Mensagem mensagem;
  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final usuario = mensagem.doUsuario;

    return Padding(
      padding: const EdgeInsets.only(bottom: DevocionalEspacamento.sp10),
      child: Row(
        mainAxisAlignment: usuario
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!usuario) ...[
            ClipOval(
              child: Image.asset(
                persona.foto,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(width: DevocionalEspacamento.sp8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.symmetric(
                horizontal: DevocionalEspacamento.sp14,
                vertical: DevocionalEspacamento.sp10,
              ),
              decoration: BoxDecoration(
                color: usuario
                    ? cor.surfaceContainer
                    : cor.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: usuario
                    ? Border.all(
                        color: cor.primary.withValues(alpha: 0.4),
                        width: 1,
                      )
                    : Border(left: BorderSide(color: cor.primary, width: 3)),
              ),
              child: Text(
                mensagem.texto,
                style: tema.bodyMedium?.copyWith(
                  color: cor.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
