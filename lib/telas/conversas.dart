import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../widgets/widgets.dart';

/// A aba Conversas: a porta de entrada do chat no celular e no computador.
///
/// A aba fica visível para todo mundo — só o conteúdo muda com
/// [Recursos.conversas]: quem está na allowlist vê a carta de cada persona
/// (o mesmo caminho que os balões das telas largas empurram, ver `_ComBaloes`
/// em `main.dart`); quem não está vê o convite para pedir acesso pelo
/// WhatsApp, porque cada conversa chama a API paga do Gemini.
class TelaConversas extends StatelessWidget {
  const TelaConversas({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DevocionalAppBar(title: const Text('Conversas')),
      body: DevocionalLarguraDeLeitura(
        // Recursos.conversas depende do e-mail logado (ver Nuvem): sem
        // ouvir a nuvem, entrar ou sair da conta com a aba aberta deixava o
        // conteúdo errado até trocar de aba e voltar.
        child: ListenableBuilder(
          listenable: Nuvem.instancia,
          builder: (context, _) => Recursos.conversas
              ? const DevocionalCartasDeConversa()
              : const DevocionalCartaoDePedirAcesso(
                  icone: FontAwesomeIcons.comments,
                  descricao:
                      'O chat com Spurgeon e com Felipe é um recurso '
                      'premium. Fale comigo pelo WhatsApp para habilitar '
                      'o acesso na sua conta.',
                  mensagemDoWhatsapp: 'Oi Felipe, quero habilitar as conversas',
                ),
        ),
      ),
    );
  }
}
