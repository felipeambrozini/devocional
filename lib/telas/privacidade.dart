import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../dados/contato.dart';
import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// Política de privacidade completa: a versão longa do resumo que já vive em
/// Sobre, com URL própria para quem chega por um link direto ou por exigência
/// de uma conta Google. Todo item aqui espelha o que o código de fato faz
/// (`lib/dados/nuvem.dart` e `lib/dados/conversas.dart`),
/// não uma promessa separada do comportamento real.
class TelaPrivacidade extends StatefulWidget {
  const TelaPrivacidade({super.key});

  @override
  State<TelaPrivacidade> createState() => _TelaPrivacidadeState();
}

class _TelaPrivacidadeState extends State<TelaPrivacidade> {
  final _semConta = GlobalKey();
  final _comConta = GlobalKey();
  final _baseLegal = GlobalKey();
  final _planos = GlobalKey();
  final _lembretes = GlobalKey();
  final _chat = GlobalKey();
  final _voz = GlobalKey();
  final _appGenuino = GlobalKey();
  final _ondeEQuanto = GlobalKey();
  final _apagar = GlobalKey();
  final _direitos = GlobalKey();
  final _menores = GlobalKey();
  final _contato = GlobalKey();

  // O aceite, o Sobre e o FAQ linkam esta página mirando perguntas ("posso
  // apagar meus dados?"): o índice leva direto à seção, sem rolagem às cegas.
  void _rolarAte(GlobalKey chave, String titulo) {
    final alvo = chave.currentContext;
    if (alvo == null) return;
    Scrollable.ensureVisible(
      alvo,
      duration: MediaQuery.disableAnimationsOf(alvo)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    // A rolagem não move o foco: sem o anúncio, quem usa leitor de tela fica
    // sem saber que a página andou.
    SemanticsService.sendAnnouncement(
      View.of(alvo),
      titulo,
      Directionality.of(alvo),
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
        // política para quem não pode usá-lo. Selecionável para o leitor
        // poder copiar o e-mail de contato.
        child: SelectionArea(
          child: ListenableBuilder(
            listenable: Nuvem.instancia,
            builder: (context, _) {
              final chat = Recursos.conversas;
              final indice = <String, GlobalKey>{
                'Sem conta': _semConta,
                'Com conta Google': _comConta,
                'Base legal e consentimento': _baseLegal,
                'Planos de leitura compartilhados': _planos,
                'Lembretes diários': _lembretes,
                if (chat) 'Chat com inteligência artificial': _chat,
                'Leitura em voz alta': _voz,
                'Verificação de app genuíno': _appGenuino,
                'Onde os dados ficam e por quanto tempo': _ondeEQuanto,
                'Apagar seus dados': _apagar,
                'Seus direitos': _direitos,
                'Menores de idade': _menores,
                'Contato': _contato,
              };
              // Coluna, não ListView: o índice rola até seções fora da
              // tela, e o ListView só monta as que estão perto dela.
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DevocionalEspacamento.sp20,
                  DevocionalEspacamento.sp16,
                  DevocionalEspacamento.sp20,
                  DevocionalEspacamento.sp40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Política de privacidade',
                        style: tema.displayMedium,
                      ),
                    ),
                    const SizedBox(height: DevocionalEspacamento.sp8),
                    const DevocionalFilete(largura: 64),
                    const SizedBox(height: DevocionalEspacamento.sp16),
                    Text(
                      'Este aplicativo não tem anúncio e não vende nem '
                      'compartilha dados com terceiros para fins de '
                      'publicidade. Também não tem coleta de erro nem de uso: '
                      'sem Sentry, sem Analytics. O que segue é a lista completa do '
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
                            onPressed: () =>
                                _rolarAte(entrada.value, entrada.key),
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
                                'histórico das conversas do chat com IA. O avatar '
                                'mostra a foto da conta Google, sem upload '
                                'próprio. Nunca '
                                'sobe o texto da Bíblia ou do devocional que '
                                'você lê, nem o horário em que lê. Quem não '
                                'entra com conta usa o aplicativo do mesmo '
                                'jeito, sem nada saindo do aparelho.'
                          : 'Entrar com a conta Google sobe, além do e-mail e '
                                'do identificador da conta, três coisas para a '
                                'nuvem do projeto (Firebase): favoritos, '
                                'anotações e dias de leitura marcados. O avatar '
                                'mostra a foto da conta Google, sem upload '
                                'próprio. Nunca '
                                'sobe o texto da Bíblia ou do devocional que '
                                'você lê, nem o horário em que lê. Quem não '
                                'entra com conta usa o aplicativo do mesmo '
                                'jeito, sem nada saindo do aparelho.',
                    ),
                    DevocionalSecaoDeTexto(
                      key: _baseLegal,
                      titulo: 'Base legal e consentimento',
                      texto:
                          'Favoritos, anotações, progresso e conversas dizem respeito'
                          ' à sua fé e, por isso, são dados pessoais sensíveis pela '
                          'Lei Geral de Proteção de Dados (LGPD). Eles só vão para a '
                          'nuvem com o seu consentimento, pedido em destaque antes do'
                          ' primeiro login neste aparelho (LGPD, art. 11, I). Você '
                          'pode retirar o consentimento quando quiser, apagando a '
                          'cópia da nuvem como descrito em Apagar seus dados.',
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
                    DevocionalSecaoDeTexto(
                      key: _lembretes,
                      titulo: 'Lembretes diários',
                      texto:
                          'Quem liga o lembrete diário guarda na nuvem um '
                          'identificador da instalação do aplicativo, os horários '
                          'escolhidos e o fuso horário do aparelho, sem ligação com a'
                          ' sua conta. Eles servem só para o Firebase Cloud '
                          'Messaging, do Google, entregar a notificação na hora '
                          'certa. Desligar o lembrete apaga esse registro.',
                    ),
                    if (chat)
                      DevocionalSecaoDeTexto(
                        key: _chat,
                        titulo: 'Chat com inteligência artificial',
                        texto:
                            'As mensagens enviadas às personas Charles Spurgeon e '
                            'Felipe Ambrozini são processadas pela API Gemini do '
                            'Google para gerar a resposta, e cada pergunta leva '
                            'junto as últimas falas da conversa. O app usa o plano '
                            'pago da API: segundo os termos do Google, nele o '
                            'conteúdo enviado não é usado para treinar nem '
                            'melhorar os produtos do Google, e fica registrado por '
                            'tempo limitado só para detectar abuso. Mesmo assim, '
                            'não escreva no chat informações que você não queira '
                            'compartilhar. O histórico de cada '
                            'conversa é salvo no aparelho e, para quem tem conta, '
                            'também na nuvem descrita acima.',
                      ),
                    DevocionalSecaoDeTexto(
                      key: _voz,
                      titulo: 'Leitura em voz alta',
                      texto:
                          'O áudio de cada capítulo, devocional e introdução é '
                          'gravado com antecedência e servido pronto: nenhum '
                          'texto é enviado a um serviço de voz na hora de tocar. '
                          'Quem baixa uma categoria para ouvir sem internet '
                          '(em Ajustes) guarda esses arquivos de áudio no próprio '
                          'aparelho, e pode apagá-los a qualquer momento na '
                          'mesma tela.',
                    ),
                    DevocionalSecaoDeTexto(
                      key: _appGenuino,
                      titulo: 'Verificação de app genuíno',
                      texto:
                          'O aplicativo usa o Firebase App Check para confirmar que '
                          'os pedidos à nuvem vêm de uma instalação genuína do '
                          'próprio aplicativo, e não de um script externo. Essa '
                          'verificação não identifica pessoas, só a instalação. '
                          'Na web, ela usa o reCAPTCHA v3 do Google, que analisa '
                          'sinais do navegador e pode gravar um cookie próprio; '
                          'esse uso segue a Política de Privacidade e os Termos '
                          'de Serviço do Google.',
                    ),
                    DevocionalSecaoDeTexto(
                      key: _ondeEQuanto,
                      titulo: 'Onde os dados ficam e por quanto tempo',
                      texto:
                          'Os dados da nuvem ficam no Firebase, serviço do Google que'
                          ' pode guardá-los em servidores fora do Brasil, sob os '
                          'termos de proteção de dados que o Google oferece a quem '
                          'usa o serviço (LGPD, art. 33). Eles ficam guardados '
                          'enquanto a conta existir no aplicativo e saem quando você '
                          'apaga a cópia da nuvem. Ninguém além de você tem acesso a '
                          'eles, a não ser o progresso que você mesmo compartilha num'
                          ' plano.',
                    ),
                    DevocionalSecaoDeTexto(
                      key: _apagar,
                      titulo: 'Apagar seus dados',
                      texto: chat
                          ? 'Quem tem conta pode apagar a cópia salva na nuvem em '
                                'Sobre, na seção Conta e privacidade: o botão remove '
                                'favoritos, anotações, progresso e conversas sincronizados, '
                                'a participação em planos '
                                'compartilhados e a própria conta, sem tocar no que está '
                                'no aparelho ou navegador. Para apagar o que ficou só '
                                'localmente, basta limpar os dados do aplicativo ou do '
                                'site pelo próprio sistema ou navegador.'
                          : 'Quem tem conta pode apagar a cópia salva na nuvem em '
                                'Sobre, na seção Conta e privacidade: o botão remove '
                                'favoritos, anotações e progresso sincronizados, '
                                'a participação em planos compartilhados e a '
                                'própria conta, sem tocar no que está no aparelho ou '
                                'navegador. Para apagar o que ficou só localmente, basta '
                                'limpar os dados do aplicativo ou do site pelo próprio '
                                'sistema ou navegador.',
                    ),
                    DevocionalSecaoDeTexto(
                      key: _direitos,
                      titulo: 'Seus direitos',
                      texto:
                          'Pela LGPD (art. 18), você pode pedir a confirmação de que '
                          'seus dados são tratados, o acesso a eles, a correção, a '
                          'portabilidade, a eliminação, a informação sobre com quem '
                          'são compartilhados e a revogação do consentimento. Boa '
                          'parte disso você faz sozinho no aplicativo: exportar a '
                          'cópia de segurança e apagar a cópia da nuvem. O resto, '
                          'peça pelo contato abaixo. Você também pode reclamar à '
                          'Autoridade Nacional de Proteção de Dados (ANPD).',
                    ),
                    DevocionalSecaoDeTexto(
                      key: _menores,
                      titulo: 'Menores de idade',
                      texto:
                          'O aplicativo não é dirigido a crianças. Menores de 18 anos'
                          ' devem usá-lo com o acompanhamento dos pais ou '
                          'responsáveis, e o chat com inteligência artificial é só '
                          'para maiores de 18 anos.',
                    ),
                    DevocionalSecaoDeTexto(
                      key: _contato,
                      titulo: 'Contato',
                      texto: emailDeContato.isEmpty
                          ? 'O responsável pelos dados descritos aqui é Felipe '
                                'Ambrozini, que mantém o aplicativo. Dúvidas sobre '
                                'esta política podem ser enviadas pelos canais '
                                'listados em Sobre.'
                          : 'O responsável pelos dados descritos aqui é Felipe '
                                'Ambrozini, que mantém o aplicativo. Para dúvidas '
                                'sobre esta política ou para pedir acesso, correção '
                                'ou exclusão dos seus dados, escreva para '
                                '$emailDeContato.',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
