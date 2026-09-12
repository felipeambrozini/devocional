import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../controladores/busca_controlador.dart';
import '../dados/conteudo.dart';
import '../dados/modelos.dart';
import '../estilo/espacamento.dart';
import '../funcoes/datas.dart';
import '../widgets/widgets.dart';
import 'devocional.dart';

/// Busca no texto da Bíblia e nos devocionais de Spurgeon, em duas abas.
///
/// Os achados da Bíblia chegam por stream e aparecem conforme os livros são
/// lidos, então a tela mostra Gênesis enquanto o resto ainda carrega, em vez
/// de travar até o fim. Os devocionais são só 366+366 registros já cacheados
/// por completo depois da primeira leitura (`Conteudo.buscarDevocionais`,
/// bem mais barato que varrer a Bíblia), então essa aba não precisa de
/// stream nem de teto de resultados.
enum AbaDaBusca { biblia, devocionais }

class TelaBusca extends StatefulWidget {
  const TelaBusca({super.key, this.abaInicial = AbaDaBusca.biblia});

  final AbaDaBusca abaInicial;

  @override
  State<TelaBusca> createState() => _TelaBuscaState();
}

class _TelaBuscaState extends State<TelaBusca> {
  late final _controller = BuscaControlador();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A DevocionalLarguraDeLeitura fica no corpo, não em volta do Scaffold: envolvendo o
    // Scaffold, a própria AppBar ficava numa faixa de 720 px no meio da janela.
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final cor = Theme.of(context).colorScheme;
        return DefaultTabController(
          length: 2,
          initialIndex: widget.abaInicial == AbaDaBusca.devocionais ? 1 : 0,
          child: Scaffold(
            appBar: DevocionalAppBar(
              title: const Text('Buscar'),
              bottom: TabBar(
                labelColor: cor.secondary,
                unselectedLabelColor: cor.onSurfaceVariant,
                indicatorColor: cor.primary,
                tabs: const [
                  Tab(text: 'Bíblia'),
                  Tab(text: 'Devocionais'),
                ],
              ),
            ),
            body: DevocionalLarguraDeLeitura(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(DevocionalEspacamento.sp16),
                    child: DevocionalBusca(
                      controller: _controller.controle,
                      // Só fora da web: no celular o teclado abre junto e cobre
                      // a lista antes de qualquer intenção de digitar.
                      autofocus: !kIsWeb,
                      hintText: 'Palavra, expressão ou referência',
                      // Além de atualizar o botão de limpar, dispara a busca
                      // automaticamente um instante depois que a digitação parar.
                      onChanged: (_) => _controller.aoDigitar(context),
                      aoBuscar: () => _controller.buscar(context),
                      aoLimpar: _controller.limpar,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        DevocionalAbaBiblia(
                          termoBuscado: _controller.termoBuscado,
                          referencia: _controller.referencia,
                          achados: _controller.achados,
                          buscando: _controller.buscando,
                          erro: _controller.erro,
                          aoTentarDeNovo: () => _controller.buscar(context),
                        ),
                        _AbaDevocionais(
                          termoBuscado: _controller.termoBuscado,
                          achados: _controller.achadosDevocionais,
                          buscando: _controller.buscandoDevocionais,
                          erro: _controller.erroDevocionais,
                          aoTentarDeNovo: () => _controller.buscar(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AbaDevocionais extends StatelessWidget {
  const _AbaDevocionais({
    required this.termoBuscado,
    required this.achados,
    required this.buscando,
    required this.erro,
    required this.aoTentarDeNovo,
  });

  final String termoBuscado;
  final List<AchadoDevocional> achados;
  final bool buscando;
  final bool erro;
  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    if (erro) {
      return DevocionalErroDeBusca(aoTentarDeNovo: aoTentarDeNovo);
    }
    if (termoBuscado.isEmpty) {
      return const DevocionalAvisoVazio(
        icone: FontAwesomeIcons.bookOpen,
        titulo: 'Busque nos devocionais',
        detalhe: 'Manhã e Noite e Promessas de Deus, na voz de Spurgeon.',
      );
    }
    if (achados.isEmpty && !buscando) {
      return DevocionalAvisoVazio(
        icone: FontAwesomeIcons.magnifyingGlassMinus,
        titulo: 'Nada encontrado',
        detalhe: 'Nenhum devocional com "$termoBuscado".',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DevocionalEspacamento.sp16,
            0,
            DevocionalEspacamento.sp16,
            DevocionalEspacamento.sp8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${achados.length} ${achados.length == 1 ? 'resultado' : 'resultados'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: DevocionalEspacamento.sp10),
              if (buscando)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              DevocionalEspacamento.sp16,
              0,
              DevocionalEspacamento.sp16,
              DevocionalEspacamento.sp32,
            ),
            itemCount: achados.length,
            separatorBuilder: (_, _) => const Divider(height: DevocionalEspacamento.sp18),
            itemBuilder: (context, i) => _ItemDeAchadoDevocional(
              achado: achados[i],
              termo: termoBuscado,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemDeAchadoDevocional extends StatelessWidget {
  const _ItemDeAchadoDevocional({required this.achado, required this.termo});

  final AchadoDevocional achado;
  final String termo;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    final leitura = Leitura.values.byName(achado.leitura);
    final data = _dataDoDevocional(achado.data);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TelaDevocional(dataInicial: data, leituraInicial: leitura),
        ),
      ),
      // 12 como no destaque de versículo: 8 está fora da escala do DESIGN.md.
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: DevocionalEspacamento.sp4,
          horizontal: DevocionalEspacamento.sp4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${leitura.rotulo} · ${dataLonga(data)}',
              style: tema.titleSmall?.copyWith(color: cor.secondary),
            ),
            if (achado.titulo.isNotEmpty) ...[
              const SizedBox(height: DevocionalEspacamento.sp2),
              Text(
                achado.titulo,
                style: tema.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: cor.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: DevocionalEspacamento.sp5),
            Text.rich(
              destacar(achado.texto, termo, tema, cor),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma data qualquer, só para navegar até o dia certo do devocional: os
/// assets são anuais e a chave 'DD-MM' não guarda ano. 2024 é bissexto de
/// propósito — sem isso, '29-02' normalizaria sozinho para 1º de março (ver
/// `test/bissexto_test.dart`) e a busca levaria para o dia errado, calada.
DateTime _dataDoDevocional(String chave) {
  final partes = chave.split('-');
  return DateTime(2024, int.parse(partes[1]), int.parse(partes[0]));
}

/// Realça as ocorrências do termo, comparando sem acento para que buscar
/// "coracao" destaque "coração" no texto original. Compartilhada pelos dois
/// tipos de resultado, Bíblia e devocionais.
TextSpan destacar(String texto, String termo, TextTheme tema, ColorScheme cor) {
  final base = tema.bodyMedium?.copyWith(height: 1.5);
  final forte = base?.copyWith(
    color: cor.secondary,
    fontWeight: FontWeight.w700,
  );
  final textoSemAcento = Conteudo.normalizar(texto);
  final expressao = Conteudo.regexDePalavra(Conteudo.normalizar(termo));

  final pedacos = <TextSpan>[];
  var cursor = 0;
  for (final acerto in expressao.allMatches(textoSemAcento)) {
    if (acerto.start > cursor) {
      pedacos.add(
        TextSpan(text: texto.substring(cursor, acerto.start), style: base),
      );
    }
    pedacos.add(
      TextSpan(text: texto.substring(acerto.start, acerto.end), style: forte),
    );
    cursor = acerto.end;
  }
  if (cursor < texto.length) {
    pedacos.add(TextSpan(text: texto.substring(cursor), style: base));
  }
  return TextSpan(children: pedacos);
}
