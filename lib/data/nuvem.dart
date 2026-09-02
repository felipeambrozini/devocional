import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'
    show
        ChangeNotifier,
        TargetPlatform,
        defaultTargetPlatform,
        kIsWeb,
        visibleForTesting;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:google_sign_in/google_sign_in.dart';

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

/// RegExp para separar por espaços em branco (evita warning de RegExp deprecated).
// ignore: deprecated_member_use
final _espacos = RegExp(r'\s+');

/// Se a conta na nuvem é uma opção nesta plataforma.
///
/// Verdade em todas as plataformas do projeto (web, Android e iOS): todas
/// têm configuração Firebase em `firebase_options.dart`.
bool get nuvemSuportada => true;

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
    this.serializar,
    this.fundir,
    this.aoMudarSituacao,
    this.atraso = const Duration(seconds: 2),
  });

  final Estado estado;
  final Future<String?> Function() puxar;
  final Future<void> Function(String copia) empurrar;

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

  /// A cópia que o [_pendente] ainda não enviou. Vive fora da closure do
  /// `Timer` para que [despejar] saiba o que enviar no logout.
  String? _pendenteCopia;

  String _serializar() => serializar?.call() ?? estado.exportar();

  Future<void> _fundir(String remota) =>
      fundir?.call(remota) ?? estado.importar(remota);

  /// Puxa e funde ANTES de passar a ouvir. Nesta ordem nada se perde nos dois
  /// sentidos: quem entra num navegador novo recebe o que já estava na conta,
  /// e o que só existia neste navegador sobe logo depois, no envio que a
  /// própria fusão dispara.
  Future<void> comecar() async {
    _ultimaCopia = _serializar();
    try {
      final remota = await puxar();
      if (remota != null) await _fundir(remota);
    } catch (erro, pilha) {
      // Cópia da conta ilegível (FormatException: versão futura ou gravada
      // torta), sem rede, ou o Firestore recusou o acesso: o local continua
      // intacto e vai subir por cima; nunca o contrário. A sincronia segue
      // viva para os envios e a próxima mudança tenta puxar de novo. Falhar
      // aqui não pode derrubar nada (mesma regra de `_enviar`).
      Registro.erro('Nuvem.comecar', erro, pilha);
    }
    estado.addListener(_aoMudar);
    _aoMudar();
  }

  void parar() {
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

  /// Envia agora o que ainda aguardava o debounce, sem esperar o [atraso].
  ///
  /// Usado no logout: o signOut a seguir para a sincronia, e uma mudança
  /// feita segundos antes não pode ficar presa no timer. A espera tem teto —
  /// sem rede, o Firestore fica com o envio pendente até reconectar, e
  /// segurar o logout por isso não vale a pena: o dado continua no aparelho
  /// e a próxima mudança tenta de novo.
  Future<void> despejar() async {
    final pendente = _pendente;
    if (pendente == null) return;
    pendente.cancel();
    _pendente = null;
    final copia = _pendenteCopia;
    _pendenteCopia = null;
    if (copia == null) return;
    try {
      await empurrar(copia).timeout(const Duration(seconds: 5));
      _ultimaCopia = copia;
    } catch (erro, pilha) {
      Registro.erro('Nuvem.despejar', erro, pilha);
    }
    aoMudarSituacao?.call();
  }

  Future<void> _enviar(String copia) async {
    try {
      await empurrar(copia);
      _ultimaCopia = copia;
    } catch (erro, pilha) {
      // Sem rede, ou regra recusou. O dado continua no aparelho e a próxima
      // mudança tenta de novo; falhar aqui não pode derrubar nada.
      Registro.erro('Nuvem.enviar', erro, pilha);
    }
    aoMudarSituacao?.call();
  }
}

/// Conta Google e cópia na nuvem. Um valor só para o app inteiro, como
/// `Lembretes.instancia` em `lib/data/lembretes.dart` — e pela mesma razão:
/// os botões de Entrar e Sair (Hoje e plano compartilhado) não têm como
/// compartilhar uma instância sem um Provider inteiro só para isto.
///
/// ponytail: um documento por usuário (`usuarios/{uid}`) com o mesmo mapa que
/// `exportar()` já produz. `importar()` funde e nunca apaga, então uma
/// remoção feita num navegador não se propaga — se um favorito apagado
/// "ressuscitar" na prática, o caminho é uma `versao: 2` da cópia com
/// lápides, e `importar` respeitando-as.
class Nuvem extends ChangeNotifier {
  static Nuvem instancia = Nuvem._();
  Nuvem._();

  static const _colecao = 'usuarios';

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
  StreamSubscription<User?>? _assinatura;
  bool _pronta = false;

  /// Só para testes de widget: força [logado] sem depender de um Firebase de
  /// verdade, que os testes não inicializam. null (padrão) deixa a resposta
  /// de verdade, vinda do Firebase.
  @visibleForTesting
  bool? logadoForcado;

