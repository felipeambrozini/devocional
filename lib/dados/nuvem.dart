import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show
        ChangeNotifier,
        TargetPlatform,
        defaultTargetPlatform,
        kIsWeb,
        visibleForTesting;
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'estado.dart';
import 'lembretes.dart';
import 'planos_nuvem.dart';
import 'registro.dart';

/// Client ID Web do projeto (`client_type: 3` em `android/app/google-services.json`).
/// Sem passar isto ao `GoogleSignIn.instance.initialize`, o token que volta no
/// Android tem audiência do client Android, e o `signInWithCredential` do
/// Firebase rejeita — mesma exigência no iOS. Não é segredo (é o mesmo ID já
/// versionado no `google-services.json`), mas segue o padrão de
/// `--dart-define` das outras chaves para ficar num só lugar.
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

// ignore: deprecated_member_use
final _espacos = RegExp(r'\s+');

/// Chave do reCAPTCHA v3 que ativa o App Check na web (console do Firebase >
/// App Check > registrar o app Web, e o site key vem do console do
/// reCAPTCHA, https://www.google.com/recaptcha/admin). Mesmo caminho das
/// demais chaves: `--dart-define` no build, GitHub Secrets no CI.
///
/// Ausente (string vazia) enquanto o registro não é feito — [iniciar] então
/// não ativa o App Check, para não travar o app com uma chave inexistente
/// no meio da migração. Só a web depende de chave: Android usa o Play
/// Integrity e iOS o App Attest, ambos por atestação do sistema, sem chave
/// de app nenhuma.
const _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');

/// Liga o [Estado] a um depósito remoto sem que o Estado saiba disso.
///
/// Não há gancho novo em `estado.dart`: o Estado já é um ChangeNotifier e já
/// tem `exportar()`/`importar()`. Isto é só um ouvinte de fora, e por isso os
/// testes existentes continuam abrindo o Estado sem Firebase nenhum.
///
/// `puxar` e `empurrar` são funções, e não uma interface: são dois métodos, e
/// o teste passa duas closures em vez de escrever um Firebase falso.
class Sincronia {
  Sincronia({
    required this.estado,
    required this.puxar,
    required this.empurrar,
    this.nome = 'copia',
    this.puxarDoServidor,
    this.serializar,
    this.fundir,
    this.aoMudarSituacao,
    this.atraso = const Duration(seconds: 2),
  });

  final Estado estado;

  /// Identifica esta sincronia na marca de envio pendente
  /// (`sincronia_pendente_<nome>`): `copia`, `conversas`, `lembretes`,
  /// `planos` ou `livros`. O padrão serve aos testes de uma sincronia só.
  final String nome;
  final Future<String?> Function() puxar;
  final Future<void> Function(String copia) empurrar;

  /// O mesmo que [puxar], mas só do servidor: falha sem rede em vez de
  /// devolver o cache local do Firestore, que pode refletir uma escrita que o
  /// servidor nunca recebeu. É o que [garantirNaNuvem] usa. Sem ele (testes),
  /// vale o [puxar].
  final Future<String?> Function()? puxarDoServidor;

  /// O que sobe para a nuvem. Padrão: a cópia de segurança do [Estado].
  /// Domínios com vida própria, como o histórico de conversas, passam o
  /// próprio serializador (ver `serializarConversas` em `estado.dart`).
  final String Function()? serializar;

  /// O que fazer com o que veio de [puxar]. Padrão: fundir pela cópia com
  /// `importar()`. As conversas passam `fundirConversas`, que une por id.
  final Future<void> Function(String remota)? fundir;

  final void Function()? aoMudarSituacao;

  /// Junta uma rajada num envio só: marcar cinco dias do cronograma seguidos
  /// é uma escrita, não cinco.
  final Duration atraso;

  String? _ultimaCopia;
  Timer? _pendente;

  /// Se um puxar+fundir já deu certo. Enquanto não deu, nada sobe: o local
  /// ainda não absorveu o que a conta tem, e empurrar o campo inteiro (o
  /// `mergeFields` substitui o campo todo) apagaria o dela, principalmente
  /// num navegador novo, sem cache persistente.
  bool _puxou = false;

  /// A cópia que o [_pendente] ainda não enviou. Vive fora da closure do
  /// `Timer` para que [despejar] saiba o que enviar no logout.
  String? _pendenteCopia;

  /// A última cópia que o servidor confirmou (o `empurrar` resolveu). Ao
  /// contrário de [_ultimaCopia], nunca vem de uma comparação com o puxar,
  /// que pode ter lido o cache local do Firestore. É a base de [emDia].
  String? _confirmada;

  /// Marcado por [parar]. Uma puxada ou um envio que estavam esperando a rede
  /// conferem isto ao voltar: depois de parada (o Sair limpou o aparelho, a
  /// conta trocou), a sincronia não funde, não ouve e não envia mais nada.
  bool _parada = false;

  /// O último conteúdo da conta que este aparelho já absorveu (fundiu). Se o
  /// servidor ainda devolve isto, ou o que [_confirmada] guarda, nada novo
  /// chegou de outro aparelho, e fundir de novo só reviveria uma remoção
  /// local ainda não confirmada: a fusão soma e nunca apaga.
  String? _ultimaRemota;

  /// Prefixo das marcas de envio pendente, que o Sair apaga todas de uma vez
  /// (ver `Estado.limparDadosPessoais`).
  static const prefixoDaMarca = 'sincronia_pendente_';

  String get _chaveDaMarca => '$prefixoDaMarca$nome';

