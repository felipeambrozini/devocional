import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;

import '../firebase_options.dart';
import 'estado.dart';

/// Se a conta na nuvem é uma opção nesta plataforma.
///
/// Só web: é a única plataforma onde o navegador apaga o armazenamento
/// sozinho (ver `_AvisoDePerda` em `lib/telas/notas.dart`). Android e iOS já
/// guardam tudo no aparelho e continuam só com o exportar/importar por
/// clipboard. Mesmo formato de `lembretesSuportados` em `lib/data/lembretes.dart`.
bool get nuvemSuportada => kIsWeb;

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

  bool falhouAoEnviar = false;
  String? _ultimaCopia;
  Timer? _pendente;

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
    } on FormatException {
      // Cópia da conta ilegível (versão futura, ou gravada torta). O local
      // continua intacto e vai subir por cima; nunca o contrário.
    }
    estado.addListener(_aoMudar);
    _aoMudar();
  }

  void parar() {
    estado.removeListener(_aoMudar);
    _pendente?.cancel();
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
    _pendente = Timer(atraso, () => _enviar(copia));
  }

  Future<void> _enviar(String copia) async {
    try {
      await empurrar(copia);
      _ultimaCopia = copia;
      falhouAoEnviar = false;
    } catch (_) {
      // Sem rede, ou regra recusou. O dado continua no aparelho e a próxima
      // mudança tenta de novo; falhar aqui não pode derrubar nada.
      falhouAoEnviar = true;
    }
    aoMudarSituacao?.call();
  }
}

/// Conta Google e cópia na nuvem. Um valor só para o app inteiro, como
/// `Lembretes.instancia` em `lib/data/lembretes.dart` — e pela mesma razão:
/// o toque em "Entrar" e a folha de ajustes não têm como compartilhar uma
/// instância sem um Provider inteiro só para isto.
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

  /// A segunda sincronia, só das conversas do chat. Vive no mesmo documento
  /// `usuarios/{uid}` que a cópia, no campo `conversas`, mas com serializador
  /// próprio (`serializarConversas`): o histórico não entra na cópia de
  /// segurança que `exportar()` produz. Ver o comentário daquele método.
  Sincronia? _sincroniaDeConversas;
  StreamSubscription<User?>? _assinatura;
  bool _pronta = false;

  bool get logado => _pronta && FirebaseAuth.instance.currentUser != null;
  String? get email => _pronta ? FirebaseAuth.instance.currentUser?.email : null;
  bool get falhouAoEnviar => _sincronia?.falhouAoEnviar ?? false;

  /// Primeiro nome de quem entrou, para a saudação de `_Cabecalho` em
  /// `hoje.dart`. null sem conta, ou se a conta Google não devolveu nome.
  String? get primeiroNome {
    final nome = _pronta ? FirebaseAuth.instance.currentUser?.displayName : null;
    return nome?.trim().split(RegExp(r'\s+')).firstOrNull;
  }

  /// Prepara o Firebase e liga a sincronização ao estado de login. Chamar uma
  /// vez, em `main.dart`, só quando [nuvemSuportada].
  ///
  /// Falhar aqui (projeto ainda não configurado, sem rede) não pode impedir o
  /// app de abrir — mesma regra do fuso horário em `lembretes.dart`. Por isso
  /// o erro só é engolido, nunca propagado.
  Future<void> iniciar(Estado estado) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      return;
    }
    _pronta = true;

    _assinatura = FirebaseAuth.instance.authStateChanges().listen((usuario) {
      _sincronia?.parar();
      _sincronia = null;
      _sincroniaDeConversas?.parar();
      _sincroniaDeConversas = null;
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

  /// Chamar como tearoff no `onTap`, nunca dentro de `() async { ... }`: o
  /// navegador só deixa abrir a janela de login dentro do gesto do usuário, e
  /// qualquer `await` antes do `signInWithPopup` consome esse gesto e a
  /// janela sai bloqueada. Quem chama trata `FirebaseAuthException` (o
  /// usuário fechou a janela, ou o navegador bloqueou o popup).
  Future<void> entrar() =>
      FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());

  Future<void> sair() => FirebaseAuth.instance.signOut();

  /// Apaga o documento da conta e a conta em si. O que está no navegador não
  /// é tocado — só o que subiu para a nuvem.
  Future<void> apagarDados() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
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
