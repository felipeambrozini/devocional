import '../dados/canon.dart';
import '../dados/planos_nuvem.dart';
import 'abrir_na_biblia.dart';

/// Prefixo do app no site ([enderecoDoSite]). Na web o `base href` já o tira
/// antes de o go_router ver o caminho; no Android, um link do site aberto
/// pelo App Link chega inteiro (`/tabernaculo/devocional/manha?data=...`).
const _prefixoDoSite = '/tabernaculo';

final _idDePlano = RegExp(r'^[a-z0-9]+$');

/// A rota interna para um link do site, ou `null` quando [uri] já é uma rota
/// do app e não há nada a traduzir. Roda no redirect geral do go_router, em
/// toda plataforma, para o mesmo link cair na mesma tela no navegador e no
/// app instalado, aberto do zero ou já aberto:
///
/// - tira o prefixo `/tabernaculo`, mantendo o resto do caminho e a query;
/// - `?plano=<slug>-<id>` ([linkDoPlano]) vira `/plano/<id>`;
/// - `?ler=joao.3.16` ([linkDoVersiculo]) vira `/ler/joao/3?versiculos=16`.
///   Um `?ler` que não aponta para um capítulo existente só some, e o link
///   cai na Hoje.
///
/// `?plano` vence `?ler` se os dois vierem juntos, a mesma ordem de antes.
String? rotaDoLinkDoSite(Uri uri) {
  var caminho = uri.path;
  final temPrefixo =
      caminho == _prefixoDoSite || caminho.startsWith('$_prefixoDoSite/');
  if (temPrefixo) caminho = caminho.substring(_prefixoDoSite.length);
  if (caminho.isEmpty) caminho = '/';

  final parametros = uri.queryParameters;
  final plano = parametros['plano'];
  final ler = parametros['ler'];
  if (caminho == '/' && plano != null) {
    // O id vai para o caminho: só letras minúsculas e dígitos, como os de
    // [novoIdDePlano] e o `jesus` do plano fixo. Barra ou `?` de um link
    // adulterado levariam a outra rota.
    final id = idDoParametroDePlano(plano);
    return _idDePlano.hasMatch(id) ? '/plano/$id' : '/';
  }
  if (caminho == '/' && ler != null) {
    final alvo = alvoDoLink(ler);
    if (alvo == null) return '/';
    final (slug, capitulo, versiculo) = alvo;
    return caminhoNaBiblia(
      slug,
      capitulo,
      destacar: versiculo == null ? null : (versiculo, versiculo),
    );
  }
  if (!temPrefixo) return null;
  return Uri(path: caminho, query: uri.hasQuery ? uri.query : null).toString();
}
