import 'package:flutter/material.dart';

import '../dados/estado.dart';
import '../dados/nuvem.dart';
import '../dados/recursos.dart';
import '../widgets/widgets.dart';

/// Cronograma anual agrupado por mês, com marcação de lido — e, na aba Meus
/// Planos, os planos de leitura que o usuário cria, compartilha e acompanha.
class TelaPlano extends StatefulWidget {
  const TelaPlano({super.key, this.hoje});

  /// Só o teste passa data: é o que permite verificar o cronograma bissexto sem
  /// esperar 2028. Em produção fica nulo e vale o relógio.
  final DateTime? hoje;

  @override
  State<TelaPlano> createState() => _TelaPlanoState();
}

class _TelaPlanoState extends State<TelaPlano> {
  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);

    final acaoDeAjustes = DevocionalBotaoDeAjustes(estado: estado);

    // Sem plano personalizado, ou sem conta para guardá-lo na nuvem, a tela
    // não tem o que dividir em abas: só o cronograma anual. A aba Meus
    // Planos depende de conta porque compartilhar um plano depende dela.
    return ListenableBuilder(
      listenable: Nuvem.instancia,
      builder: (context, _) {
        if (!Recursos.planoPersonalizado || !Nuvem.instancia.logado) {
          return Scaffold(
            appBar: DevocionalAppBar(
              title: const Text('Plano'),
              actions: [acaoDeAjustes],
            ),
            body: DevocionalAbaDoCronograma(hoje: widget.hoje),
          );
        }
        return DevocionalAbasDoPlano(
          hoje: widget.hoje,
          acaoDeAjustes: acaoDeAjustes,
        );
      },
    );
  }
}