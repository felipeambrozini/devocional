import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/nuvem.dart';
import '../data/recursos.dart';
import '../estilo/spacing.dart';
import '../widgets/widgets.dart';

/// Perguntas frequentes: dúvidas reais de quem ainda decide se fica, não um
/// roteiro de vendas. Nada aqui é exclusivo desta tela, é o que já está
/// espalhado em Sobre e no código, reunido num só lugar com URL própria.
class TelaFAQ extends StatelessWidget {
  const TelaFAQ({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Perguntas frequentes')),
      body: LarguraDeLeitura(
        // O chat só existe para quem tem acesso à função (ver
        // Recursos.conversas); as perguntas sobre ele não fazem sentido
        // para quem não pode usá-lo.
        child: ListenableBuilder(
          listenable: Nuvem.instancia,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.sp20, Spacing.sp16, Spacing.sp20, Spacing.sp40),
            children: [
              Text('Perguntas frequentes', style: tema.displayMedium),
              const SizedBox(height: Spacing.sp8),
              const Filete(largura: 64),
              const SizedBox(height: Spacing.sp16),
              for (final pergunta in _perguntas(Recursos.conversas)) _Pergunta(pergunta),
              const SizedBox(height: Spacing.sp16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.primary),
                title: const Text('Política de privacidade completa'),
                subtitle: const Text('O que é guardado, onde e por quê.'),
                onTap: () => context.push('/privacidade'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pergunta extends StatelessWidget {
  const _Pergunta(this.item);

  final (String, String) item;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(item.$1, style: tema.titleMedium),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sp12),
          child: Text(item.$2, style: tema.bodyLarge?.copyWith(height: 1.7)),
        ),
      ],
    );
  }
}

/// [chat] é [Recursos.conversas]: só quem tem acesso à função vê as
/// perguntas que falam dela.
List<(String, String)> _perguntas(bool chat) => [
  (
    'O aplicativo é gratuito?',
    chat
        ? 'Sim, por completo. A Bíblia, os dois devocionais de Spurgeon, o '
              'cronograma de leitura, a leitura em voz alta e o chat com '
              'IA não têm custo nem anúncio.'
        : 'Sim, por completo. A Bíblia, os dois devocionais de Spurgeon, o '
              'cronograma de leitura e a leitura em voz alta não têm '
              'custo nem anúncio.',
  ),
  (
    'Por que essa tradução da Bíblia?',
    'O texto é uma tradução autoral e inédita da King James 1611, feita '
        'diretamente do inglês em domínio público, com a mesma contagem de '
        'versículos do canon: 31.102. Nenhum outro aplicativo tem este '
        'texto, porque ele nasceu aqui.',
  ),
  (
    'Funciona sem internet?',
    chat
        ? 'A leitura da Bíblia e dos devocionais funciona sem internet, '
              'porque o texto vem de arquivos dentro do próprio '
              'aplicativo. A leitura em voz alta, o chat com IA e a '
              'sincronização da conta na nuvem precisam de conexão.'
        : 'A leitura da Bíblia e dos devocionais funciona sem internet, '
              'porque o texto vem de arquivos dentro do próprio '
              'aplicativo. A leitura em voz alta e a sincronização da '
              'conta na nuvem precisam de conexão.',
  ),
  (
    'Preciso de uma conta para usar?',
    'Não. O aplicativo funciona por completo sem conta. Entrar com a conta '
        'Google só é necessário para guardar uma cópia de segurança na '
        'nuvem ou para participar de um plano de leitura compartilhado.',
  ),
  (
    'O aplicativo tem anúncio ou rastreia meu uso?',
    'Não. Não há anúncio, não há ferramenta de análise de uso e nenhum '
        'dado é vendido ou compartilhado com terceiros para fins de '
        'publicidade. Os detalhes completos estão na política de '
        'privacidade.',
  ),
  (
    'Em quais aparelhos o aplicativo funciona?',
    'No Android e em qualquer navegador, com a mesma experiência e o '
        'mesmo design nas duas plataformas.',
  ),
  if (chat)
    (
      'Como funciona o chat com inteligência artificial?',
      'São duas personas: Charles Spurgeon e Felipe Ambrozini, o criador do '
          'aplicativo. As respostas são geradas por inteligência artificial, '
          'e o histórico de cada conversa fica salvo para quem quiser '
          'retomá-la depois.',
    ),
  (
    'Posso apagar meus dados?',
    'Sim. Quem tem conta pode apagar a cópia salva na nuvem na tela Sobre, '
        'em Conta e privacidade. O que fica só no aparelho ou navegador '
        'pode ser apagado limpando os dados do aplicativo ou do site.',
  ),
];