  /// Grava (ou apaga) a marca de que há um estado local que a conta não
  /// confirmou. Persistente: sobrevive a fechar o app e é o que faz o próximo
  /// abrir reenviar, em vez de esperar uma mudança que talvez nunca venha (e
  /// o navegador pode limpar o armazenamento antes disso). Falhar ao gravar a
  /// marca não derruba nada.
  Future<void> _marcarPendente(bool pendente) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pendente) {
        await prefs.setBool(_chaveDaMarca, true);
      } else {
        await prefs.remove(_chaveDaMarca);
      }
    } catch (erro, pilha) {
      Registro.erro('Nuvem.marca', erro, pilha);
    }
  }

  Future<bool> _haMarca() async {
    try {
      return (await SharedPreferences.getInstance()).containsKey(_chaveDaMarca);
    } catch (erro, pilha) {
      Registro.erro('Nuvem.marca', erro, pilha);
      return false;
    }
  }

  /// Reenvia o estado atual se um envio anterior falhou (há marca). Passa pelo
  /// mesmo caminho de [_enviar]: respeita [_parada] e puxa antes de subir
  /// quando o puxar+fundir ainda não deu certo. A marca sai quando o servidor
  /// confirma; falhando, fica para a próxima abertura ou retomada.
  Future<void> reenviarSePendente() async {
    if (_parada || !await _haMarca() || _parada) return;
    await _enviar(_serializar());
  }

  String _serializar() => serializar?.call() ?? estado.exportar();

  Future<void> _fundir(String remota) =>
      fundir?.call(remota) ?? estado.importar(remota);

  /// Puxa e funde ANTES de passar a ouvir. Nesta ordem nada se perde nos dois
  /// sentidos: quem entra num navegador novo recebe o que já estava na conta,
  /// e o que só existe neste aparelho sobe logo depois, no envio que o
  /// [_aoMudar] do fim dispara.
  Future<void> comecar() async {
    _ultimaCopia = _serializar();
    await _puxarEFundir();
    if (_parada) return;
    estado.addListener(_aoMudar);
    await reenviarSePendente();
    if (_parada) return;
    _aoMudar();
  }

  /// Devolve se o puxar+fundir deu certo (agora ou antes). Falhar aqui (sem
  /// rede, Firestore recusou, cópia ilegível) não pode derrubar nada: o local
  /// fica intacto, nada sobe, e o próximo envio tenta puxar de novo.
  Future<bool> _puxarEFundir() async {
    try {
      final remota = await puxar();
      if (_parada) return false;
      if (remota != null) {
        await _fundir(remota);
        _ultimaRemota = remota;
      }
      // A partir daqui a base de comparação é o que a CONTA tem, não o que
      // este aparelho tinha. Sem esta linha, o que só existe aqui só subia
      // quando a fusão trazia novidade de lá: com a conta ainda sem cópia
      // (`remota` null), `_aoMudar` comparava o local com ele mesmo, não via
      // diferença e nada subia: um plano criado antes de entrar na conta
      // ficava preso no aparelho, e a web, na mesma conta, nunca o via.
      if (!_mesmoConteudo(remota, _serializar())) _ultimaCopia = null;
      _puxou = true;
    } catch (erro, pilha) {
      Registro.erro('Nuvem.puxar', erro, pilha);
    }
    return _puxou;
  }

  void parar() {
    _parada = true;
    estado.removeListener(_aoMudar);
    _pendente?.cancel();
    _pendente = null;
    _pendenteCopia = null;
  }

  /// Comparar a cópia inteira é o filtro mais barato daqui (alguns KB de
  /// string) e resolve dois problemas com uma linha: não escreve por
  /// preferência de aparelho, que não entra na cópia (ver `exportar()` em
  /// `estado.dart`), e não escreve em resposta ao próprio `importar()`, que
  /// também notifica. Sem isto, o `notifyListeners` de dentro do `importar`
  /// viraria um envio, e o envio viraria outro importar.
  void _aoMudar() {
    if (_parada) return;
    final copia = _serializar();
    if (copia == _ultimaCopia) return;
    _pendente?.cancel();
    _pendenteCopia = copia;
    _pendente = Timer(atraso, _enviarPendente);
  }

  void _enviarPendente() {
    _pendente = null;
    final copia = _pendenteCopia;
    _pendenteCopia = null;
    if (copia != null) _enviar(copia);
  }

  /// Sem puxar+fundir feito, tenta de novo antes de subir e não sobe se
  /// falhar (o pendente se perde, mas a próxima mudança o recalcula). Depois
  /// de uma retomada tardia a cópia é refeita: a fusão pode ter trazido o que
  /// a conta tinha.
  Future<void> _transmitir(String copia) async {
    final aEnviar = _puxou ? copia : await _copiaDepoisDePuxar();
    if (_parada) return;
    if (aEnviar == null) {
      // Não deu para puxar, então nada subiu: segue pendente.
      await _marcarPendente(true);
      return;
    }
    if (aEnviar == _ultimaCopia) {
      // A conta já tem exatamente isto: nada a reenviar.
      await _marcarPendente(false);
      return;
    }
    await empurrar(aEnviar);
    _confirmar(aEnviar);
  }

  Future<String?> _copiaDepoisDePuxar() async =>
      await _puxarEFundir() && !_parada ? _serializar() : null;

  bool _jaAbsorvida(String remota) =>
      (_ultimaRemota != null && _mesmoConteudo(remota, _ultimaRemota!)) ||
      (_confirmada != null && _mesmoConteudo(remota, _confirmada!));

  /// O servidor confirmou [copia]: vira a base das duas comparações, e um
  /// pendente com o mesmo conteúdo não precisa mais subir.
  void _confirmar(String copia) {
    unawaited(_marcarPendente(false));
    _ultimaCopia = copia;
    _confirmada = copia;
    if (_pendenteCopia == copia) {
      _pendente?.cancel();
      _pendente = null;
      _pendenteCopia = null;
    }
  }

  /// Se o servidor confirmou exatamente o que o aparelho tem agora. O Sair
  /// confere isto logo antes de parar as sincronias: uma mudança feita
  /// durante a espera do [garantirNaNuvem] deixa a sincronia fora de dia, e
  /// limpar nesse estado a apagaria sem subir.
  bool get emDia => _confirmada != null && _serializar() == _confirmada;

  /// Envia agora o que ainda aguardava o debounce, sem esperar o [atraso].
  ///
  /// Usado quando o app vai para segundo plano: um app fechado em seguida
  /// mataria o timer, e uma mudança feita segundos antes ficaria presa nele.
  /// A espera tem teto e o erro é engolido: sem rede, o Firestore fica com o
  /// envio pendente até reconectar, o dado continua no aparelho e a próxima
  /// mudança tenta de novo. O Sair, que precisa da confirmação, usa
  /// [garantirNaNuvem].
  Future<void> despejar() async {
    final pendente = _pendente;
    if (pendente == null) return;
    pendente.cancel();
    _pendente = null;
    final copia = _pendenteCopia;
    _pendenteCopia = null;
    if (copia == null) return;
    try {
      await _transmitir(copia).timeout(const Duration(seconds: 5));
    } catch (erro, pilha) {
      Registro.erro('Nuvem.despejar', erro, pilha);
    }
    aoMudarSituacao?.call();
  }

  /// Garante que a conta tem o estado atual, para o Sair poder limpar o
  /// aparelho sem perder nada. Ao contrário de [despejar], não depende da fila
  /// do debounce e **propaga** o erro: falha ou prazo estourado interrompem o
  /// Sair.
  ///
  /// Sempre puxa do servidor ([puxarDoServidor]) e envia o estado atual,
  /// esperando a confirmação, mesmo sem nada na fila. Puxar do servidor, e
  /// não do cache, é o que garante que a conta tem mesmo o que o aparelho tem
  /// (o cache pode refletir uma escrita que nunca subiu). Se o servidor
  /// trouxe algo que este aparelho ainda não absorveu, funde antes de enviar,
  /// para não pisar num envio mais novo de outro aparelho (o `mergeFields`
  /// troca o campo inteiro). Se não trouxe ([_ultimaRemota]), não funde: a
  /// fusão só soma, e devolveria um favorito tirado segundos antes.
  ///
  /// O prazo cobre o puxar e o envio: sem rede, o Firestore segura a escrita
  /// até reconectar, e o Sair não pode ficar mudo esperando.
  Future<void> garantirNaNuvem({
    Duration prazo = const Duration(seconds: 15),
  }) async {
    _pendente?.cancel();
    _pendente = null;
    _pendenteCopia = null;
    try {
      await _garantir().timeout(prazo);
    } catch (_) {
      // O Sair parou e a sessão continua: a mudança volta para a fila, como
      // qualquer outra, em vez de esperar a próxima.
      _aoMudar();
      rethrow;
    } finally {
      aoMudarSituacao?.call();
    }
  }

  Future<void> _garantir() async {
    final remota = await (puxarDoServidor ?? puxar)();
    if (_parada) throw StateError('Sincronia parada durante o Sair');
    if (remota != null && !_jaAbsorvida(remota)) {
      await _fundir(remota);
      // Um `_garantir` antigo não pode enviar o aparelho já limpo.
      if (_parada) throw StateError('Sincronia parada durante o Sair');
      _ultimaRemota = remota;
    }
    _puxou = true;
    final copia = _serializar();
    await empurrar(copia);
    _confirmar(copia);
  }

  Future<void> _enviar(String copia) async {
    try {
      await _transmitir(copia);
    } catch (erro, pilha) {
      // Sem rede, ou regra recusou. O dado continua no aparelho e a próxima
      // mudança tenta de novo; falhar aqui não pode derrubar nada.
      Registro.erro('Nuvem.enviar', erro, pilha);
      // Parada (Sair, troca de conta): a marca seria de uma conta que já não
      // é a deste aparelho.
      if (!_parada) await _marcarPendente(true);
    }
    aoMudarSituacao?.call();
  }
}

