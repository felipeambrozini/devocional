import 'dart:async';

import 'package:flutter/material.dart';

import '../data/canon.dart';
import '../data/conteudo.dart';
import '../data/estado.dart';
import '../data/modelos.dart';
import '../theme.dart';
import 'biblia.dart';
import 'comuns.dart';

/// Busca no texto da versão escolhida.
///
/// Os achados chegam por stream e aparecem conforme os livros são lidos, então a
/// tela mostra Gênesis enquanto o resto ainda carrega, em vez de travar até o fim.
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
  String _termoBuscado = '';

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
      _buscando = true;
      _termoBuscado = termo;
    });

    _assinatura = Conteudo.instancia.buscar(versao, termo).listen(
      (achado) {
        if (!mounted) return;
        setState(() => _achados.add(achado));
      },
      onDone: () {
        if (mounted) setState(() => _buscando = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final versao = EscopoDoEstado.de(context).versao;

    return LarguraDeLeitura(
      child: Scaffold(
        appBar: AppBar(title: Text('Buscar em ${versao.sigla}')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controle,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(versao),
                decoration: InputDecoration(
                  hintText: 'Palavra ou expressão',
                  prefixIcon: const Icon(Icons.search, color: Cores.begeSuave),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _buscar(versao),
                  ),
                ),
              ),
            ),
            if (_termoBuscado.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${_achados.length} ${_achados.length == 1 ? 'resultado' : 'resultados'}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 10),
                    if (_buscando)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _termoBuscado.isEmpty
                  ? const AvisoVazio(
                      icone: Icons.search,
                      titulo: 'Busque um versículo',
                      detalhe: 'A busca ignora acentos e maiúsculas.',
                    )
                  : _achados.isEmpty && !_buscando
                  ? AvisoVazio(
                      icone: Icons.search_off,
                      titulo: 'Nada encontrado',
                      detalhe: 'Nenhum versículo com "$_termoBuscado".',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: _achados.length,
                      separatorBuilder: (_, _) => const Divider(height: 18),
                      itemBuilder: (context, i) => _ItemDeAchado(
                        achado: _achados[i],
                        termo: _termoBuscado,
                      ),
                    ),
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
              style: tema.titleSmall?.copyWith(color: Cores.douradoClaro),
            ),
            const SizedBox(height: 5),
            Text.rich(
              _destacar(achado.texto, termo, tema),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Realça as ocorrências do termo, comparando sem acento para que buscar
  /// "coracao" destaque "coração" no texto original.
  TextSpan _destacar(String texto, String termo, TextTheme tema) {
    final base = tema.bodyMedium?.copyWith(height: 1.5);
    final forte = base?.copyWith(
      color: Cores.douradoClaro,
      fontWeight: FontWeight.w700,
    );
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
}
