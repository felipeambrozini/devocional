import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../dados/canon.dart';
import '../dados/dia_da_leitura.dart';
import '../telas/biblia.dart';

/// Caminho da Bíblia aberta por cima de qualquer aba, como a epígrafe do
/// devocional, a faixa da leitura do dia ou um achado da busca a abrem:
/// `/ler/joao/3`, com `?versiculos=16` ou `?versiculos=16-18` quando há
/// versículos a destacar, e os parâmetros de [dia] quando a leitura veio de
/// um dia do cronograma ou de um plano (ver [DiaDaLeitura]). A rota mora em
/// `main.dart`.
String caminhoNaBiblia(
  String livro,
  int capitulo, {
  (int, int)? destacar,
  DiaDaLeitura? dia,
}) {
  final base = '/ler/$livro/$capitulo';
  final parametros = <String, String>{
    if (destacar != null)
      'versiculos': destacar.$1 == destacar.$2
          ? '${destacar.$1}'
          : '${destacar.$1}-${destacar.$2}',
    ...?dia?.parametros,
  };
  if (parametros.isEmpty) return base;
  return Uri(path: base, queryParameters: parametros).toString();
}

/// Livro, capítulo e faixa de versículos de [caminhoNaBiblia], a partir dos
/// pedaços da rota. `null` para livro inexistente ou capítulo fora do livro
/// (link velho ou digitado), para a rota mandar à aba Bíblia em vez de abrir
/// uma leitura errada. Uma faixa de versículos inválida só some: o capítulo
/// continua abrindo, sem destaque.
(String, int, (int, int)?)? leituraDoCaminho(
  String livro,
  String capitulo,
  String? versiculos,
) {
  final alvo = alvoDoLink('$livro.$capitulo');
  if (alvo == null) return null;
  final (slug, numero, _) = alvo;
  return (slug, numero, _faixaDoParametro(versiculos));
}

(int, int)? _faixaDoParametro(String? texto) {
  if (texto == null) return null;
  final partes = texto.split('-');
  if (partes.length > 2) return null;
  final de = int.tryParse(partes.first);
  final ate = partes.length == 2 ? int.tryParse(partes.last) : de;
  if (de == null || ate == null || de < 1 || ate < de) return null;
  return (de, ate);
}

/// Abre a Bíblia por cima da tela atual, com voltar para ela. Pelo
/// go_router quando há um (no app): a URL mostra a leitura, o F5 a reabre, e a
/// barra de baixo não fica marcando a aba de onde se veio. Sem go_router (um
/// widget testado sozinho num MaterialApp), o push direto de antes.
void abrirNaBiblia(
  BuildContext context,
  String livro,
  int capitulo, {
  (int, int)? destacar,
  DiaDaLeitura? dia,
}) {
  final roteador = GoRouter.maybeOf(context);
  if (roteador != null) {
    roteador.push(
      caminhoNaBiblia(livro, capitulo, destacar: destacar, dia: dia),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TelaBiblia(
        livroInicial: livro,
        capituloInicial: capitulo,
        destacar: destacar,
        dia: dia,
      ),
    ),
  );
}