/// Se a cópia que veio da conta diz a mesma coisa que a local, sem depender
/// da ordem das chaves — o Firestore devolve os campos de um mapa em outra
/// ordem, e comparar as strings acusaria diferença a cada entrada na conta,
/// numa escrita à toa por login. Conta ainda sem cópia (`remota` null) nunca
/// é igual: é justamente o que precisa subir.
///
/// Só [Sincronia.comecar] usa; o caminho quente (`_aoMudar`, a cada mudança
/// do Estado) continua comparando as strings, que é mais barato e ali basta:
/// dos dois lados a cópia saiu do mesmo serializador.
bool _mesmoConteudo(String? remota, String local) {
  if (remota == null) return false;
  try {
    return _mesmoValor(json.decode(remota), json.decode(local));
  } on FormatException {
    // Cópia da conta ilegível: tratar como diferente deixaria o local subir
    // por cima dela, que é o que o resto do arquivo já faz com cópia torta.
    return false;
  }
}

bool _mesmoValor(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final chave in a.keys) {
      if (!b.containsKey(chave) || !_mesmoValor(a[chave], b[chave])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_mesmoValor(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// A ordem segura de apagar a conta. Para as sincronias ANTES de tudo, senão
/// uma mudança pendente recriaria o documento recém-apagado. Reautentica antes
/// de apagar, quando o login é antigo, para que um popup cancelado ou falho
/// não deixe o documento apagado e a conta de pé. Se algo falha, as sincronias
/// voltam: o usuário segue logado e o app segue sincronizando.
Future<void> apagarContaEmOrdem({
  required void Function() pararSincronias,
  required void Function() religarSincronias,
  required bool precisaReautenticar,
  required Future<void> Function() reautenticar,
  required Future<void> Function() apagar,
}) async {
  pararSincronias();
  try {
    if (precisaReautenticar) await reautenticar();
    await apagar();
  } catch (_) {
    religarSincronias();
    rethrow;
  }
}

/// O Sair parou antes de limpar o aparelho: algo não chegou à conta (sem
/// rede, prazo estourado, Firestore recusou). A sessão continua e nada foi
/// apagado. [causa] é o erro de origem, para o registro.
class SairDaContaFalhou implements Exception {
  const SairDaContaFalhou(this.causa);

  final Object causa;

  @override
  String toString() => 'SairDaContaFalhou: $causa';
}

/// Garante as [sincronias] na nuvem e confere que ficaram em dia: uma
/// mudança feita durante a espera é garantida de novo, até duas voltas a mais.
/// Se ainda assim o aparelho não para de mudar, ou falta uma sincronia,
/// lança: o Sair não pode limpar o que não subiu.
Future<void> _garantirTodas(List<Sincronia?> sincronias) async {
  if (sincronias.contains(null)) {
    // Com consentimento e conta aberta, as cinco sempre estão ligadas (ver
    // `Nuvem._iniciarSincronias`); faltar uma é não ter como garantir.
    throw StateError('Sincronias da conta desligadas');
  }
  var aGarantir = sincronias.cast<Sincronia>();
  for (var volta = 0; volta < 3; volta++) {
    await Future.wait([for (final s in aGarantir) s.garantirNaNuvem()]);
    aGarantir = [for (final s in aGarantir) if (!s.emDia) s];
    if (aGarantir.isEmpty) return;
  }
  throw StateError('O aparelho continuou mudando durante o Sair');
}

/// O Sair com as sincronias de verdade, sem Firebase: [Nuvem.sair] passa as
/// cinco dela, o `_pararSincronias`, a limpeza do aparelho e o `signOut`.
///
/// Logo antes de parar as sincronias, sem nenhum `await` no meio, confere de
/// novo que todas seguem em dia: se algo mudou depois da última confirmação,
/// o Sair para ali, antes de apagar qualquer coisa. [limparAparelho] precisa
/// zerar a memória antes da primeira espera (ver [limparAoSair]): entre a
/// conferência, o parar e a limpeza não pode haver brecha para uma mudança.
Future<void> sairComSincronias({
  required List<Sincronia?> sincronias,
  required void Function() pararSincronias,
  required Future<void> Function() limparAparelho,
  required Future<void> Function() deslogar,
}) => sairEmOrdem(
  garantir: () => _garantirTodas(sincronias),
  limpar: () async {
    if (!sincronias.every((s) => s!.emDia)) {
      throw SairDaContaFalhou(
        StateError('O aparelho mudou depois da confirmação'),
      );
    }
    pararSincronias();
    await limparAparelho();
  },
  deslogar: deslogar,
);

/// A limpeza do aparelho no Sair: zera a memória do [estado] de forma
/// síncrona, antes de qualquer espera (é o que deixa `sairComSincronias`
/// parar as sincronias e limpar sem uma brecha em que uma mudança se perca),
/// e só depois cancela os lembretes que o sistema já agendou, se estavam
/// ligados. Cancelar depois, e não antes da conferência final, evita que um
/// Sair que falha deixe os lembretes deste aparelho desligados com a
/// preferência ligada. Falhar no cancelamento não interrompe a limpeza.
Future<void> limparAoSair(
  Estado estado, {
  required Future<void> Function() cancelarLembretes,
}) async {
  final lembretesLigados = estado.lembretesAtivos;
  final limpeza = estado.limparDadosPessoais();
  if (lembretesLigados) {
    try {
      await cancelarLembretes();
    } catch (erro, pilha) {
      Registro.erro('Nuvem.sair.lembretes', erro, pilha);
    }
  }
  await limpeza;
}

/// A ordem segura de sair da conta: primeiro [garantir] que a conta tem tudo,
/// e só com a confirmação [limpar] o pessoal do aparelho e [deslogar]. Se
/// [garantir] falha, nada mais acontece e o erro vira [SairDaContaFalhou]:
/// limpar sem a confirmação perderia o que só existe aqui.
Future<void> sairEmOrdem({
  required Future<void> Function() garantir,
  required Future<void> Function() limpar,
  required Future<void> Function() deslogar,
}) async {
  try {
    await garantir();
  } catch (erro, pilha) {
    Registro.erro('Nuvem.sair', erro, pilha);
    throw SairDaContaFalhou(erro);
  }
  await limpar();
  await deslogar();
}

/// Funde os lembretes que vieram da conta neste aparelho. O ligar e o desligar
/// vindos de outro aparelho precisam chegar ao agendamento local, não só à
/// preferência.
Future<void> fundirLembretesDaConta(Estado estado, String remota) async {
  final estavaLigado = estado.lembretesAtivos;
  final mudou = await estado.fundirLembretes(remota);
  if (!mudou) return;
  if (!estado.lembretesAtivos) {
    if (estavaLigado) await Lembretes.instancia.cancelar();
    return;
  }
  // O horário ligado veio de outro aparelho: este pode nunca ter pedido a
  // permissão de notificação. Sem checar aqui, agendar() roda no vácuo: grava
  // o horário mas nada aparece neste aparelho. Não desliga `lembretesAtivos`
  // aqui: é a preferência compartilhada entre aparelhos, e derrubá-la também
  // desligaria os que já têm permissão; a falta de permissão é só deste
  // aparelho.
  if (!await Lembretes.instancia.pedirPermissao()) return;
  TimeOfDay hora(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
  await Lembretes.instancia.agendar(
    manha: hora(estado.minutosLembreteManha),
    promessas: hora(estado.minutosLembretePromessas),
    leitura: hora(estado.minutosLembreteLeitura),
    noite: hora(estado.minutosLembreteNoite),
  );
}

/// Conta Google e cópia na nuvem. Um valor só para o app inteiro, como
/// `Lembretes.instancia` em `lib/dados/lembretes.dart` — e pela mesma razão:
/// os botões de Entrar e Sair (Hoje e plano compartilhado) não têm como
/// compartilhar uma instância sem um Provider inteiro só para isto.
///
/// Um documento por usuário (`usuarios/{uid}`) com o mesmo mapa que
/// `exportar()` já produz. `importar()` funde e nunca apaga, então uma
/// remoção feita num navegador não se propaga — se um favorito apagado
/// "ressuscitar" na prática, o caminho é uma `versao: 2` da cópia com
/// lápides, e `importar` respeitando-as.
class Nuvem extends ChangeNotifier {
  static Nuvem instancia = Nuvem._();
  Nuvem._();

  static const _colecao = 'usuarios';
  static const _loginRecente = Duration(minutes: 5);

  Sincronia? _sincronia;

  /// Se o `GoogleSignIn` do `google_sign_in` já foi inicializado neste
  /// processo. A documentação do plugin pede uma única chamada de
  /// `initialize`, e a primeira vez acontece no primeiro toque em "Entrar",
  /// não na inicialização do app: fora da web não há sinal de que a conta
  /// será pedida, e evitar a ida ao plugin nativo de graça mantém a abertura
  /// do app independente dele.
  bool _googlePronto = false;

  /// A segunda sincronia, só das conversas do chat. Vive no mesmo documento
  /// `usuarios/{uid}` que a cópia, no campo `conversas`, mas com serializador
  /// próprio (`serializarConversas`): o histórico não entra na cópia de
  /// segurança que `exportar()` produz. Ver o comentário daquele método.
  Sincronia? _sincroniaDeConversas;
  Sincronia? _sincroniaDeLembretes;

  /// Planos de leitura do usuário (criados no celular/web). Vivem no mesmo
  /// documento `usuarios/{uid}` no campo `planos`, com serializador próprio
  /// (`serializarPlanos`): sem isto um plano criado no celular nunca aparecia
  /// na web, mesmo com a mesma conta — era só local.
  Sincronia? _sincroniaDePlanos;

  /// Posição, capítulos lidos, leituras concluídas e destaques dos livros da
  /// biblioteca, no campo `livros` do mesmo documento: a leitura é da conta, e
  /// celular e web logados mostram a mesma coisa.
  Sincronia? _sincroniaDeLivros;

  /// O Estado passado a [iniciar], para religar as sincronias quando o
  /// apagar da conta é desfeito.
  Estado? _estado;
  StreamSubscription<User?>? _assinatura;
  bool _pronta = false;

  /// Se o Firebase Auth já disse se há sessão salva — o primeiro evento de
  /// `authStateChanges`, que chega logo depois do `initializeApp` (na web,
  /// assim que a sessão volta do armazenamento do navegador). É isto, e não
  /// [_pronta], que libera nome, foto e [logado]: a identidade não depende do
  /// App Check, só o Firestore depende. Com os dois no mesmo portão, a Hoje
  /// dizia "Bom dia" sem o nome por até 30 s a cada abertura, e parecia que a
  /// conta tinha saído.
  bool _sessaoConhecida = false;
  StreamSubscription<User?>? _assinaturaDaSessao;

  /// Só para testes de widget: força [logado] sem depender de um Firebase de
  /// verdade, que os testes não inicializam. null (padrão) deixa a resposta
  /// de verdade, vinda do Firebase.
  @visibleForTesting
  bool? logadoForcado;

  bool get logado =>
      logadoForcado ??
      (_sessaoConhecida && FirebaseAuth.instance.currentUser != null);

  /// Se [iniciar] já terminou (Firebase + App Check prontos) — o que libera
  /// o Firestore, não a identidade (ver [_sessaoConhecida]).
  bool get pronta => _pronta;

  /// A sessão salva ainda não voltou: sem override de teste e sem o primeiro
  /// evento do Auth. Antes disso [logado] vale false por falta de resposta,
  /// não por resposta, e o cabeçalho mostra espera em vez de um "Entrar" que
  /// sumiria sozinho (ver `TabernaculoBotaoDeConta` em `lib/widgets/botao_de_conta.dart`).
  bool get carregandoConta =>
      carregandoContaForcado ?? (logadoForcado == null && !_sessaoConhecida);

  /// Só para testes de widget: força [carregandoConta], como [logadoForcado]
  /// faz com [logado]. null (padrão) deixa a resposta de verdade.
  @visibleForTesting
  bool? carregandoContaForcado;
  String? get email =>
      emailForcado ??
      (_sessaoConhecida ? FirebaseAuth.instance.currentUser?.email : null);

  /// Só para testes de widget: força [email], como [logadoForcado] faz com
  /// [logado].
  @visibleForTesting
  String? emailForcado;

  /// Se [entrar] está em andamento, para os botões de "Entrar" mostrarem um
  /// spinner e ficarem desabilitados — sem isto o toque parecia não fazer
  /// nada enquanto o seletor de conta ou a troca de token com o Firebase
  /// demoravam. Um flag só, e não um por botão: os três botões que chamam
  /// [entrar] (ver `entrarNaConta` em `lib/funcoes/conta_acoes.dart`) apontam para
  /// a mesma instância, então todos refletem o mesmo login em andamento.
  bool _entrando = false;
  bool get entrando => _entrando;

  /// O uid de quem está com a conta aberta, para saber se é o criador de um
  /// plano compartilhado (ver `excluirPlano`/`sairDoPlano` em
  /// `lib/funcoes/planos_acoes.dart`). null sem conta, ou antes de [iniciar].
  String? get uid =>
      uidForcado ??
      (_sessaoConhecida ? FirebaseAuth.instance.currentUser?.uid : null);

  /// Só para testes: força [uid], como [logadoForcado] faz com [logado].
  @visibleForTesting
  String? uidForcado;

  /// Primeiro nome de quem entrou, para a saudação de `TabernaculoCabecalhoDaHoje`
  /// (`lib/widgets/cabecalho_da_hoje.dart`). null sem conta, ou se a conta Google não devolveu nome.
  String? get primeiroNome => nome?.trim().split(_espacos).firstOrNull;

  /// O nome completo da conta Google, para o cabeçalho do perfil. null sem
  /// conta, ou se a conta não devolveu nome.
  String? get nome =>
      nomeForcado ??
      (_sessaoConhecida
          ? FirebaseAuth.instance.currentUser?.displayName
          : null);

  /// Só para testes de widget: força [nome] (e com ele [primeiroNome]).
  @visibleForTesting
  String? nomeForcado;

  /// Avatar da conta: a foto do Google quando há, senão a inicial do nome
  /// (ver `TabernaculoCabecalhoDaHoje`). Sem upload próprio: o app nunca
  /// hospeda foto, só exibe a da conta.
  String? get fotoUrl =>
      _sessaoConhecida ? FirebaseAuth.instance.currentUser?.photoURL : null;

  /// Só o núcleo do Firebase (`Firebase.initializeApp`), sem o resto de
  /// [iniciar] — para quem precisa do app default já registrado antes de
  /// continuar (Auth e Firestore lançam sem isto). Idempotente:
  /// `Firebase.apps` vazio é o sinal de que ainda não rodou; chamar de novo
  /// depois lançaria "app duplicado".
  Future<void> iniciarFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Só identidade, sem Firestore: pode ouvir antes do App Check. Qualquer
    // mudança de conta (a sessão que volta, entrar, sair) redesenha a UI.
    _assinaturaDaSessao = FirebaseAuth.instance.authStateChanges().listen((_) {
      _sessaoConhecida = true;
      notifyListeners();
    });
  }

  /// Prepara o Firebase e liga a sincronização ao estado de login. Chamar uma
  /// vez, em `main.dart`.
  ///
  /// Falhar aqui (projeto ainda não configurado, sem rede) não pode impedir o
  /// app de abrir — mesma regra do fuso horário em `lembretes.dart`. Por isso
  /// o erro só é engolido, nunca propagado.
  Future<void> _assegurarTokenAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(_recaptchaSiteKey),
        providerAndroid: const AndroidPlayIntegrityProvider(),
        // Com fallback para DeviceCheck: o app aceita iOS 13 (Podfile), e
        // App Attest sozinho exige iOS 14+.
        providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      // activate() resolve assim que o provedor é registrado, não quando o
      // primeiro token chega — a troca com o reCAPTCHA/Play Integrity ainda
      // é assíncrona. Sem este getToken() explícito, quem assina
      // authStateChanges (aqui e em PlanosNaNuvem) e já tem sessão em cache
      // dispara a primeira consulta ao Firestore antes do token existir, e
      // o Firestore nega com PERMISSION_DENIED.
      //
      // Com timeout: sem rede ou com o provedor emperrado, `getToken()`
      // pode nunca resolver, e sem prazo `_pronta` nunca vira true — a
      // sincronia, os planos e o admin ficam mudos para sempre em vez de
      // só começarem sem nuvem.
      await FirebaseAppCheck.instance.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
    } catch (erro, pilha) {
      // "App attestation failed" (iOS sem o provedor, simulador, device
      // bloqueado) é esperado em certas máquinas: vai só para o registro local.
      Registro.esperado('Nuvem.iniciar', erro, pilha);
    }
  }

  /// Pede o token do App Check. Na retomada do app basta `forcar: false`: o
  /// SDK devolve o cacheado e só renova se expirou, sem pagar uma atestação
  /// (avaliação do reCAPTCHA na web, Play Integrity no Android) a cada volta
  /// à aba. Depois de um PERMISSION_DENIED, que pode ter sido token vencido,
  /// o padrão `forcar: true` obriga uma atestação nova: sem isso o SDK
  /// devolveria o token ruim em cache. Se a atestação falha de verdade, isso
  /// só registra e segue: ninguém fica travado aqui esperando.
  Future<void> revalidarAppCheck({bool forcar = true}) async {
    try {
      await obterTokenAppCheck(
        forcar,
      ).timeout(const Duration(seconds: 10), onTimeout: () => null);
    } catch (erro, pilha) {
      Registro.esperado('Nuvem.revalidarAppCheck', erro, pilha);
    }
  }

  /// Só para testes: troca a ida ao Firebase App Check.
  @visibleForTesting
  Future<String?> Function(bool forcar) obterTokenAppCheck = (forcar) =>
      FirebaseAppCheck.instance.getToken(forcar);

  Future<void> iniciar(Estado estado) async {
    try {
      await iniciarFirebase();
    } catch (erro, pilha) {
      Registro.erro('Nuvem.iniciar', erro, pilha);
      return;
    }

    // Prova ao Firestore e ao Auth que quem pede é o próprio app, não um
    // cliente forjado com as mesmas chaves públicas. Erro aqui (chave errada,
    // domínio ainda não liberado no console) não pode impedir o app de abrir
    // — mesma regra do Firebase.initializeApp acima.
    // O activate+getToken fica em _assegurarTokenAppCheck para a retomada
    // do app e as falhas de PERMISSION_DENIED poderem revalidar sem
    // duplicar a sequência.
    if (kIsWeb ? _recaptchaSiteKey.isNotEmpty : true) {
      await _assegurarTokenAppCheck();
    }

    _pronta = true;
    // Avisa já, sem esperar o primeiro evento do `authStateChanges` abaixo:
    // com sessão em cache ele chega logo, mas sem sessão (deslogado de
    // verdade) a UI saberia tarde que pode mostrar o "Entrar".
    notifyListeners();

    _estado = estado;
    _assinatura = FirebaseAuth.instance.authStateChanges().listen((usuario) {
      _pararSincronias();
      notifyListeners();
      // Sem consentimento neste aparelho nada sobe nem desce: quem já tinha
      // sessão aberta antes do pedido existir passa primeiro pelo diálogo
      // (ver `_pedirConsentimento` em main.dart), que chama [aoConsentir].
      if (usuario != null && estado.consentimentoDaNuvem) {
        _iniciarSincronias(estado, usuario.uid);
      }
    });
  }

  /// Liga as sincronias da conta já aberta assim que o consentimento chega.
  void aoConsentir() {
    final estado = _estado;
    final usuario = FirebaseAuth.instance.currentUser;
    if (estado == null || usuario == null || _sincronia != null) return;
    _iniciarSincronias(estado, usuario.uid);
    PlanosNaNuvem.instancia.aoConsentir();
  }

  void _pararSincronias() {
    _sincronia?.parar();
    _sincronia = null;
    _sincroniaDeConversas?.parar();
    _sincroniaDeConversas = null;
    _sincroniaDeLembretes?.parar();
    _sincroniaDeLembretes = null;
    _sincroniaDePlanos?.parar();
    _sincroniaDePlanos = null;
    _sincroniaDeLivros?.parar();
    _sincroniaDeLivros = null;
  }

  void _iniciarSincronias(Estado estado, String uid) {
    // Uma leitura só do documento para as cinco sincronias na primeira
    // tentativa: cada uma pega o próprio campo dela, em vez de cinco idas ao
    // Firestore por login. Quem precisa tentar de novo (o puxar falhou) lê o
    // documento outra vez, sem herdar o erro da leitura compartilhada.
    final documento = _lerDocumento(uid);
    Future<String?> Function() puxarDe(String campo) {
      var primeiraLeitura = true;
      return () {
        if (!primeiraLeitura) return _campo(_lerDocumento(uid), campo);
        primeiraLeitura = false;
        return _campo(documento, campo);
      };
    }

    // Para o Sair (`Sincronia.garantirNaNuvem`): só o servidor responde. O
    // cache local pode refletir uma escrita que nunca subiu.
    Future<String?> Function() doServidor(String campo) =>
        () => _campo(_lerDocumento(uid, soServidor: true), campo);

    final sincronia = Sincronia(
      estado: estado,
      nome: 'copia',
      puxar: puxarDe('copia'),
      puxarDoServidor: doServidor('copia'),
      empurrar: (copia) => _empurrarCampo(uid, 'copia', copia),
      aoMudarSituacao: notifyListeners,
    );
    _sincronia = sincronia;
    unawaited(sincronia.comecar());

    final sincroniaDeConversas = Sincronia(
      estado: estado,
      serializar: estado.serializarConversas,
      fundir: estado.fundirConversas,
      nome: 'conversas',
      puxar: puxarDe('conversas'),
      puxarDoServidor: doServidor('conversas'),
      empurrar: (copia) => _empurrarCampo(uid, 'conversas', copia),
      aoMudarSituacao: notifyListeners,
    );
    _sincroniaDeConversas = sincroniaDeConversas;
    unawaited(sincroniaDeConversas.comecar());

    final sincroniaDeLembretes = Sincronia(
      estado: estado,
      serializar: estado.serializarLembretes,
      fundir: (remota) => fundirLembretesDaConta(estado, remota),
      nome: 'lembretes',
      puxar: puxarDe('lembretes'),
      puxarDoServidor: doServidor('lembretes'),
      empurrar: (copia) => _empurrarCampo(uid, 'lembretes', copia),
      aoMudarSituacao: notifyListeners,
    );
    _sincroniaDeLembretes = sincroniaDeLembretes;
    unawaited(sincroniaDeLembretes.comecar());

    final sincroniaDePlanos = Sincronia(
      estado: estado,
      serializar: estado.serializarPlanos,
      fundir: estado.fundirPlanos,
      nome: 'planos',
      puxar: puxarDe('planos'),
      puxarDoServidor: doServidor('planos'),
      empurrar: (copia) => _empurrarCampo(uid, 'planos', copia),
      aoMudarSituacao: notifyListeners,
    );
    _sincroniaDePlanos = sincroniaDePlanos;
    unawaited(sincroniaDePlanos.comecar());

    final sincroniaDeLivros = Sincronia(
      estado: estado,
      serializar: estado.serializarLeituraDeLivros,
      fundir: estado.fundirLeituraDeLivros,
      nome: 'livros',
      puxar: puxarDe('livros'),
      puxarDoServidor: doServidor('livros'),
      empurrar: (copia) => _empurrarCampo(uid, 'livros', copia),
      aoMudarSituacao: notifyListeners,
    );
    _sincroniaDeLivros = sincroniaDeLivros;
    unawaited(sincroniaDeLivros.comecar());
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    _assinaturaDaSessao?.cancel();
    _sincronia?.parar();
    _sincroniaDeConversas?.parar();
    _sincroniaDeLembretes?.parar();
    _sincroniaDePlanos?.parar();
    _sincroniaDeLivros?.parar();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _lerDocumento(
    String uid, {
    bool soServidor = false,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(uid)
        .get(soServidor ? const GetOptions(source: Source.server) : null);
    return doc.data();
  }

  /// O [campo] do documento como JSON, ou null se a conta ainda não o tem.
  /// Guardado como mapa no Firestore, não como string: assim a cópia se lê
  /// no console do Firebase quando alguém disser "sumiu uma nota".
  Future<String?> _campo(
    Future<Map<String, dynamic>?> documento,
    String campo,
  ) async {
    final valor = (await documento)?[campo];
    return valor == null ? null : json.encode(valor);
  }

  Future<void> _empurrarCampo(String uid, String campo, String copiaJson) =>
      FirebaseFirestore.instance.collection(_colecao).doc(uid).set(
        {
          campo: json.decode(copiaJson),
          'atualizadoEm': FieldValue.serverTimestamp(),
        },
        // `mergeFields`, e não `merge: true`: o documento é compartilhado
        // pelos domínios (cópia, conversas, lembretes, planos e livros), então
        // o `set` sem opções apagaria os outros; mas `merge: true` também
        // mescla os mapas POR DENTRO, e uma chave que a cópia nova deixou de
        // ter continuava na nuvem. Foi o "Terminar a leitura": a cópia sem
        // `posicao` não apagava a `posicao` antiga, e o livro reaparecia na
        // posição do último capítulo ao abrir o app. Com `mergeFields` cada
        // campo da lista é substituído por inteiro, e os demais ficam.
        SetOptions(mergeFields: [campo, 'atualizadoEm']),
      );

  /// Chamar como tearoff no `onTap`, nunca dentro de `() async { ... }`: o
  /// navegador só deixa abrir a janela de login dentro do gesto do usuário, e
  /// qualquer `await` antes do `signInWithPopup` consome esse gesto e a
  /// janela sai bloqueada. Quem chama trata `FirebaseAuthException` (o
  /// usuário fechou a janela, ou o navegador bloqueou o popup).
  ///
  /// Na web o login é popup do navegador, exceto em iOS/Android: aí o popup
  /// abre, a conta é escolhida, e a troca de token entre a janela e a
  /// original falha (armazenamento particionado do navegador mobile) — por
  /// isso o redirect, mesmo abrindo mão da proteção contra partição que o
  /// popup dá no desktop (ver SECURITY.md). `defaultTargetPlatform` já
  /// reflete o user-agent do navegador mobile mesmo com `kIsWeb`, sem
  /// depender de pacote novo. Nas demais plataformas é o fluxo nativo do
  /// `google_sign_in`, que devolve as credenciais para o
  /// `signInWithCredential` do Firebase. Quem cancela fora da web sai sem
  /// erro, como o popup fechado na web.
  Future<void> entrar() async {
    // Síncrono até aqui (nenhum await acima) — não consome o gesto que abre
    // o popup/seletor de conta logo adiante.
    _entrando = true;
    notifyListeners();
    try {
      if (kIsWeb) {
        final mobil =
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android;
        if (mobil) {
          await FirebaseAuth.instance.signInWithRedirect(GoogleAuthProvider());
        } else {
          await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
        }
        return;
      }
      if (!_googlePronto) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _googleServerClientId,
        );
        _googlePronto = true;
      }
      final GoogleSignInAccount conta;
      try {
        conta = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (erro) {
        // Cancelar não é erro: o gesto de "Entrar" foi interrompido, e o app
        // continua deslogado sem aviso. O mesmo vale para o popup fechado na
        // web, tratado por quem chama com FirebaseAuthException.
        if (erro.code == GoogleSignInExceptionCode.canceled ||
            erro.code == GoogleSignInExceptionCode.interrupted ||
            erro.code == GoogleSignInExceptionCode.uiUnavailable) {
          return;
        }
        rethrow;
      }
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: conta.authentication.idToken),
      );
    } finally {
      _entrando = false;
      notifyListeners();
    }
  }

  /// Envia agora o que ainda aguardava o debounce, em todas as sincronias.
  /// Usado quando o app vai para segundo plano: um app fechado em seguida
  /// mataria o timer de 2 s e a última mudança se perderia. Cada
  /// [Sincronia.despejar] tem teto de espera, então nada trava. O Sair não usa
  /// isto: precisa da confirmação de [Sincronia.garantirNaNuvem].
  Future<void> despejarSincronias() async {
    await _sincronia?.despejar();
    await _sincroniaDeConversas?.despejar();
    await _sincroniaDeLembretes?.despejar();
    await _sincroniaDePlanos?.despejar();
    await _sincroniaDeLivros?.despejar();
  }

  /// Reenvia o que ficou pendente em cada sincronia (ver
  /// [Sincronia.reenviarSePendente]). Na retomada do app, sem esperar. Não faz
  /// nada durante o [sair] nem sem sincronias rodando; erros só vão ao registro.
  Future<void> reenviarPendentes() async {
    if (_saindo) return;
    final sincronias = [
      _sincronia,
      _sincroniaDeConversas,
      _sincroniaDeLembretes,
      _sincroniaDePlanos,
      _sincroniaDeLivros,
    ];
    for (final sincronia in sincronias) {
      if (sincronia == null || _saindo) continue;
      try {
        await sincronia.reenviarSePendente();
      } catch (erro, pilha) {
        Registro.erro('Nuvem.reenviarPendentes', erro, pilha);
      }
    }
  }

  /// Sai da conta só depois de tudo salvo nela (ver [sairEmOrdem]): garante
  /// as cinco sincronias na nuvem, para de ouvir, limpa o pessoal do aparelho
  /// e então desloga. Qualquer falha ao garantir lança [SairDaContaFalhou] e
  /// deixa tudo como estava, com a sessão aberta.
  ///
  /// Sem consentimento neste aparelho (quem recusa o pedido em `main.dart`)
  /// nada sobe nem foi sincronizado, então nada pode ser garantido: só
  /// desloga, sem apagar o que existe aqui.
  ///
  /// Um segundo toque enquanto o Sair anda devolve o mesmo Sair, em vez de
  /// começar outro por cima.
  Future<void> sair() =>
      _saida ??= (sairForcado ?? _sair)().whenComplete(() => _saida = null);

  /// Só para testes de widget: troca o Sair de verdade, que precisa do
  /// Firebase. O segundo toque continua devolvendo o mesmo Sair.
  @visibleForTesting
  Future<void> Function()? sairForcado;

  Future<void>? _saida;

  Future<void> _sair() async {
    final estado = _estado;
    if (estado == null || !estado.consentimentoDaNuvem) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    _saindo = true;
    try {
      await sairComSincronias(
        sincronias: [
          _sincronia,
          _sincroniaDeConversas,
          _sincroniaDeLembretes,
          _sincroniaDePlanos,
          _sincroniaDeLivros,
        ],
        // Para ANTES de limpar: senão a limpeza notificaria as sincronias e
        // subiria uma cópia vazia por cima do que acabou de ser garantido.
        pararSincronias: _pararSincronias,
        limparAparelho: () => limparAoSair(
          estado,
          // Os horários saem das prefs, mas o que o sistema já agendou fica:
          // cancela (só este aparelho: o documento do FID dele), com prazo,
          // porque espera a rede.
          cancelarLembretes: () => Lembretes.instancia.cancelar().timeout(
            const Duration(seconds: 10),
          ),
        ),
        deslogar: FirebaseAuth.instance.signOut,
      );
    } finally {
      _saindo = false;
    }
  }

  /// Se [sair] está em andamento. Entre a limpeza do aparelho e o `signOut`
  /// a sessão ainda é a mesma, e quem espelha dados da conta por fora das
  /// sincronias (`PlanosNaNuvem`, a tela do plano) confere isto para não
  /// repor o que acabou de ser limpo.
  bool _saindo = false;
  bool get saindo => _saindo;

  /// Apaga o documento da conta e a conta em si. O que está no navegador não
  /// é tocado, só o que subiu para a nuvem.
  ///
  /// Antes do documento e da conta, limpa a participação em planos
  /// compartilhados (nome e progresso ficariam visíveis aos outros
  /// participantes, sem chance de limpeza depois de a conta sumir).
  Future<void> apagarDados() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    final estado = _estado;
    await apagarContaEmOrdem(
      pararSincronias: _pararSincronias,
      religarSincronias: () {
        if (estado != null) _iniciarSincronias(estado, usuario.uid);
      },
      precisaReautenticar: _loginAntigo(usuario),
      reautenticar: () => _reautenticar(usuario),
      apagar: () => _apagarDocumentoEConta(usuario),
    );
  }

  /// O Firebase só apaga a conta com login recente. Reautenticar antes de
  /// apagar qualquer coisa evita deixar o documento apagado e a conta de pé,
  /// mas só vale a pena (um popup do Google) quando o login já passou do prazo.
  bool _loginAntigo(User usuario) {
    final ultimoLogin = usuario.metadata.lastSignInTime;
    return ultimoLogin == null ||
        DateTime.now().difference(ultimoLogin) > _loginRecente;
  }

  Future<void> _apagarDocumentoEConta(User usuario) async {
    await PlanosNaNuvem.instancia.sairDeTodosOsPlanos(usuario.uid);
    await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(usuario.uid)
        .delete();
    await usuario.delete();
  }

  /// Prova de novo a identidade de [usuario], sem trocar a sessão — o que
  /// [apagarDados] precisa quando o Firebase recusa por login antigo demais.
  ///
  /// Mesmo fluxo de plataforma que [entrar] (popup/redirect na web conforme
  /// mobile ou não, `google_sign_in` nativo fora dela), mas reautenticando o
  /// próprio [usuario] em vez de abrir uma sessão nova. Sem este split, o
  /// antigo `signInWithPopup` — só web — lançava em todo Android/iOS com
  /// sessão antiga, e apagar a conta parava ali, com os dados do Firestore
  /// já apagados mas a conta em si intacta.
  Future<void> _reautenticar(User usuario) async {
    if (kIsWeb) {
      final mobil =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android;
      if (mobil) {
        await usuario.reauthenticateWithRedirect(GoogleAuthProvider());
      } else {
        await usuario.reauthenticateWithPopup(GoogleAuthProvider());
      }
      return;
    }
    if (!_googlePronto) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
      );
      _googlePronto = true;
    }
    final conta = await GoogleSignIn.instance.authenticate();
    await usuario.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: conta.authentication.idToken),
    );
  }
}
