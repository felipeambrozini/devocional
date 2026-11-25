import 'package:material_ui/material_ui.dart';

import '../estilo/espacamento.dart';
import 'botao.dart';
import 'filete.dart';

/// Portão de idade do chat: a primeira visita pede uma declaração explícita
/// de que a pessoa tem 18 anos ou mais.
///
/// O chat responde por inteligência artificial e pode tratar de ansiedade,
/// culpa e fé — assuntos que a política de uso responsável manda destacar. A
/// resposta fica guardada por aparelho em `Estado.maiorDeIdade`, para o aviso
/// não reaparecer a cada conversa; quem responde "Não tenho" continua vendo o
/// portão e não chega ao campo de mensagem.
///
/// O portão não prova idade (nada no navegador prova): ele garante que a
/// declaração foi lida e feita, que é o que cabe ao app.
class TabernaculoPortaoDeIdade extends StatelessWidget {
  const TabernaculoPortaoDeIdade({
    super.key,
    required this.aoConfirmar,
    required this.aoRecusar,
  });

  final VoidCallback aoConfirmar;
  final VoidCallback aoRecusar;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TabernaculoEspacamento.sp32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: TabernaculoFilete(largura: 64)),
              const SizedBox(height: TabernaculoEspacamento.sp18),
              Text(
                'Antes de conversar',
                style: tema.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TabernaculoEspacamento.sp12),
              Text(
                'As respostas são geradas por inteligência artificial a partir '
                'do que você escrever. Elas podem tratar de temas sensíveis, '
                'como ansiedade, culpa e fé, e não substituem acompanhamento '
                'médico, psicológico ou pastoral.',
                textAlign: TextAlign.center,
                style: tema.bodyLarge?.copyWith(
                  color: cor.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: TabernaculoEspacamento.sp12),
              Text(
                'O chat é destinado a maiores de 18 anos. Confirme para '
                'continuar.',
                textAlign: TextAlign.center,
                style: tema.bodyMedium?.copyWith(
                  color: cor.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: TabernaculoEspacamento.sp24),
              TabernaculoBotaoPrimario(
                onPressed: aoConfirmar,
                child: const Text('Tenho 18 anos ou mais'),
              ),
              const SizedBox(height: TabernaculoEspacamento.sp8),
              TabernaculoBotaoTerciario(
                onPressed: aoRecusar,
                child: const Text('Não tenho 18 anos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
