import 'dart:async';

import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import 'biblia.dart';
import 'comuns.dart';
import 'devocional.dart';

/// Busca no texto da Bíblia e nos devocionais de Spurgeon, em duas abas.
///
/// Os achados da Bíblia chegam por stream e aparecem conforme os livros são
/// lidos, então a tela mostra Gênesis enquanto o resto ainda carrega, em vez
/// de travar até o fim. Os devocionais são só 366+366 registros já cacheados
/// por completo depois da primeira leitura (`Conteudo.buscarDevocionais`,
/// bem mais barato que varrer a Bíblia), então essa aba não precisa de
/// stream nem de teto de resultados.
class TelaBusca extends StatefulWidget {
  const TelaBusca({super.key});

  @override
  State<TelaBusca> createState() => _TelaBuscaState();
}

class _TelaBuscaState extends State<TelaBusca> {
  final _controle = TextEditingController();
  final _achados = <Achado>[];
  StreamSubscription<Achado>? _assinatura;
  bool _buscando = false;
  bool _erro = false;
  String _termoBuscado = '';

  /// Não nula quando o termo digitado é, ele mesmo, uma referência bíblica
  /// ("João 3:16"): a busca por texto não acha isso, porque o versículo não
  /// contém a própria referência.
  (Livro, int, int, int)? _referencia;

  List<AchadoDevocional> _achadosDevocionais = [];
  bool _buscandoDevocionais = false;
  bool _erroDevocionais = false;

  @override
  void dispose() {
    _assinatura?.cancel();
    _controle.dispose();
    super.dispose();
  }

  void _buscar(Versao versao) {
    final termo = _controle.text.trim();
    // Menos de três letras devolveria meia Bíblia e não ajudaria ninguém.
    if (termo.length < 3) return;

    // Cancelar a busca anterior interrompe a leitura dos livros restantes.
    _assinatura?.cancel();
    setState(() {
      _achados.clear();
      _achadosDevocionais = [];
      _buscando = true;
      _buscandoDevocionais = true;
      _erro = false;
      _erroDevocionais = false;
      _termoBuscado = termo;
      _referencia = faixaDeVersiculoDaReferencia(termo);
    });

    _assinatura = Conteudo.instancia
        .buscar(versao, termo)
        .listen(
          (achado) {
            if (mounted) setState(() => _achados.add(achado));
          },
          onDone: () {
            if (mounted) setState(() => _buscando = false);
          },
          onError: (Object _) {
            if (mounted) {
              setState(() {
                _erro = true;
                _buscando = false;
              });
            }
          },
        );

    _buscarDevocionais(termo);
  }

