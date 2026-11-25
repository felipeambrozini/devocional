import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/config_admin.dart';
import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../widgets/widgets.dart';

/// A aba Conversas: a porta de entrada do chat no celular e no computador.
///
/// A aba fica visível para todo mundo — só o conteúdo muda com
/// [Recursos.conversas]: quem está na allowlist vê a carta de cada persona;
/// quem não está vê o convite para pedir acesso pelo WhatsApp, porque cada
/// conversa chama a API paga do Gemini.
class TelaConversas extends StatelessWidget {
  const TelaConversas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ajustes em toda aba: o tema e o tamanho do texto valem aqui também, e
      // Conversas era a única sem o botão.
      appBar: TabernaculoAppBar(
        title: const Text('Conversas'),
        actions: [
          TabernaculoBotaoDeAjustes(estado: EscopoDoEstado.de(context)),
        ],
      ),
      body: TabernaculoLarguraDeLeitura(
        // Recursos.conversas depende do e-mail logado (ver Nuvem): sem
        // ouvir a nuvem, entrar ou sair da conta com a aba aberta deixava o
        // conteúdo errado até trocar de aba e voltar.
        child: ListenableBuilder(
          listenable: Listenable.merge([
            Nuvem.instancia,
            ConfigAdmin.instancia,
          ]),
          builder: (context, _) => Recursos.conversas
              ? const TabernaculoCartasDeConversa()
              : const TabernaculoCartaoDePedirAcesso(
                  icone: FontAwesomeIcons.comments,
                  descricao:
                      'Por enquanto, as conversas com Spurgeon e com Felipe '
                      'estão abertas para alguns leitores. Peça o acesso pelo '
                      'WhatsApp para habilitar na sua conta.',
                  mensagemDoWhatsapp: 'Oi Felipe, quero habilitar as conversas',
                ),
        ),
      ),
    );
  }
}
