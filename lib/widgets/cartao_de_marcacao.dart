import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/dialogos.dart';
import '../telas/biblia.dart';
import 'carrega_uma_vez.dart';

class DevocionalCartaoDeMarcacao extends StatelessWidget {
  const DevocionalCartaoDeMarcacao({
    super.key,
    required this.marcacao,
    required this.mostrarNota,
  });

  final Marcacao marcacao;
  final bool mostrarNota;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final estado = EscopoDoEstado.de(context);
    final tema = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelaBiblia(
              livroInicial: marcacao.livro,
              capituloInicial: marcacao.capitulo,
              destacar: (marcacao.versiculo, marcacao.versiculo),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DevocionalEspacamento.sp16, DevocionalEspacamento.sp12, DevocionalEspacamento.sp8, DevocionalEspacamento.sp12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      marcacao.referencia,
                      style: tema.titleSmall?.copyWith(color: cor.secondary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar anotação',
                    icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 20),
                    onPressed: () async {
                      final nota = await editarNota(
                        context,
                        referencia: marcacao.referencia,
                        notaAtual: marcacao.nota,
                      );
                      if (nota != null) {
                        await estado.definirNota(
                          marcacao.livro,
                          marcacao.capitulo,
                          marcacao.versiculo,
                          nota,
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Remover',
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 20),
                    onPressed: () async {
                      final confirmou = await confirmarRemocao(
                        context,
                        referencia: marcacao.referencia,
                        comNota: marcacao.nota.isNotEmpty,
                      );
                      if (confirmou) estado.removerMarcacao(marcacao);
                    },
                  ),
                ],
              ),
              const SizedBox(height: DevocionalEspacamento.sp4),
              // O texto do versículo não é guardado junto da marcação: fica sempre
              // na versão salva, e assim uma correção no asset se reflete aqui.
              DevocionalCarregaUmaVez<String>(
                chave: marcacao.chave,
                carregar: () => Conteudo.instancia.versiculo(
                  marcacao.livro,
                  marcacao.capitulo,
                  marcacao.versiculo,
                ),
                // Falhar aqui deixava o cartão com o texto do versículo em branco,
                // sem dizer nada. A referência e a nota continuam visíveis, então
                // basta uma linha no lugar do versículo.
                construir: (context, snap) => Text(
                  snap.hasError
                      ? 'Não foi possível carregar o texto deste versículo.'
                      : snap.data ?? '',
                  style: tema.bodyMedium?.copyWith(
                    height: 1.55,
                    fontStyle: snap.hasError ? FontStyle.italic : null,
                    color: snap.hasError ? cor.onSurfaceVariant : null,
                  ),
                ),
              ),
              if (mostrarNota && marcacao.nota.isNotEmpty) ...[
                const SizedBox(height: DevocionalEspacamento.sp12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(DevocionalEspacamento.sp12),
                  decoration: BoxDecoration(
                    color: cor.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: cor.primary, width: 3),
                    ),
                  ),
                  child: Text(
                    marcacao.nota,
                    style: tema.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