  bool get logado =>
      logadoForcado ?? (_pronta && FirebaseAuth.instance.currentUser != null);
  String? get email =>
      _pronta ? FirebaseAuth.instance.currentUser?.email : null;

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
  String? get uid => _pronta ? FirebaseAuth.instance.currentUser?.uid : null;

  /// Primeiro nome de quem entrou, para a saudação de `_Cabecalho` em
  /// `hoje.dart`. null sem conta, ou se a conta Google não devolveu nome.
  String? get primeiroNome {
    final nome = _pronta
        ? FirebaseAuth.instance.currentUser?.displayName
        : null;
    return nome?.trim().split(_espacos).firstOrNull;
  }

  /// Foto de perfil da conta Google de quem entrou, para o avatar de
  /// `_Cabecalho` em `hoje.dart`. null sem conta, ou sem foto no Google.
  String? get fotoUrl =>
      _pronta ? FirebaseAuth.instance.currentUser?.photoURL : null;

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
  }

  /// Prepara o Firebase e liga a sincronização ao estado de login. Chamar uma
  /// vez, em `main.dart`, só quando [nuvemSuportada].
  ///
  /// Falhar aqui (projeto ainda não configurado, sem rede) não pode impedir o
  /// app de abrir — mesma regra do fuso horário em `lembretes.dart`. Por isso
  /// o erro só é engolido, nunca propagado.
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
    if (kIsWeb ? _recaptchaSiteKey.isNotEmpty : true) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaV3Provider(_recaptchaSiteKey),
          providerAndroid: const AndroidPlayIntegrityProvider(),
          // Com fallback para DeviceCheck: o app aceita iOS 13 (Podfile), e
          // App Attest sozinho exige iOS 14+.
          providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (erro, pilha) {
        Registro.erro('Nuvem.iniciar', erro, pilha);
      }
    }

    _pronta = true;

    _assinatura = FirebaseAuth.instance.authStateChanges().listen((usuario) {
      _sincronia?.parar();
      _sincronia = null;
      _sincroniaDeConversas?.parar();
      _sincroniaDeConversas = null;
      _sincroniaDeLembretes?.parar();
      _sincroniaDeLembretes = null;
      _sincroniaDePlanos?.parar();
      _sincroniaDePlanos = null;
      notifyListeners();
      if (usuario == null) return;

      final sincronia = Sincronia(
        estado: estado,
        puxar: () => _puxar(usuario.uid),
        empurrar: (copia) => _empurrar(usuario.uid, copia),
        aoMudarSituacao: notifyListeners,
      );
      _sincronia = sincronia;
      unawaited(sincronia.comecar());

      final sincroniaDeConversas = Sincronia(
        estado: estado,
        serializar: estado.serializarConversas,
        fundir: estado.fundirConversas,
        puxar: () => _puxarConversas(usuario.uid),
        empurrar: (copia) => _empurrarConversas(usuario.uid, copia),
        aoMudarSituacao: notifyListeners,
      );
      _sincroniaDeConversas = sincroniaDeConversas;
      unawaited(sincroniaDeConversas.comecar());

      final sincroniaDeLembretes = Sincronia(
        estado: estado,
        serializar: estado.serializarLembretes,
        fundir: (remota) async {
          final mudou = await estado.fundirLembretes(remota);
          if (!mudou || !estado.lembretesAtivos) return;
          // O horário ligado veio de outro aparelho — este pode nunca ter
          // pedido a permissão de notificação. Sem checar aqui, agendar()
          // roda no vácuo: grava o horário mas nada aparece neste aparelho.
          // Não desliga `lembretesAtivos` aqui: é a preferência compartilhada
          // entre aparelhos, e derrubá-la também desligaria os que já têm
          // permissão — a falta de permissão é só deste aparelho.
          if (!await Lembretes.instancia.pedirPermissao()) return;
          TimeOfDay hora(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
          await Lembretes.instancia.agendar(
            manha: hora(estado.minutosLembreteManha),
            promessas: hora(estado.minutosLembretePromessas),
            leitura: hora(estado.minutosLembreteLeitura),
            noite: hora(estado.minutosLembreteNoite),
          );
        },
        puxar: () => _puxarLembretes(usuario.uid),
        empurrar: (copia) => _empurrarLembretes(usuario.uid, copia),
        aoMudarSituacao: notifyListeners,
      );
      _sincroniaDeLembretes = sincroniaDeLembretes;
      unawaited(sincroniaDeLembretes.comecar());

      final sincroniaDePlanos = Sincronia(
        estado: estado,
        serializar: estado.serializarPlanos,
        fundir: estado.fundirPlanos,
        puxar: () => _puxarPlanos(usuario.uid),
        empurrar: (copia) => _empurrarPlanos(usuario.uid, copia),
        aoMudarSituacao: notifyListeners,
      );
      _sincroniaDePlanos = sincroniaDePlanos;
      unawaited(sincroniaDePlanos.comecar());
    });
  }

  Future<String?> _puxar(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(uid)
        .get();
    final copia = doc.data()?['copia'];
    if (copia == null) return null;
    // Guardado como mapa no Firestore, não como string: assim a cópia se lê
    // no console do Firebase quando alguém disser "sumiu uma nota".
    return json.encode(copia);
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    _sincronia?.parar();
    _sincroniaDeConversas?.parar();
    _sincroniaDeLembretes?.parar();
    _sincroniaDePlanos?.parar();
    super.dispose();
  }

  Future<void> _empurrar(String uid, String copiaJson) =>
      FirebaseFirestore.instance.collection(_colecao).doc(uid).set({
        'copia': json.decode(copiaJson),
        'atualizadoEm': FieldValue.serverTimestamp(),
        // Sem merge os dois domínios se apagariam um ao outro: a cópia e as
        // conversas escrevem no mesmo documento, e o `set` sem opções
        // substituiria o documento inteiro.
      }, SetOptions(merge: true));

  Future<String?> _puxarConversas(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(uid)
        .get();
    final conversas = doc.data()?['conversas'];
    if (conversas == null) return null;
    return json.encode(conversas);
  }

  Future<void> _empurrarConversas(String uid, String copiaJson) =>
      FirebaseFirestore.instance.collection(_colecao).doc(uid).set({
        'conversas': json.decode(copiaJson),
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<String?> _puxarLembretes(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(uid)
        .get();
    final lembretes = doc.data()?['lembretes'];
    if (lembretes == null) return null;
    return json.encode(lembretes);
  }

  Future<void> _empurrarLembretes(String uid, String copiaJson) =>
      FirebaseFirestore.instance.collection(_colecao).doc(uid).set({
        'lembretes': json.decode(copiaJson),
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<String?> _puxarPlanos(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(uid)
        .get();
    final planos = doc.data()?['planos'];
    if (planos == null) return null;
    return json.encode(planos);
  }

  Future<void> _empurrarPlanos(String uid, String copiaJson) =>
      FirebaseFirestore.instance.collection(_colecao).doc(uid).set({
        'planos': json.decode(copiaJson),
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

  /// Sobe a foto escolhida na câmera ou galeria (`_escolherFoto` em
  /// `hoje.dart`) para o Storage e atualiza a photoURL da conta com o link.
  /// `fotoUrl` lê direto do `currentUser`, então o `notifyListeners` aqui é o
  /// único jeito de repintar o avatar sem esperar um evento do Auth.
  Future<void> atualizarFoto(Uint8List bytes) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    final referencia = FirebaseStorage.instance.ref(
      'fotos_de_perfil/${usuario.uid}.jpg',
    );
    await referencia.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    await usuario.updatePhotoURL(await referencia.getDownloadURL());
    notifyListeners();
  }

  /// Volta ao avatar da inicial: apaga o arquivo do Storage (se houver — a
  /// foto pode ter vindo direto da conta Google, sem nunca passar por
  /// [atualizarFoto]) e limpa a photoURL da conta.
  Future<void> removerFoto() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    try {
      await FirebaseStorage.instance
          .ref('fotos_de_perfil/${usuario.uid}.jpg')
          .delete();
    } on FirebaseException catch (erro) {
      if (erro.code != 'object-not-found') rethrow;
    }
    await usuario.updatePhotoURL(null);
    notifyListeners();
  }

  Future<void> sair() async {
    // Despeja o que ainda aguardava o debounce antes de derrubar a sessão:
    // o signOut para a sincronia, e a última mudança não pode ficar presa no
    // timer. [despejar] tem teto de espera, então o logout nunca trava.
    await _sincronia?.despejar();
    await _sincroniaDeConversas?.despejar();
    await _sincroniaDeLembretes?.despejar();
    await _sincroniaDePlanos?.despejar();
    await FirebaseAuth.instance.signOut();
  }

  /// Apaga o documento da conta e a conta em si. O que está no navegador não
  /// é tocado — só o que subiu para a nuvem.
  ///
  /// Antes do documento e da conta, limpa os dois rastros que ficariam para
  /// trás: a foto de perfil (pública no Storage) e a própria participação em
  /// planos compartilhados (nome e progresso ficariam visíveis aos outros
  /// participantes, sem chance de limpeza depois de a conta sumir).
  Future<void> apagarDados() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    await removerFoto();
    await PlanosNaNuvem.instancia.sairDeTodosOsPlanos(usuario.uid);
    await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(usuario.uid)
        .delete();
    try {
      await usuario.delete();
    } on FirebaseAuthException catch (erro) {
      // O Firebase exige login recente para apagar a conta. Como já estamos
      // dentro do gesto de "Apagar", reabrir o popup na hora ainda conta como
      // gesto do usuário.
      if (erro.code != 'requires-recent-login') rethrow;
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      await FirebaseAuth.instance.currentUser?.delete();
    }
  }
}
