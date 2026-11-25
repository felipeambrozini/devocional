import 'package:material_ui/material_ui.dart';

import '../dados/planos_nuvem.dart';
import '../estilo/espacamento.dart';
import 'linha_de_participante.dart';

class TabernaculoSecaoDeParticipantes extends StatelessWidget {
  const TabernaculoSecaoDeParticipantes({
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
        padding: const EdgeInsets.all(TabernaculoEspacamento.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participantes (${participantes.length})',
              style: tema.titleSmall,
            ),
            const SizedBox(height: TabernaculoEspacamento.sp8),
            for (final MapEntry(key: uid, value: entrada)
                in participantes.entries) ...[
              TabernaculoLinhaDeParticipante(
                nome: _nomeDe(entrada),
                // Só os dias que valem na revisão atual e cabem no plano:
                // quem ainda não abriu o plano depois de uma edição aparece
                // zerado, e ninguém passa do total.
                lidos: lidosValidos(dados, entrada),
                ehVoce: uid == meuUid,
                ehCriador: uid == criador,
                totalDeDias: totalDeDias,
              ),
              const SizedBox(height: TabernaculoEspacamento.sp10),
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
}
