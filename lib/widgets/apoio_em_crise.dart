import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dados/registro.dart';
import '../estilo/espacamento.dart';
import '../funcoes/aviso.dart';
import 'botao.dart';

/// Contato do CVV, fixo acima do campo do chat depois que uma mensagem dá
/// sinal de crise (ver `lib/dados/crise.dart`). Fica até a conversa fechar:
/// quem precisa dele não pode depender de rolar até a resposta certa. Os
/// botões vêm antes do texto para continuarem à vista quando o espaço aperta.
class DevocionalApoioEmCrise extends StatelessWidget {
  const DevocionalApoioEmCrise({super.key});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card(
        margin: const EdgeInsets.fromLTRB(
          DevocionalEspacamento.sp16,
          DevocionalEspacamento.sp8,
          DevocionalEspacamento.sp16,
          0,
        ),
        child: Padding(
          padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Você não está sozinho', style: tema.titleMedium),
              ),
              const SizedBox(height: DevocionalEspacamento.sp12),
              Wrap(
                spacing: DevocionalEspacamento.sp8,
                runSpacing: DevocionalEspacamento.sp8,
                children: [
                  DevocionalBotaoPrimario.icon(
                    onPressed: () => _abrir(
                      context,
                      Uri.parse('tel:188'),
                      seFalhar: 'Ligue 188 de qualquer telefone.',
                    ),
                    icon: const FaIcon(FontAwesomeIcons.phone, size: 16),
                    label: const Text('Ligar para o 188'),
                  ),
                  DevocionalBotaoTerciario(
                    onPressed: () => _abrir(
                      context,
                      Uri.https('cvv.org.br'),
                      seFalhar: 'Abra cvv.org.br no navegador.',
                    ),
                    child: const Text('Abrir cvv.org.br'),
                  ),
                ],
              ),
              const SizedBox(height: DevocionalEspacamento.sp12),
              Text(
                'Se você pensa em tirar a própria vida, converse agora com '
                'alguém. O CVV atende de graça, a qualquer hora, pelo '
                'telefone 188 ou pelo chat do site cvv.org.br. Em perigo '
                'imediato, ligue 192.',
                style: tema.bodyMedium?.copyWith(color: cor.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre o telefone ou o site; onde não há como (computador sem discador), diz
/// o que fazer em vez de deixar o botão parecer morto.
Future<void> _abrir(
  BuildContext context,
  Uri destino, {
  required String seFalhar,
}) async {
  final mensageiro = ScaffoldMessenger.of(context);
  try {
    if (await launchUrl(destino, mode: LaunchMode.externalApplication)) return;
  } catch (erro, pilha) {
    Registro.erro('DevocionalApoioEmCrise', erro, pilha);
  }
  mostrarAvisoNo(mensageiro, seFalhar);
}
