import 'package:flutter/material.dart';

import '../widgets/widgets.dart';

/// As duas abas de quem tem conta: o cronograma anual e os planos próprios.
class DevocionalAbasDoPlano extends StatelessWidget {
  const DevocionalAbasDoPlano({super.key, required this.hoje, required this.acaoDeAjustes});

  final DateTime? hoje;
  final Widget acaoDeAjustes;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: DevocionalAppBar(
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
            DevocionalAbaDoCronograma(hoje: hoje),
            const DevocionalAbaDosMeusPlanos(),
          ],
        ),
      ),
    );
  }
}
