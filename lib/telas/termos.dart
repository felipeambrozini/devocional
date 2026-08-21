import 'package:flutter/material.dart';

import '../spacing.dart';
import 'comuns.dart';

/// Termos de serviço: URL própria exigida por integrações que pedem um link
/// de termos (ex.: tela de consentimento OAuth do Google), com o mesmo
/// tratamento visual de [privacidade.dart].
class TelaTermos extends StatelessWidget {
  const TelaTermos({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de serviço')),
      body: LarguraDeLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sp20,
            Spacing.sp16,
            Spacing.sp20,
            Spacing.sp40,
          ),
          children: [
            Text('Termos de serviço', style: tema.displayMedium),
            const SizedBox(height: Spacing.sp8),
            const Filete(largura: 64),
            const SizedBox(height: Spacing.sp16),
            Text(
              'Ao usar este aplicativo você concorda com o que segue. Ele é '
              'gratuito, sem anúncio e mantido por uma única pessoa como '
              'projeto pessoal.',
              style: tema.bodyLarge?.copyWith(height: 1.7),
            ),
            const _Secao(
              titulo: 'O serviço',
              texto:
                  'O aplicativo oferece Bíblia, devocionais, plano de '
                  'leitura, notas, busca, leitura em voz alta e conversas '
                  'com personas de inteligência artificial. Não há garantia '
                  'de disponibilidade contínua nem de ausência de erros; o '
                  'conteúdo pode mudar ou ser descontinuado a qualquer '
                  'momento, sem aviso prévio.',
            ),
            const _Secao(
              titulo: 'Conta e conteúdo do usuário',
              texto:
                  'Entrar com conta Google é opcional e serve para '
                  'sincronizar favoritos, anotações, progresso de leitura e '
                  'conversas na nuvem. Você é responsável pelo conteúdo que '
                  'escreve em anotações e conversas. Planos de leitura '
                  'compartilhados expõem o progresso a quem participa do '
                  'mesmo plano.',
            ),
            const _Secao(
              titulo: 'Uso aceitável',
              texto:
                  'O aplicativo não deve ser usado para fins ilegais, para '
                  'tentar comprometer sua segurança ou a de terceiros, nem '
                  'para automatizar acesso em volume que sobrecarregue a '
                  'infraestrutura do serviço.',
            ),
            const _Secao(
              titulo: 'Isenção de responsabilidade',
              texto:
                  'O conteúdo é fornecido "como está". O criador não se '
                  'responsabiliza por decisões tomadas com base no que está '
                  'no aplicativo, nem por perdas decorrentes de '
                  'indisponibilidade do serviço.',
            ),
            const _Secao(
              titulo: 'Encerramento',
              texto:
                  'Você pode parar de usar o aplicativo e apagar sua conta a '
                  'qualquer momento, como descrito na política de '
                  'privacidade. O criador pode encerrar o serviço ou '
                  'contas que violem estes termos.',
            ),
            const _Secao(
              titulo: 'Alterações',
              texto:
                  'Estes termos podem ser atualizados; o uso continuado do '
                  'aplicativo após uma mudança implica aceitação da nova '
                  'versão.',
            ),
            const _Secao(
              titulo: 'Contato',
              texto:
                  'Dúvidas sobre estes termos podem ser enviadas pelos '
                  'canais listados em Sobre, YouTube e Instagram.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sp32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.headlineSmall),
          const SizedBox(height: Spacing.sp10),
          Text(texto, style: tema.bodyLarge?.copyWith(height: 1.7)),
        ],
      ),
    );
  }
}
