import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/estado.dart';
import '../data/modelos.dart';
import '../data/personas.dart';
import '../spacing.dart';
import 'comuns.dart';

/// O histórico de conversas com uma persona: a lista de todas as conversas,
/// da mais recente à mais antiga, com o título (a primeira pergunta) e a data
/// da última fala.
///
/// É o que o balão do chat abre (ver `_ComBaloes` em `main.dart`), e de onde
/// se começa uma conversa nova ou se abre uma antiga. Cada conversa tem o
/// próprio botão de apagar, e o topo tem o de apagar tudo. Depois da mudança
/// de uma conversa só por persona, esta tela é onde o usuário escolhe com
/// qual fio quer continuar.
class TelaHistorico extends StatelessWidget {
  const TelaHistorico({super.key, required this.persona});

  final Persona persona;

  void _abrirNova(BuildContext context) =>
      context.push('/${persona.slug}/conversa');

  void _abrirConversa(BuildContext context, Conversa conversa) =>
      context.push('/${persona.slug}/conversa/${conversa.id}');

  Future<void> _apagarUma(BuildContext context, Conversa conversa) async {
    final confirmou = await confirmar(
      context,
      titulo: 'Apagar esta conversa?',
      conteudo:
          'Só esta conversa será apagada deste aparelho, e da cópia na nuvem '
          'se houver. As outras conversas ficam. Essa ação não pode ser '
          'desfeita.',
      rotuloDaAcao: 'Apagar',
    );
    if (!confirmou || !context.mounted) return;
    await EscopoDoEstado.de(context).limparConversa(persona.id, conversa.id);
  }

  Future<void> _apagarTodas(BuildContext context) async {
    final confirmou = await confirmar(
      context,
      titulo: 'Apagar todas as conversas?',
      conteudo:
          'Todas as conversas com ${persona.nome} serão apagadas deste '
          'aparelho, e da cópia na nuvem se houver. Essa ação não pode ser '
          'desfeita.',
      rotuloDaAcao: 'Apagar tudo',
    );
    if (!confirmou || !context.mounted) return;
    await EscopoDoEstado.de(context).limparTodasDe(persona.id);
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final estado = EscopoDoEstado.de(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                persona.foto,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            const SizedBox(width: Spacing.sp10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona.nome,
                    style: tema.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Conversas',
                    style: tema.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nova conversa',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => _abrirNova(context),
          ),
          // Só tem o que apagar tudo quando há conversas.
          ListenableBuilder(
            listenable: estado,
            builder: (context, _) => estado.conversasDe(persona.id).isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Apagar todas as conversas',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _apagarTodas(context),
                  ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: estado,
        builder: (context, _) {
          final conversas = estado.conversasDe(persona.id);
          if (conversas.isEmpty) {
            return _SemConversas(
              persona: persona,
              aoComecar: () => _abrirNova(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sp8),
            itemCount: conversas.length,
            separatorBuilder: (context, _) => Divider(
              height: 1,
              indent: Spacing.sp16,
              endIndent: Spacing.sp16,
              color: cor.outlineVariant.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, i) {
              final conversa = conversas[i];
              return ListTile(
                onTap: () => _abrirConversa(context, conversa),
                title: Text(
                  conversa.titulo.isEmpty ? 'Conversa' : conversa.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tema.titleMedium,
                ),
                subtitle: Text(
                  dataLonga(
                    DateTime.fromMillisecondsSinceEpoch(conversa.momento),
                  ),
                  style: tema.labelMedium,
                ),
                trailing: IconButton(
                  tooltip: 'Apagar conversa',
                  icon: Icon(Icons.delete_outline, color: cor.error),
                  onPressed: () => _apagarUma(context, conversa),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Sem conversa nenhuma ainda: o convite para começar, no lugar da lista vazia.
class _SemConversas extends StatelessWidget {
  const _SemConversas({required this.persona, required this.aoComecar});

  final Persona persona;
  final VoidCallback aoComecar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Filete(largura: 64),
            const SizedBox(height: Spacing.sp18),
            Text(
              persona.nome,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: Spacing.sp10),
            Text(
              'Nenhuma conversa com ${persona.nome} ainda. '
              'Comece pela primeira pergunta.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: Spacing.sp12),
            // O histórico é a porta de entrada do chat: o aviso de que as
            // respostas são geradas por IA aparece aqui, antes da conversa,
            // além do rodapé do chat e da carta de boas-vindas.
            Text(
              avisoDeIa,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.sp18),
            FilledButton.icon(
              onPressed: aoComecar,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Começar conversa'),
            ),
          ],
        ),
      ),
    );
  }
}
