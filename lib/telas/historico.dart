import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../dados/personas.dart';
import '../estilo/spacing.dart';
import '../funcoes/aviso.dart';
import '../funcoes/datas.dart';
import '../widgets/widgets.dart';

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
      appBar: DevocionalAppBar(
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
            const SizedBox(width: DevocionalEspacamento.sp10),
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
            icon: const FaIcon(FontAwesomeIcons.commentDots),
            onPressed: () => _abrirNova(context),
          ),
          // Só tem o que apagar tudo quando há conversas.
          ListenableBuilder(
            listenable: estado,
            builder: (context, _) => estado.conversasDe(persona.id).isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Apagar todas as conversas',
                    icon: const FaIcon(FontAwesomeIcons.broom),
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
            return DevocionalSemConversas(
              persona: persona,
              aoComecar: () => _abrirNova(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: DevocionalEspacamento.sp8),
            itemCount: conversas.length,
            separatorBuilder: (context, _) => Divider(
              height: 1,
              indent: DevocionalEspacamento.sp16,
              endIndent: DevocionalEspacamento.sp16,
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
                  icon: FaIcon(FontAwesomeIcons.trash, color: cor.error),
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
