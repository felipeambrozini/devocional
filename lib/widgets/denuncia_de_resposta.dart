import 'package:material_ui/material_ui.dart';

import '../dados/denuncias.dart';
import '../dados/modelos.dart';
import '../dados/personas.dart';
import '../estilo/espacamento.dart';
import 'botao.dart';

/// Diálogo "Denunciar resposta": escolhe o motivo, aceita um detalhe opcional
/// e devolve a [Denuncia] pronta (ou null, se cancelar).
///
/// Quem chama envia e mostra o aviso (ver `ChatControlador.denunciar`); o
/// diálogo não fala com o Firestore, para o teste de widget poder verificar o
/// fluxo sem rede.
Future<Denuncia?> mostrarDenunciaDeResposta(
  BuildContext context, {
  required Persona persona,
  required Mensagem resposta,
  Mensagem? pergunta,
  String? conversaId,
}) => showDialog<Denuncia>(
  context: context,
  builder: (context) => _DialogoDeDenuncia(
    persona: persona,
    resposta: resposta,
    pergunta: pergunta,
    conversaId: conversaId,
  ),
);

class _DialogoDeDenuncia extends StatefulWidget {
  const _DialogoDeDenuncia({
    required this.persona,
    required this.resposta,
    required this.pergunta,
    required this.conversaId,
  });

  final Persona persona;
  final Mensagem resposta;
  final Mensagem? pergunta;
  final String? conversaId;

  @override
  State<_DialogoDeDenuncia> createState() => _DialogoDeDenunciaState();
}

class _DialogoDeDenunciaState extends State<_DialogoDeDenuncia> {
  final _detalhe = TextEditingController();
  String? _motivo;

  @override
  void dispose() {
    _detalhe.dispose();
    super.dispose();
  }

  void _enviar() {
    final motivo = _motivo;
    if (motivo == null) return;
    Navigator.pop(
      context,
      denunciaDaResposta(
        resposta: widget.resposta,
        pergunta: widget.pergunta,
        persona: widget.persona.id,
        conversaId: widget.conversaId,
        motivo: motivo,
        detalhe: _detalhe.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return AlertDialog(
      scrollable: true,
      title: const Text('Denunciar resposta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A pergunta, a resposta e o motivo vão para o desenvolvedor '
            'revisar. Seu e-mail e seu nome não são enviados.',
            style: tema.bodyMedium,
          ),
          const SizedBox(height: TabernaculoEspacamento.sp16),
          Wrap(
            spacing: TabernaculoEspacamento.sp8,
            runSpacing: TabernaculoEspacamento.sp8,
            children: [
              for (final motivo in motivosDeDenuncia.entries)
                ChoiceChip(
                  label: Text(motivo.value),
                  selected: _motivo == motivo.key,
                  onSelected: (_) => setState(() => _motivo = motivo.key),
                ),
            ],
          ),
          const SizedBox(height: TabernaculoEspacamento.sp16),
          TextField(
            controller: _detalhe,
            minLines: 1,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Conte mais (opcional)',
            ),
          ),
        ],
      ),
      actions: [
        TabernaculoBotaoTerciario(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TabernaculoBotaoPrimario(
          onPressed: _motivo == null ? null : _enviar,
          child: const Text('Enviar denúncia'),
        ),
      ],
    );
  }
}
