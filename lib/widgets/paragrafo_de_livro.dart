import 'package:material_ui/material_ui.dart';

import '../dados/modelos.dart';
import '../dados/nuvem.dart';
import '../estilo/espacamento.dart';
import '../estilo/toque.dart';

/// Um parágrafo do livro. Grifado, ganha o fundo de citação e o fio do metal à
/// esquerda; com nota, a nota aparece embaixo. A faixa à esquerda existe sempre
/// (transparente) para o texto não pular de lugar quando o grifo liga.
class TabernaculoParagrafoDeLivro extends StatelessWidget {
  const TabernaculoParagrafoDeLivro({
    super.key,
    required this.texto,
    required this.destaque,
    required this.aoTocar,
    this.estilo,
    this.outrasAcoes = 'anotar ou copiar',
    this.outrasAcoesSemConta = 'copiar',
  });

  final String texto;
  final DestaqueDeLivro? destaque;
  final VoidCallback aoTocar;

  /// Estilo do texto; o padrão é o corpo de leitura do tema.
  final TextStyle? estilo;

  /// O que a folha do toque oferece além do favorito, para a dica do leitor
  /// de tela ("anotar ou copiar"; o Devocional acrescenta compartilhar).
  final String outrasAcoes;

  /// O mesmo, sem conta: favoritos e notas são pessoais, e a folha só oferece
  /// o que não pede conta.
  final String outrasAcoesSemConta;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: Nuvem.instancia, builder: _construir);
  }

  Widget _construir(BuildContext context, Widget? _) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final grifado = destaque != null;
    final nota = destaque?.nota ?? '';
    // A dica acompanha o estado, para não anunciar "Favorito... toque para
    // favoritar": com nota, a folha nem oferece desfavoritar (a nota prende
    // o favorito, ver `LeituraDeLivros.alternarDestaque`).
    final dica = !Nuvem.instancia.logado
        ? 'Toque para $outrasAcoesSemConta'
        : nota.isNotEmpty
        ? 'Toque para $outrasAcoes'
        : grifado
        ? 'Toque para remover dos favoritos, $outrasAcoes'
        : 'Toque para favoritar, $outrasAcoes';

    return Padding(
      padding: const EdgeInsets.only(bottom: TabernaculoEspacamento.sp12),
      child: ConstrainedBox(
        // O alvo de uma linha curta ficava abaixo dos 48 dp: o mesmo mínimo da
        // Bíblia vale aqui, inclusive para quem lê com o texto ampliado.
        constraints: const BoxConstraints(minHeight: TabernaculoToque.minimo),
        child: Semantics(
          button: true,
          label: grifado ? 'Favorito' : null,
          hint: dica,
          child: InkWell(
            onTap: aoTocar,
            // Ink e não Container: o fundo do grifo é opaco e, pintado por
            // cima do InkWell, escondia o splash e o foco do teclado.
            child: Ink(
              decoration: BoxDecoration(
                color: grifado ? cor.surfaceContainerHighest : null,
                border: Border(
                  left: BorderSide(
                    color: grifado ? cor.secondary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.fromLTRB(
                  TabernaculoEspacamento.sp10,
                  TabernaculoEspacamento.sp4,
                  TabernaculoEspacamento.sp4,
                  TabernaculoEspacamento.sp4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texto,
                      style: estilo ?? tema.bodyLarge?.copyWith(height: 1.7),
                    ),
                    if (nota.isNotEmpty) ...[
                      const SizedBox(height: TabernaculoEspacamento.sp8),
                      Text(
                        nota,
                        style: tema.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cor.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
