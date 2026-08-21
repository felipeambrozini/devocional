import 'package:flutter/material.dart';

import '../spacing.dart';
import 'comuns.dart';

/// Política de privacidade completa: a versão longa do resumo que já vive em
/// Sobre, com URL própria para quem chega por um link direto ou por exigência
/// de uma conta Google. Todo item aqui espelha o que o código de fato faz
/// (`lib/data/nuvem.dart` e `lib/data/conversas.dart`), não uma promessa
/// separada do comportamento real.
class TelaPrivacidade extends StatelessWidget {
  const TelaPrivacidade({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Política de privacidade')),
      body: LarguraDeLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.sp20, Spacing.sp16, Spacing.sp20, Spacing.sp40),
          children: [
            Text('Política de privacidade', style: tema.displayMedium),
            const SizedBox(height: Spacing.sp8),
            const Filete(largura: 64),
            const SizedBox(height: Spacing.sp16),
            Text(
              'Este aplicativo não tem anúncio, não usa ferramenta de '
              'análise de uso e não vende nem compartilha dados com '
              'terceiros para fins de publicidade. O que segue é a lista '
              'completa do que é guardado, onde e por quê.',
              style: tema.bodyLarge?.copyWith(height: 1.7),
            ),
            const _Secao(
              titulo: 'Sem conta',
              texto:
                  'Favoritos, anotações, progresso de leitura, tema e '
                  'tamanho do texto ficam só no aparelho ou no navegador '
                  '(armazenamento local). Nada disso sai daqui.',
            ),
            const _Secao(
              titulo: 'Com conta Google',
              texto:
                  'Entrar com a conta Google sobe, além do e-mail e do '
                  'identificador da conta, quatro coisas para a nuvem do '
                  'projeto (Firebase): favoritos, anotações, dias de '
                  'leitura marcados e o histórico das conversas do chat com '
                  'IA. A foto de perfil, quando trocada pela câmera ou pela '
                  'galeria, fica hospedada na mesma nuvem. Nunca sobe o '
                  'texto da Bíblia ou do devocional que você lê, nem o '
                  'horário em que lê. Quem não entra com conta usa o '
                  'aplicativo do mesmo jeito, sem nada saindo do aparelho.',
            ),
            const _Secao(
              titulo: 'Planos de leitura compartilhados',
              texto:
                  'Um plano criado para ser compartilhado por link mostra o '
                  'progresso de cada participante aos demais participantes '
                  'do mesmo plano. Participar de um plano exige conta '
                  'Google. Quem criou o plano pode excluí-lo para todos; '
                  'quem só participa pode sair dele, afetando apenas o '
                  'próprio progresso.',
            ),
            const _Secao(
              titulo: 'Chat com inteligência artificial',
              texto:
                  'As mensagens enviadas às personas Charles Spurgeon e '
                  'Felipe Ambrozini são processadas pela API Gemini do '
                  'Google para gerar a resposta. O histórico de cada '
                  'conversa é salvo no aparelho e, para quem tem conta, '
                  'também na nuvem descrita acima.',
            ),
            const _Secao(
              titulo: 'Leitura em voz alta',
              texto:
                  'O texto do capítulo ou devocional pedido em voz é '
                  'enviado ao serviço de síntese de voz da nuvem do Google '
                  'para gerar o áudio reproduzido na hora. O áudio não fica '
                  'guardado depois de tocado.',
            ),
            const _Secao(
              titulo: 'Verificação de app genuíno',
              texto:
                  'O aplicativo usa o Firebase App Check para confirmar que '
                  'os pedidos à nuvem vêm de uma instalação genuína do '
                  'próprio aplicativo, e não de um script externo. Essa '
                  'verificação não identifica pessoas, só a instalação.',
            ),
            const _Secao(
              titulo: 'Apagar seus dados',
              texto:
                  'Quem tem conta pode apagar a cópia salva na nuvem em '
                  'Sobre, na seção Conta e privacidade: o botão remove '
                  'favoritos, anotações, progresso e conversas sincronizados '
                  'e a própria conta, sem tocar no que está no aparelho ou '
                  'navegador. Para apagar o que ficou só localmente, basta '
                  'limpar os dados do aplicativo ou do site pelo próprio '
                  'sistema ou navegador.',
            ),
            const _Secao(
              titulo: 'Contato',
              texto:
                  'Dúvidas sobre esta política podem ser enviadas pelos '
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
