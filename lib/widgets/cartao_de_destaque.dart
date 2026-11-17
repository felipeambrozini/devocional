import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../dados/biblioteca.dart';
import '../dados/conteudo.dart';
import '../dados/estado.dart';
import '../dados/leitura_de_livros.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/datas.dart';
import '../funcoes/dialogos.dart';
import 'carrega_uma_vez.dart';

/// De onde vem um favorito ou nota que não é da Bíblia: o título do cartão e
/// o texto de trás, para as telas de notas da Biblioteca e do Devocional.
class OrigemDoDestaque {
  const OrigemDoDestaque({required this.referencia, required this.rotaDeAbrir});

  /// "Respigas entre os Feixes, capítulo 3" ou "Manhã, 17 de novembro".
  final String referencia;

  /// A rota que reabre o texto.
  final String rotaDeAbrir;

  /// Nulo para um slug que o app não conhece (livro tirado do catálogo).
  static OrigemDoDestaque? de(DestaqueDeLivro d) {
    if (ehSlugDeDevocional(d.slug)) {
      final leitura = leituraDoSlug(d.slug);
      final data = dataDoDestaque(d);
      final rotulo = switch (leitura) {
        'manha' => 'Manhã',
        'noite' => 'Noite',
        'promessas' => 'Promessas de Deus',
        _ => null,
      };
      if (rotulo == null || data == null) return null;
      return OrigemDoDestaque(
        referencia: '$rotulo, ${dataLonga(data)}',
        rotaDeAbrir:
            '/$leitura?data=${data.year}-'
            '${data.month.toString().padLeft(2, '0')}-'
            '${data.day.toString().padLeft(2, '0')}',
      );
    }
    final obra = obraPorSlug(d.slug);
    if (obra == null) return null;
    return OrigemDoDestaque(
      referencia: '${obra.titulo}, capítulo ${d.capitulo + 1}',
      rotaDeAbrir: '/biblioteca/${d.slug}/${d.capitulo + 1}',
    );
  }

  /// O dia de um destaque de devocional, no ano corrente (a rota de hoje
  /// continua valendo) ou em 2024 para 29 de fevereiro.
  static DateTime? dataDoDestaque(DestaqueDeLivro d) {
    final mes = d.capitulo ~/ 100;
    final dia = d.capitulo % 100;
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    final ano = DateTime.now().year;
    final data = DateTime(ano, mes, dia);
    if (data.month == mes) return data;
    final bissexto = DateTime(2024, mes, dia);
    return bissexto.month == mes ? bissexto : null;
  }
}

/// Um favorito ou nota de livro da Biblioteca ou de devocional: a referência,
/// o começo do texto e a nota, com editar e remover como no cartão da Bíblia.
class DevocionalCartaoDeDestaque extends StatelessWidget {
  const DevocionalCartaoDeDestaque({
    super.key,
    required this.destaque,
    required this.origem,
    required this.mostrarNota,
  });

  final DestaqueDeLivro destaque;
  final OrigemDoDestaque origem;
  final bool mostrarNota;

  /// O texto de trás, carregado sob demanda como o versículo no cartão da
  /// Bíblia: a lista não traz todos os livros para a memória de uma vez.
  Future<String> _carregarTexto() async {
    if (ehSlugDeDevocional(destaque.slug)) {
      final data = OrigemDoDestaque.dataDoDestaque(destaque);
      if (data == null) return '';
      final dev = switch (leituraDoSlug(destaque.slug)) {
        'manha' => await Conteudo.instancia.devocional(data, Periodo.manha),
        'noite' => await Conteudo.instancia.devocional(data, Periodo.noite),
        _ => await Conteudo.instancia.promessa(data),
      };
      return dev?.texto ?? '';
    }
    final capitulos = await Biblioteca.instancia.capitulos(destaque.slug);
    if (capitulos == null ||
        destaque.capitulo >= capitulos.length ||
        destaque.paragrafo >= capitulos[destaque.capitulo].paragrafos.length) {
      return '';
    }
    return capitulos[destaque.capitulo].paragrafos[destaque.paragrafo];
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final leitura = EscopoDoEstado.de(context).leituraDeLivros;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(origem.rotaDeAbrir),
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
                      origem.referencia,
                      style: tema.titleSmall?.copyWith(color: cor.secondary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar anotação de ${origem.referencia}',
                    icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 20),
                    onPressed: () async {
                      final nota = await editarNota(
                        context,
                        referencia: origem.referencia,
                        notaAtual: destaque.nota,
                      );
                      if (nota != null) {
                        await leitura.definirNota(
                          destaque.slug,
                          destaque.capitulo,
                          destaque.paragrafo,
                          nota,
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Remover ${origem.referencia} dos favoritos',
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 20),
                    onPressed: () async {
                      final confirmou = await confirmarRemocao(
                        context,
                        referencia: origem.referencia,
                        comNota: destaque.nota.isNotEmpty,
                      );
                      if (confirmou) await leitura.removerDestaque(destaque);
                    },
                  ),
                ],
              ),
              const SizedBox(height: DevocionalEspacamento.sp4),
              DevocionalCarregaUmaVez<String>(
                chave: destaque.chave,
                carregar: _carregarTexto,
                construir: (context, snap) => Text(
                  snap.hasError
                      ? 'Não foi possível carregar este texto.'
                      : snap.data ?? '',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: tema.bodyMedium?.copyWith(
                    height: 1.55,
                    fontStyle: snap.hasError ? FontStyle.italic : null,
                    color: snap.hasError ? cor.onSurfaceVariant : null,
                  ),
                ),
              ),
              if (mostrarNota && destaque.nota.isNotEmpty) ...[
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
                    destaque.nota,
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

/// A lista de favoritos ou notas de uma aba que não é a Bíblia.
class DevocionalListaDeDestaques extends StatelessWidget {
  const DevocionalListaDeDestaques({
    super.key,
    required this.itens,
    required this.vazio,
    this.mostrarNota = false,
  });

  final List<DestaqueDeLivro> itens;
  final Widget vazio;
  final bool mostrarNota;

  @override
  Widget build(BuildContext context) {
    // Destaque de um livro que saiu do catálogo não tem para onde levar.
    final visiveis = [
      for (final d in itens)
        if (OrigemDoDestaque.de(d) case final origem?) (d, origem),
    ];
    if (visiveis.isEmpty) return vazio;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp16,
        DevocionalEspacamento.sp32,
      ),
      itemCount: visiveis.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: DevocionalEspacamento.sp10),
      itemBuilder: (context, i) => DevocionalCartaoDeDestaque(
        destaque: visiveis[i].$1,
        origem: visiveis[i].$2,
        mostrarNota: mostrarNota,
      ),
    );
  }
}
