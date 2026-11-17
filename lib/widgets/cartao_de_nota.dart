import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../estilo/espacamento.dart';
import '../funcoes/dialogos.dart';
import 'caixa_de_citacao.dart';
import 'carrega_uma_vez.dart';

/// Um favorito ou anotação na tela de Notas: a referência, o texto marcado e
/// a nota, com editar e remover. Serve às três origens (Bíblia, Devocional e
/// Biblioteca), que só diferem em de onde vem o texto, para onde o toque leva
/// e onde a nota é guardada; isso tudo chega por parâmetro.
class DevocionalCartaoDeNota extends StatelessWidget {
  const DevocionalCartaoDeNota({
    super.key,
    required this.referencia,
    required this.chaveDoTexto,
    required this.carregarTexto,
    required this.nota,
    required this.mostrarNota,
    required this.aoAbrir,
    required this.aoSalvarNota,
    required this.aoRemover,
    this.mensagemDeFalha = 'Não foi possível carregar este texto.',
    this.maxLinhas,
  });

  /// "João 3:16", "Manhã, 17 de novembro" ou "Respigas, capítulo 3".
  final String referencia;

  /// Identifica o texto para o [DevocionalCarregaUmaVez] não recarregá-lo a
  /// cada quadro.
  final String chaveDoTexto;

  /// O texto não é guardado junto da marcação: é lido sob demanda, da versão
  /// salva, e assim uma correção no asset se reflete aqui.
  final Future<String> Function() carregarTexto;

  final String nota;
  final bool mostrarNota;
  final VoidCallback aoAbrir;

  /// Grava a nota editada (vazia apaga).
  final Future<void> Function(String nota) aoSalvarNota;

  /// Tira o favorito, depois de confirmado.
  final Future<void> Function() aoRemover;

  /// O que aparece no lugar do texto quando ele não carrega: a referência e a
  /// nota continuam visíveis, então basta uma linha.
  final String mensagemDeFalha;

  /// Nulo mostra o texto inteiro (um versículo); os parágrafos de livro e de
  /// devocional são longos e param em poucas linhas.
  final int? maxLinhas;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DevocionalEspacamento.sp16,
            DevocionalEspacamento.sp12,
            DevocionalEspacamento.sp8,
            DevocionalEspacamento.sp12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      referencia,
                      style: tema.titleSmall?.copyWith(color: cor.secondary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar anotação de $referencia',
                    icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 20),
                    onPressed: () async {
                      final editada = await editarNota(
                        context,
                        referencia: referencia,
                        notaAtual: nota,
                      );
                      if (editada != null) await aoSalvarNota(editada);
                    },
                  ),
                  IconButton(
                    tooltip: 'Remover $referencia dos favoritos',
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 20),
                    onPressed: () async {
                      final confirmou = await confirmarRemocao(
                        context,
                        referencia: referencia,
                        comNota: nota.isNotEmpty,
                      );
                      if (confirmou) await aoRemover();
                    },
                  ),
                ],
              ),
              const SizedBox(height: DevocionalEspacamento.sp4),
              DevocionalCarregaUmaVez<String>(
                chave: chaveDoTexto,
                carregar: carregarTexto,
                construir: (context, snap) => Text(
                  snap.hasError ? mensagemDeFalha : snap.data ?? '',
                  maxLines: maxLinhas,
                  overflow: maxLinhas == null ? null : TextOverflow.ellipsis,
                  style: tema.bodyMedium?.copyWith(
                    height: 1.55,
                    fontStyle: snap.hasError ? FontStyle.italic : null,
                    color: snap.hasError ? cor.onSurfaceVariant : null,
                  ),
                ),
              ),
              if (mostrarNota && nota.isNotEmpty) ...[
                const SizedBox(height: DevocionalEspacamento.sp12),
                DevocionalCaixaDeCitacao(
                  expandir: true,
                  child: Text(
                    nota,
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

/// A lista de cartões de uma aba de Notas, ou o [vazio] quando não há nenhum.
class DevocionalListaDeNotas extends StatelessWidget {
  const DevocionalListaDeNotas({
    super.key,
    required this.quantidade,
    required this.construir,
    required this.vazio,
  });

  final int quantidade;

  /// Constrói o cartão de índice dado, sob demanda (a lista pode ter
  /// centenas de favoritos).
  final IndexedWidgetBuilder construir;
  final Widget vazio;

  @override
  Widget build(BuildContext context) {
    if (quantidade == 0) return vazio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp32,
      ),
      itemCount: quantidade,
      separatorBuilder: (_, _) =>
          const SizedBox(height: DevocionalEspacamento.sp10),
      itemBuilder: construir,
    );
  }
}
