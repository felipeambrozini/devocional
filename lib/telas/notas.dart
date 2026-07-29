import 'package:flutter/material.dart';

import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'biblia.dart';
import 'comuns.dart';

/// Favoritos e anotações, em duas abas.
class TelaNotas extends StatelessWidget {
  const TelaNotas({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = EscopoDoEstado.de(context);
    final favoritos = estado.marcacoes;
    final notas = estado.comNota;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marcações'),
          bottom: TabBar(
            labelColor: Cores.douradoClaro,
            unselectedLabelColor: Cores.begeSuave,
            indicatorColor: Cores.dourado,
            tabs: [
              Tab(text: 'Favoritos (${favoritos.length})'),
              Tab(text: 'Anotações (${notas.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Lista(
              itens: favoritos,
              vazio: const AvisoVazio(
                icone: Icons.bookmark_outline,
                titulo: 'Nenhum favorito',
                detalhe: 'Toque num versículo na Bíblia para favoritá-lo.',
              ),
            ),
            _Lista(
              itens: notas,
              mostrarNota: true,
              vazio: const AvisoVazio(
                icone: Icons.edit_note,
                titulo: 'Nenhuma anotação',
                detalhe: 'Toque num versículo na Bíblia para anotar.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.itens, required this.vazio, this.mostrarNota = false});

  final List<Marcacao> itens;
  final Widget vazio;
  final bool mostrarNota;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return vazio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: itens.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _CartaoDeMarcacao(
        marcacao: itens[i],
        mostrarNota: mostrarNota,
      ),
    );
  }
}

class _CartaoDeMarcacao extends StatelessWidget {
  const _CartaoDeMarcacao({required this.marcacao, required this.mostrarNota});

  final Marcacao marcacao;
  final bool mostrarNota;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${marcacao.referencia}  ·  ${marcacao.versao.sigla}',
                      style: tema.titleSmall?.copyWith(color: Cores.douradoClaro),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar anotação',
                    icon: const Icon(Icons.edit_note, size: 20),
                    onPressed: () async {
                      final nota = await editarNota(
                        context,
                        referencia: marcacao.referencia,
                        notaAtual: marcacao.nota,
                      );
                      if (nota != null) {
                        await estado.definirNota(
                          marcacao.versao,
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
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => estado.removerMarcacao(marcacao),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // O texto do versículo não é guardado junto da marcação: fica sempre
              // na versão salva, e assim uma correção no asset se reflete aqui.
              CarregaUmaVez<String>(
                chave: marcacao.chave,
                carregar: () => Conteudo.instancia.versiculo(
                  marcacao.versao,
                  marcacao.livro,
                  marcacao.capitulo,
                  marcacao.versiculo,
                ),
                construir: (context, snap) => Text(
                  snap.data ?? '',
                  style: tema.bodyMedium?.copyWith(height: 1.55),
                ),
              ),
              if (mostrarNota && marcacao.nota.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Cores.superficieAlta,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: Cores.dourado, width: 3),
                    ),
                  ),
                  child: Text(
                    marcacao.nota,
                    style: tema.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
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
