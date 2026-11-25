import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/estado.dart';
import '../dados/instalacao.dart';
import '../estilo/espacamento.dart';
import 'botao.dart';
import 'cartao.dart';
import 'item_de_instalar.dart';

/// Convite para instalar a versão web como app, na Hoje. Só na web, só fora
/// do app instalado e só até "Agora não" (ver
/// `Estado.conviteDeInstalarDispensado`); quem dispensou ainda acha o item
/// fixo em Sobre. Quem chama decide a vez dele: a Hoje só o mostra depois que
/// o cartão "Como usar" foi dispensado, para dois cartões de boas-vindas não
/// se empilharem antes da leitura.
class TabernaculoCartaoDeInstalar extends StatelessWidget {
  const TabernaculoCartaoDeInstalar({
    super.key,
    required this.estado,
    this.instalacao,
  });

  final Estado estado;

  /// Nulo usa [InstalacaoDoApp.instancia]; os testes passam uma falsa.
  final InstalacaoDoApp? instalacao;

  @override
  Widget build(BuildContext context) {
    final instalacao = this.instalacao ?? InstalacaoDoApp.instancia;
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: instalacao,
      builder: (context, _) {
        if (!instalacao.disponivel || estado.conviteDeInstalarDispensado) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: TabernaculoEspacamento.sp16),
          child: TabernaculoCartao(
            titulo: 'Instalar como app',
            acessorio: FaIcon(
              FontAwesomeIcons.mobileScreen,
              color: cor.primary,
              size: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O Tabernáculo ganha ícone como os outros apps e abre em '
                  'janela própria, sem passar por loja. Se preferir depois, '
                  'a opção fica em Sobre.',
                  style: tema.bodyMedium,
                ),
                const SizedBox(height: TabernaculoEspacamento.sp8),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: TabernaculoEspacamento.sp8,
                  runSpacing: TabernaculoEspacamento.sp8,
                  children: [
                    Semantics(
                      hint: 'Esconde este convite; a opção continua em Sobre',
                      child: TabernaculoBotaoTerciario(
                        onPressed: () {
                          // O botão some junto com o cartão: o foco do
                          // teclado segue para a leitura do dia em vez de
                          // voltar ao começo da tela.
                          FocusScope.of(context).nextFocus();
                          estado.dispensarConviteDeInstalar();
                        },
                        child: const Text('Agora não'),
                      ),
                    ),
                    Semantics(
                      hint: 'Instala o Tabernáculo como app',
                      child: TabernaculoBotaoSecundario(
                        onPressed: () => instalarComoApp(context, instalacao),
                        child: const Text('Instalar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