  Future<void> _buscarDevocionais(String termo) async {
    try {
      final achados = await Conteudo.instancia.buscarDevocionais(termo);
      if (mounted) {
        setState(() {
          _achadosDevocionais = achados;
          _buscandoDevocionais = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erroDevocionais = true;
          _buscandoDevocionais = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final versao = EscopoDoEstado.de(context).versao;

    // A LarguraDeLeitura fica no corpo, não em volta do Scaffold: envolvendo o
    // Scaffold, a própria AppBar ficava numa faixa de 720 px no meio da janela.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buscar'),
          bottom: const TabBar(tabs: [Tab(text: 'Bíblia'), Tab(text: 'Devocionais')]),
        ),
        body: LarguraDeLeitura(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controle,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscar(versao),
                  decoration: InputDecoration(
                    hintText: 'Palavra, expressão ou referência',
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar',
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _buscar(versao),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AbaBiblia(
                      termoBuscado: _termoBuscado,
                      versao: versao,
                      referencia: _referencia,
                      achados: _achados,
                      buscando: _buscando,
                      erro: _erro,
                    ),
                    _AbaDevocionais(
                      termoBuscado: _termoBuscado,
                      achados: _achadosDevocionais,
                      buscando: _buscandoDevocionais,
                      erro: _erroDevocionais,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbaBiblia extends StatelessWidget {
  const _AbaBiblia({
    required this.termoBuscado,
    required this.versao,
    required this.referencia,
    required this.achados,
    required this.buscando,
    required this.erro,
  });

  final String termoBuscado;
  final Versao versao;
  final (Livro, int, int, int)? referencia;
  final List<Achado> achados;
  final bool buscando;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    if (erro) return const AvisoDeErro();
    if (termoBuscado.isEmpty) {
      return const AvisoVazio(
        icone: Icons.search,
        titulo: 'Busque um versículo',
        detalhe: 'A busca ignora acentos e maiúsculas.',
      );
    }
    if (achados.isEmpty && referencia == null && !buscando) {
      return AvisoVazio(
        icone: Icons.search_off,
        titulo: 'Nada encontrado',
        detalhe: 'Nenhum versículo com "$termoBuscado" em ${versao.sigla}.',
      );
    }

    final temReferencia = referencia != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              // A busca para no teto e a lista fica cortada. Dizer só "300
              // resultados" faria parecer que são exatamente 300 na Bíblia
              // inteira, quando na verdade a contagem parou ali.
              Expanded(
                child: Text(
                  achados.length >= Conteudo.limiteDeBusca
                      ? 'Primeiros ${Conteudo.limiteDeBusca} resultados em ${versao.sigla}; há mais'
                      : '${achados.length} ${achados.length == 1 ? 'resultado' : 'resultados'} em ${versao.sigla}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 10),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: achados.length + (temReferencia ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 18),
            itemBuilder: (context, i) {
              if (temReferencia && i == 0) {
                return _CartaoDeReferencia(referencia: referencia!);
              }
              final indice = temReferencia ? i - 1 : i;
              return _ItemDeAchado(achado: achados[indice], termo: termoBuscado);
            },
          ),
        ),
      ],
    );
  }
}

/// Card fixo no topo dos resultados quando o próprio termo digitado é uma
/// referência bíblica reconhecida, para ir direto ao versículo em vez de
/// depender da busca de texto — que nunca acharia isso, já que o corpo do
/// versículo não contém a própria referência.
class _CartaoDeReferencia extends StatelessWidget {
  const _CartaoDeReferencia({required this.referencia});

  final (Livro, int, int, int) referencia;

  @override
  Widget build(BuildContext context) {
    final (livro, capitulo, deVersiculo, ateVersiculo) = referencia;
    final cor = Theme.of(context).colorScheme;
    final rotulo = deVersiculo == ateVersiculo
        ? '${livro.nome} $capitulo:$deVersiculo'
        : '${livro.nome} $capitulo:$deVersiculo-$ateVersiculo';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaBiblia(
            livroInicial: livro.slug,
            capituloInicial: capitulo,
            destacar: (deVersiculo, ateVersiculo),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.arrow_forward, size: 18, color: cor.primary),
            const SizedBox(width: 10),
            Text(
              'Ir para $rotulo',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: cor.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDeAchado extends StatelessWidget {
  const _ItemDeAchado({required this.achado, required this.termo});

  final Achado achado;
  final String termo;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme;
    final tema = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaBiblia(
            livroInicial: achado.livro,
            capituloInicial: achado.capitulo,
            destacar: (achado.versiculo, achado.versiculo),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              achado.referencia,
              style: tema.titleSmall?.copyWith(color: cor.secondary),
            ),
            const SizedBox(height: 5),
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

class _AbaDevocionais extends StatelessWidget {
  const _AbaDevocionais({
    required this.termoBuscado,
    required this.achados,
    required this.buscando,
    required this.erro,
  });

  final String termoBuscado;
  final List<AchadoDevocional> achados;
  final bool buscando;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    if (erro) return const AvisoDeErro();
    if (termoBuscado.isEmpty) {
      return const AvisoVazio(
        icone: Icons.menu_book_outlined,
        titulo: 'Busque nos devocionais',
        detalhe: 'Manhã e Noite e Promessas de Deus, na voz de Spurgeon.',
      );
    }
    if (achados.isEmpty && !buscando) {
      return AvisoVazio(
        icone: Icons.search_off,
        titulo: 'Nada encontrado',
        detalhe: 'Nenhum devocional com "$termoBuscado".',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${achados.length} ${achados.length == 1 ? 'resultado' : 'resultados'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 10),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: achados.length,
            separatorBuilder: (_, _) => const Divider(height: 18),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${leitura.rotulo} · ${dataLonga(data)}',
              style: tema.titleSmall?.copyWith(color: cor.secondary),
            ),
            if (achado.titulo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                achado.titulo,
                style: tema.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: cor.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 5),
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
  final forte = base?.copyWith(color: cor.secondary, fontWeight: FontWeight.w700);
  final textoSemAcento = Conteudo.normalizar(texto);
  final termoSemAcento = Conteudo.normalizar(termo);

  final pedacos = <TextSpan>[];
  var cursor = 0;
  while (true) {
    final achou = textoSemAcento.indexOf(termoSemAcento, cursor);
    if (achou < 0) break;
    if (achou > cursor) {
      pedacos.add(TextSpan(text: texto.substring(cursor, achou), style: base));
    }
    final fim = achou + termoSemAcento.length;
    pedacos.add(TextSpan(text: texto.substring(achou, fim), style: forte));
    cursor = fim;
  }
  if (cursor < texto.length) {
    pedacos.add(TextSpan(text: texto.substring(cursor), style: base));
  }
  return TextSpan(children: pedacos);
}
