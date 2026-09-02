import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/coleta.dart';
import '../data/estado.dart';

/// Diálogo de aceite mostrado uma vez, antes de qualquer coleta remota —
/// erro para o Sentry, uso anônimo para o Analytics (ver
/// `lib/data/coleta.dart` e a seção "Uso anônimo" em
/// `lib/telas/privacidade.dart`). Os dois SDKs ficam desligados por padrão;
/// só [aplicarAceiteDeColeta] os liga, e só depois desta resposta.
///
/// Chamado de `main.dart`, num `addPostFrameCallback` depois do primeiro
/// quadro — precisa do `Navigator` já montado.
Future<void> mostrarAceiteDeColetaSeNecessario(BuildContext context) async {
  final estado = EscopoDoEstado.de(context);
  if (estado.aceiteDeColeta != null) return;
  final tema = Theme.of(context).textTheme;
  final aceito = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogo) => AlertDialog(
      title: const Text('Ajudar a melhorar o app'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Com sua permissão, o app envia dois tipos de informação sem '
              'identificar você: erros técnicos, para achar e corrigir '
              'falhas, e uso anônimo por tela, para saber onde as pessoas '
              'travam. Nada disso é vendido nem usado para anúncio, e dá '
              'para mudar de ideia depois em Sobre.',
              style: tema.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogo).pop();
            GoRouter.of(context).push('/privacidade');
          },
          child: const Text('Ver a política'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(false),
          child: const Text('Não'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogo).pop(true),
          child: const Text('Aceitar'),
        ),
      ],
    ),
  );
  // `null` é "Ver a política": o usuário saiu para ler antes de decidir, e
  // o diálogo volta a aparecer na próxima abertura até uma resposta de
  // verdade — nunca lido como recusa.
  if (aceito == null || !context.mounted) return;
  await estado.definirAceiteDeColeta(aceito);
  await aplicarAceiteDeColeta(aceito);
}
