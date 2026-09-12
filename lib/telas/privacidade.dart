import 'package:flutter/material.dart';

import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// Política de privacidade completa: a versão longa do resumo que já vive em
/// Sobre, com URL própria para quem chega por um link direto ou por exigência
/// de uma conta Google. Todo item aqui espelha o que o código de fato faz
/// (`lib/dados/nuvem.dart`, `lib/dados/conversas.dart` e `lib/dados/coleta.dart`),
/// não uma promessa separada do comportamento real.
class TelaPrivacidade extends StatefulWidget {
  const TelaPrivacidade({super.key});

  @override
  State<TelaPrivacidade> createState() => _TelaPrivacidadeState();
}

class _TelaPrivacidadeState extends State<TelaPrivacidade> {
  final _semConta = GlobalKey();
  final _comConta = GlobalKey();
  final _planos = GlobalKey();
  final _chat = GlobalKey();
  final _voz = GlobalKey();
  final _usoAnonimo = GlobalKey();
  final _appGenuino = GlobalKey();
  final _apagar = GlobalKey();
  final _contato = GlobalKey();

  // O aceite, o Sobre e o FAQ linkam esta página mirando perguntas ("posso
  // apagar meus dados?"): o índice leva direto à seção, sem rolagem às cegas.
  void _rolarAte(GlobalKey chave) {
    final alvo = chave.currentContext;
    if (alvo == null) return;
    Scrollable.ensureVisible(
      alvo,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: DevocionalAppBar(title: const Text('Política de privacidade')),
      body: DevocionalLarguraDeLeitura(
        // O chat só existe para quem tem acesso à função (ver
        // Recursos.conversas); as seções que falam dele ficam de fora da
        // política para quem não pode usá-lo.
        child: ListenableBuilder(
          listenable: Nuvem.instancia,
          builder: (context, _) {
            final chat = Recursos.conversas;
            final indice = <String, GlobalKey>{
              'Sem conta': _semConta,
              'Com conta Google': _comConta,
              'Planos de leitura compartilhados': _planos,
              if (chat) 'Chat com inteligência artificial': _chat,
              'Leitura em voz alta': _voz,
              'Uso anônimo e erro técnico': _usoAnonimo,
              'Verificação de app genuíno': _appGenuino,
              'Apagar seus dados': _apagar,
              'Contato': _contato,
            };
            return ListView(
              padding: const EdgeInsets.fromLTRB(DevocionalEspacamento.sp20, DevocionalEspacamento.sp16, DevocionalEspacamento.sp20, DevocionalEspacamento.sp40),
              children: [
                Text('Política de privacidade', style: tema.displayMedium),
                const SizedBox(height: DevocionalEspacamento.sp8),
                const DevocionalFilete(largura: 64),
                const SizedBox(height: DevocionalEspacamento.sp16),
                Text(
                  'Este aplicativo não tem anúncio e não vende nem '
                  'compartilha dados com terceiros para fins de '
                  'publicidade. Com sua permissão, ele pode enviar erro '
                  'técnico e uso anônimo por tela — ver "Uso anônimo e '
                  'erro técnico" abaixo. O que segue é a lista completa do '
                  'que é guardado, onde e por quê.',
                  style: tema.bodyLarge?.copyWith(height: 1.7),
                ),
                const SizedBox(height: DevocionalEspacamento.sp16),
                Text(
                  'Nesta página',
                  style: tema.labelLarge?.copyWith(color: cor.secondary),
                ),
                const SizedBox(height: DevocionalEspacamento.sp4),
                Wrap(
                  spacing: DevocionalEspacamento.sp4,
                  children: [
                    for (final entrada in indice.entries)
                      DevocionalBotaoTerciario(
                        onPressed: () => _rolarAte(entrada.value),
                        child: Text(entrada.key),
                      ),
                  ],
                ),
                DevocionalSecaoDeTexto(
                  key: _semConta,
                  titulo: 'Sem conta',
                  texto:
                      'Favoritos, anotações, progresso de leitura, tema e '
                      'tamanho do texto ficam só no aparelho ou no navegador '
                      '(armazenamento local). Nada disso sai daqui.',
                ),
                DevocionalSecaoDeTexto(
                  key: _comConta,
                  titulo: 'Com conta Google',
                  texto: chat
                      ? 'Entrar com a conta Google sobe, além do e-mail e '
                            'do identificador da conta, quatro coisas para '
                            'a nuvem do projeto (Firebase): favoritos, '
                            'anotações, dias de leitura marcados e o '
                            'histórico das conversas do chat com IA. A foto '
                            'de perfil, quando trocada pela câmera ou pela '
                            'galeria, fica hospedada na mesma nuvem. Nunca '
                            'sobe o texto da Bíblia ou do devocional que '
                            'você lê, nem o horário em que lê. Quem não '
                            'entra com conta usa o aplicativo do mesmo '
                            'jeito, sem nada saindo do aparelho.'
                      : 'Entrar com a conta Google sobe, além do e-mail e '
                            'do identificador da conta, três coisas para a '
                            'nuvem do projeto (Firebase): favoritos, '
                            'anotações e dias de leitura marcados. A foto '
                            'de perfil, quando trocada pela câmera ou pela '
                            'galeria, fica hospedada na mesma nuvem. Nunca '
                            'sobe o texto da Bíblia ou do devocional que '
                            'você lê, nem o horário em que lê. Quem não '
                            'entra com conta usa o aplicativo do mesmo '
                            'jeito, sem nada saindo do aparelho.',
                ),
                DevocionalSecaoDeTexto(
                  key: _planos,
                  titulo: 'Planos de leitura compartilhados',
                  texto:
                      'Um plano criado para ser compartilhado por link mostra o '
                      'progresso de cada participante aos demais participantes '
                      'do mesmo plano. Participar de um plano exige conta '
                      'Google. Quem criou o plano pode excluí-lo para todos; '
                      'quem só participa pode sair dele, afetando apenas o '
                      'próprio progresso.',
                ),
                if (chat)
                  DevocionalSecaoDeTexto(
                    key: _chat,
                    titulo: 'Chat com inteligência artificial',
                    texto:
                        'As mensagens enviadas às personas Charles Spurgeon e '
                        'Felipe Ambrozini são processadas pela API Gemini do '
                        'Google para gerar a resposta. O histórico de cada '
                        'conversa é salvo no aparelho e, para quem tem conta, '
                        'também na nuvem descrita acima.',
                  ),
                DevocionalSecaoDeTexto(
                  key: _voz,
                  titulo: 'Leitura em voz alta',
                  texto:
                      'O áudio de cada capítulo, devocional e introdução é '
                      'gravado com antecedência e servido pronto — nenhum '
                      'texto é enviado a um serviço de voz na hora de tocar. '
                      'Quem baixa uma categoria para ouvir sem internet '
                      '(em Ajustes) guarda esses arquivos de áudio no próprio '
                      'aparelho, e pode apagá-los a qualquer momento na '
                      'mesma tela.',
                ),
                DevocionalSecaoDeTexto(
                  key: _usoAnonimo,
                  titulo: 'Uso anônimo e erro técnico',
                  texto:
                      'Na primeira vez que abre o app, você escolhe se '
                      'autoriza o envio de dois tipos de informação sem '
                      'identificar você: erros técnicos (com o Sentry), '
                      'para achar e corrigir falhas, e uso anônimo por tela '
                      '(com o Google Analytics), para saber onde as pessoas '
                      'travam ou desistem. As duas ficam desligadas até '
                      'você responder, e nenhuma delas manda o texto que '
                      'você lê ou escreve. Dá para mudar de ideia depois '
                      'em Sobre.',
                ),
                DevocionalSecaoDeTexto(
                  key: _appGenuino,
                  titulo: 'Verificação de app genuíno',
                  texto:
                      'O aplicativo usa o Firebase App Check para confirmar que '
                      'os pedidos à nuvem vêm de uma instalação genuína do '
                      'próprio aplicativo, e não de um script externo. Essa '
                      'verificação não identifica pessoas, só a instalação.',
                ),
                DevocionalSecaoDeTexto(
                  key: _apagar,
                  titulo: 'Apagar seus dados',
                  texto: chat
                      ? 'Quem tem conta pode apagar a cópia salva na nuvem em '
                            'Sobre, na seção Conta e privacidade: o botão remove '
                            'favoritos, anotações, progresso e conversas sincronizados, '
                            'a foto de perfil, a participação em planos '
                            'compartilhados e a própria conta, sem tocar no que está '
                            'no aparelho ou navegador. Para apagar o que ficou só '
                            'localmente, basta limpar os dados do aplicativo ou do '
                            'site pelo próprio sistema ou navegador.'
                      : 'Quem tem conta pode apagar a cópia salva na nuvem em '
                            'Sobre, na seção Conta e privacidade: o botão remove '
                            'favoritos, anotações e progresso sincronizados, a foto '
                            'de perfil, a participação em planos compartilhados e a '
                            'própria conta, sem tocar no que está no aparelho ou '
                            'navegador. Para apagar o que ficou só localmente, basta '
                            'limpar os dados do aplicativo ou do site pelo próprio '
                            'sistema ou navegador.',
                ),
                DevocionalSecaoDeTexto(
                  key: _contato,
                  titulo: 'Contato',
                  texto:
                      'Dúvidas sobre esta política podem ser enviadas pelos '
                      'canais listados em Sobre — YouTube, Instagram e, '
                      'quando disponível, "Relatar um problema".',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
