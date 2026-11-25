import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/config_admin.dart';
import '../dados/recursos.dart';
import '../widgets/widgets.dart';

/// As duas abas de quem tem conta: o cronograma anual e os planos próprios.
class TabernaculoAbasDoPlano extends StatelessWidget {
  const TabernaculoAbasDoPlano({
    super.key,
    required this.hoje,
    required this.acaoDeAjustes,
  });

  final DateTime? hoje;
  final Widget acaoDeAjustes;

  @override
  Widget build(BuildContext context) {
    // O cronograma desliga sozinho no painel admin: sem ele, só restam os
    // planos próprios, sem régua de abas. Com os dois desligados, um aviso
    // explica em vez de uma tela vazia.
    return ListenableBuilder(
      listenable: ConfigAdmin.instancia,
      builder: (context, _) {
        if (!Recursos.cronograma && !Recursos.planoPersonalizado) {
          return Scaffold(
            appBar: TabernaculoAppBar(
              title: const Text('Plano'),
              actions: [acaoDeAjustes],
            ),
            body: const TabernaculoAvisoVazio(
              icone: FontAwesomeIcons.calendarDays,
              titulo: 'Plano desativado temporariamente',
              detalhe: 'O cronograma e os planos próprios voltam em breve',
            ),
          );
        }
        if (!Recursos.cronograma) {
          return Scaffold(
            appBar: TabernaculoAppBar(
              title: const Text('Plano'),
              actions: [acaoDeAjustes],
            ),
            body: const TabernaculoAbaDosMeusPlanos(),
          );
        }
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: TabernaculoAppBar(
              title: const Text('Plano'),
              actions: [acaoDeAjustes],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Cronograma'),
                  Tab(text: 'Meus planos'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                TabernaculoAbaDoCronograma(hoje: hoje),
                const TabernaculoAbaDosMeusPlanos(),
              ],
            ),
          ),
        );
      },
    );
  }
}
