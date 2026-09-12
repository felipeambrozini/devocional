import 'package:flutter/material.dart';

import '../estilo/espacamento.dart';
import 'linha_de_participante.dart';

class DevocionalSecaoDeParticipantes extends StatelessWidget {
  const DevocionalSecaoDeParticipantes({
    super.key,
    required this.dados,
    required this.meuUid,
    required this.totalDeDias,
  });

  final Map<String, dynamic> dados;
  final String? meuUid;
  final int totalDeDias;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final participantes =
        dados['participantes'] as Map<String, dynamic>? ?? const {};
    final criador = dados['criadoPor'] as String?;
    if (participantes.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participantes (${participantes.length})',
              style: tema.titleSmall,
            ),
            const SizedBox(height: DevocionalEspacamento.sp8),
            for (final MapEntry(key: uid, value: entrada)
                in participantes.entries) ...[
              DevocionalLinhaDeParticipante(
                nome: _nomeDe(entrada),
                lidos: _lidosDe(entrada),
                ehVoce: uid == meuUid,
                ehCriador: uid == criador,
                totalDeDias: totalDeDias,
              ),
              const SizedBox(height: DevocionalEspacamento.sp10),
            ],
          ],
        ),
      ),
    );
  }

  String _nomeDe(Object? entrada) {
    if (entrada is Map<String, dynamic>) {
      final nome = entrada['nome'];
      if (nome is String && nome.trim().isNotEmpty) return nome;
    }
    return 'Participante';
  }

  Set<int> _lidosDe(Object? entrada) {
    if (entrada is Map<String, dynamic> && entrada['lidos'] is List) {
      return {
        for (final dia in entrada['lidos'] as List)
          if (dia is int) dia,
      };
    }
    return const {};
  }
}
