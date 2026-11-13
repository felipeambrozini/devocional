import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../controladores/busca_controlador.dart';
import '../dados/conteudo.dart';
import '../estilo/espacamento.dart';
import '../estilo/tema.dart';
import '../widgets/widgets.dart';

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
                        DevocionalAbaDevocionais(
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

/// Realça as ocorrências do termo, comparando sem acento para que buscar
/// "coracao" destaque "coração" no texto original. Compartilhada pelos dois
/// tipos de resultado, Bíblia e devocionais.
TextSpan destacar(String texto, String termo, TextTheme tema, ColorScheme cor) {
  final base = tema.bodyMedium?.copyWith(height: 1.5);
  final forte = base?.copyWith(color: cor.secondary).comPeso(FontWeight.w700);
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
