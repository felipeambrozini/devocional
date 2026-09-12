import 'package:flutter/material.dart';

import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../estilo/espacamento.dart';
import '../widgets/widgets.dart';

/// Termos de serviço: URL própria exigida por integrações que pedem um link
/// de termos (ex.: tela de consentimento OAuth do Google), com o mesmo
/// tratamento visual de [privacidade.dart].
class TelaTermos extends StatefulWidget {
  const TelaTermos({super.key});

  @override
  State<TelaTermos> createState() => _TelaTermosState();
}

class _TelaTermosState extends State<TelaTermos> {
  final _servico = GlobalKey();
  final _conta = GlobalKey();
  final _uso = GlobalKey();
  final _isencao = GlobalKey();
  final _encerramento = GlobalKey();
  final _alteracoes = GlobalKey();
  final _contato = GlobalKey();

  // Mesma razão do índice da privacidade: chegar direto à seção que motivou
  // a visita, sem rolagem às cegas.
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
      appBar: DevocionalAppBar(title: const Text('Termos de serviço')),
      body: DevocionalLarguraDeLeitura(
        // O chat só existe para quem tem acesso à função (ver
        // Recursos.conversas); os termos não citam o que essa conta não
        // consegue usar.
        child: ListenableBuilder(
          listenable: Nuvem.instancia,
          builder: (context, _) {
            final chat = Recursos.conversas;
            const indice = <String>[
              'O serviço',
              'Conta e conteúdo do usuário',
              'Uso aceitável',
              'Isenção de responsabilidade',
              'Encerramento',
              'Alterações',
              'Contato',
            ];
            final chaves = <String, GlobalKey>{
              'O serviço': _servico,
              'Conta e conteúdo do usuário': _conta,
              'Uso aceitável': _uso,
              'Isenção de responsabilidade': _isencao,
              'Encerramento': _encerramento,
              'Alterações': _alteracoes,
              'Contato': _contato,
            };
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                DevocionalEspacamento.sp20,
                DevocionalEspacamento.sp16,
                DevocionalEspacamento.sp20,
                DevocionalEspacamento.sp40,
              ),
              children: [
                Text('Termos de serviço', style: tema.displayMedium),
                const SizedBox(height: DevocionalEspacamento.sp8),
                const DevocionalFilete(largura: 64),
                const SizedBox(height: DevocionalEspacamento.sp16),
                Text(
                  'Ao usar este aplicativo você concorda com o que segue. Ele é '
                  'gratuito, sem anúncio e mantido por uma única pessoa como '
                  'projeto pessoal.',
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
                    for (final titulo in indice)
                      DevocionalBotaoTerciario(
                        onPressed: () => _rolarAte(chaves[titulo]!),
                        child: Text(titulo),
                      ),
                  ],
                ),
                DevocionalSecaoDeTexto(
                  key: _servico,
                  titulo: 'O serviço',
                  texto: chat
                      ? 'O aplicativo oferece Bíblia, devocionais, plano de '
                            'leitura, notas, busca, leitura em voz alta e '
                            'conversas com personas de inteligência '
                            'artificial. Como todo projeto mantido por uma '
                            'pessoa só, o serviço pode falhar ou ficar fora '
                            'do ar de vez em quando, e o conteúdo pode '
                            'mudar ou ser descontinuado a qualquer momento, '
                            'sem aviso prévio.'
                      : 'O aplicativo oferece Bíblia, devocionais, plano de '
                            'leitura, notas, busca e leitura em voz alta. '
                            'Como todo projeto mantido por uma pessoa só, o '
                            'serviço pode falhar ou ficar fora do ar de vez '
                            'em quando, e o conteúdo pode mudar ou ser '
                            'descontinuado a qualquer momento, sem aviso '
                            'prévio.',
                ),
                DevocionalSecaoDeTexto(
                  key: _conta,
                  titulo: 'Conta e conteúdo do usuário',
                  texto: chat
                      ? 'Entrar com conta Google é opcional e serve para '
                            'sincronizar favoritos, anotações, progresso de '
                            'leitura e conversas na nuvem. Você é '
                            'responsável pelo conteúdo que escreve em '
                            'anotações e conversas. Planos de leitura '
                            'compartilhados expõem o progresso a quem '
                            'participa do mesmo plano.'
                      : 'Entrar com conta Google é opcional e serve para '
                            'sincronizar favoritos, anotações e progresso '
                            'de leitura na nuvem. Você é responsável pelo '
                            'conteúdo que escreve em anotações. Planos de '
                            'leitura compartilhados expõem o progresso a '
                            'quem participa do mesmo plano.',
                ),
                DevocionalSecaoDeTexto(
                  key: _uso,
                  titulo: 'Uso aceitável',
                  texto:
                      'O aplicativo não deve ser usado para fins ilegais, para '
                      'tentar comprometer sua segurança ou a de terceiros, nem '
                      'para automatizar acesso em volume que sobrecarregue a '
                      'infraestrutura do serviço.',
                ),
                DevocionalSecaoDeTexto(
                  key: _isencao,
                  titulo: 'Isenção de responsabilidade',
                  texto:
                      'O conteúdo é fornecido "como está". O criador não se '
                      'responsabiliza por decisões tomadas com base no que está '
                      'no aplicativo, nem por perdas decorrentes de '
                      'indisponibilidade do serviço.',
                ),
                DevocionalSecaoDeTexto(
                  key: _encerramento,
                  titulo: 'Encerramento',
                  texto:
                      'Você pode parar de usar o aplicativo e apagar sua conta a '
                      'qualquer momento, como descrito na política de '
                      'privacidade. O criador pode encerrar o serviço ou '
                      'contas que violem estes termos.',
                ),
                DevocionalSecaoDeTexto(
                  key: _alteracoes,
                  titulo: 'Alterações',
                  texto:
                      'Estes termos podem ser atualizados; o uso continuado do '
                      'aplicativo após uma mudança implica aceitação da nova '
                      'versão.',
                ),
                DevocionalSecaoDeTexto(
                  key: _contato,
                  titulo: 'Contato',
                  texto:
                      'Dúvidas sobre estes termos podem ser enviadas pelos '
                      'canais listados em Sobre, YouTube e Instagram.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
