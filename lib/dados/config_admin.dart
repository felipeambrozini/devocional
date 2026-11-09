import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'registro.dart';

/// Configuração remota do painel admin (só web, só o dono).
///
/// Um documento no Firestore (`config/recursos`), lido por todo mundo e
/// escrito só pelo admin (ver `firestore.rules`), guarda os interruptores de
/// cada recurso. Sem ele (primeiro deploy, sem rede, teste) vale o padrão
/// ligado de cada campo.
///
/// Os convidados do chat ficam fora dele, um documento por e-mail em
/// `convidados/{email}`: o documento de configuração é público, e a lista
/// dentro dele entregava o e-mail de todos os convidados a qualquer pessoa.
/// Cada conta só consegue ler o próprio convite.
///
/// Não importa `recursos.dart` de propósito: é `recursos.dart` quem lê daqui,
/// e o contrário fecharia um ciclo.
class ConfigAdmin extends ChangeNotifier {
  static ConfigAdmin instancia = ConfigAdmin._();
  ConfigAdmin._();

  static const colecao = 'config';
  static const documento = 'recursos';
  static const colecaoDeConvidados = 'convidados';

  bool _conversasAtivas = true;
  List<String> _emailsLegados = const [];
  bool _souConvidado = false;
  bool _planoPersonalizadoAtivo = true;
  bool _cronogramaAtivo = true;
  bool _manhaAtivo = true;
  bool _noiteAtivo = true;
  bool _promessasAtivo = true;
  bool _ouvirTextosAtivo = true;
  bool _bibliotecaAtiva = true;
  bool _comentarioNoCapituloAtivo = true;

  /// Se algum snapshot (ou mapa de teste) já foi aplicado. Antes disso os
  /// getters valem os padrões acima, e `Recursos.conversas` não libera ninguém.
  bool _carregado = false;

  bool get conversasAtivas => _conversasAtivas;

  /// A lista antiga de convidados, de quando ela morava em `config/recursos`.
  /// Só serve para o painel oferecer [migrarConvidados]; vazia depois dele.
  List<String> get emailsLegados => List.unmodifiable(_emailsLegados);

  /// Se a conta aberta tem convite para o chat (ver [ouvirConvite]).
  bool get souConvidado => _souConvidado;
  bool get planoPersonalizadoAtivo => _planoPersonalizadoAtivo;
  bool get cronogramaAtivo => _cronogramaAtivo;
  bool get manhaAtivo => _manhaAtivo;
  bool get noiteAtivo => _noiteAtivo;
  bool get promessasAtivo => _promessasAtivo;
  bool get ouvirTextosAtivo => _ouvirTextosAtivo;
  bool get bibliotecaAtiva => _bibliotecaAtiva;
  bool get comentarioNoCapituloAtivo => _comentarioNoCapituloAtivo;
  bool get carregado => _carregado;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _assinatura;
  bool _iniciado = false;

  /// Ouve o documento uma vez por processo, sem bloquear a abertura: sem
  /// Firebase (teste) ou sem rede, volta em silêncio e valem os padrões.
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    if (Firebase.apps.isEmpty) return;
    try {
      _assinatura = FirebaseFirestore.instance
          .collection(colecao)
          .doc(documento)
          .snapshots()
          .listen(
            (doc) => aplicarMapa(doc.data()),
            onError: (Object erro, StackTrace pilha) =>
                Registro.erro('ConfigAdmin.ouvir', erro, pilha),
          );
    } catch (erro, pilha) {
      Registro.erro('ConfigAdmin.iniciar', erro, pilha);
    }
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _assinaturaDoConvite;
  String? _emailDoConvite;

  CollectionReference<Map<String, dynamic>> get _convidados =>
      FirebaseFirestore.instance.collection(colecaoDeConvidados);

  /// Ouve o convite de [emailDaConta] (null = ninguém logado). Chamar de novo
  /// com o mesmo e-mail não faz nada; trocar de conta troca a escuta e
  /// derruba o convite até o documento da conta nova chegar.
  void ouvirConvite(String? emailDaConta) {
    final normalizado = emailDaConta?.trim().toLowerCase() ?? '';
    final email = normalizado.isEmpty ? null : normalizado;
    if (email == _emailDoConvite) return;
    _emailDoConvite = email;
    unawaited(_assinaturaDoConvite?.cancel());
    _assinaturaDoConvite = null;
    _definirConvidado(false);
    if (email == null || Firebase.apps.isEmpty) return;
    _assinaturaDoConvite = _convidados
        .doc(email)
        .snapshots()
        .listen(
          (doc) => _definirConvidado(doc.exists),
          onError: (Object erro, StackTrace pilha) {
            Registro.erro('ConfigAdmin.ouvirConvite', erro, pilha);
            // O erro encerra a escuta. Esquecer o e-mail faz a próxima
            // chamada assinar de novo, em vez de deixar a conta sem chat
            // até reabrir o app.
            _emailDoConvite = null;
            _definirConvidado(false);
          },
        );
  }

  void _definirConvidado(bool valor) {
    if (_souConvidado == valor) return;
    _souConvidado = valor;
    notifyListeners();
  }

  /// Os e-mails de todos os convidados, para o painel. Só o admin consegue
  /// listar a coleção: para qualquer outra conta o stream termina em erro.
  Stream<List<String>> ouvirConvidados() => _convidados.snapshots().map(
    (consulta) => [for (final doc in consulta.docs) doc.id],
  );

  @override
  void dispose() {
    _assinatura?.cancel();
    _assinaturaDoConvite?.cancel();
    super.dispose();
  }

  /// Aplica um mapa do Firestore (ou null, documento ainda inexistente) aos
  /// campos. Campo ausente ou fora do tipo mantém o padrão ligado — um
  /// documento velho nunca desliga um recurso novo por acidente.
  @visibleForTesting
  void aplicarMapa(Map<String, dynamic>? mapa) {
    if (mapa == null) {
      _carregado = true;
      notifyListeners();
      return;
    }
    bool ligado(String chave, {bool padrao = true}) {
      final valor = mapa[chave];
      return valor is bool ? valor : padrao;
    }

    _conversasAtivas = ligado('conversasAtivas');
    _emailsLegados = normalizarEmails(mapa['emailsComConversas']);
    _planoPersonalizadoAtivo = ligado('planoPersonalizadoAtivo');
    _cronogramaAtivo = ligado('cronogramaAtivo');
    _manhaAtivo = ligado('manhaAtivo');
    _noiteAtivo = ligado('noiteAtivo');
    _promessasAtivo = ligado('promessasAtivo');
    _ouvirTextosAtivo = ligado('ouvirTextosAtivo');
    _bibliotecaAtiva = ligado('bibliotecaAtiva');
    _comentarioNoCapituloAtivo = ligado('comentarioNoCapituloAtivo');
    _carregado = true;
    notifyListeners();
  }

  /// Normaliza a lista de e-mails do documento: minúsculas, sem espaço,
  /// sem duplicata, ordenada, só o que parece e-mail. Entrada torta vira
  /// lista vazia, nunca exceção — dado de admin não pode derrubar a leitura.
  static List<String> normalizarEmails(dynamic cru) {
    if (cru is! List) return const [];
    final vistos = <String>{};
    for (final item in cru) {
      if (item is! String) continue;
      final email = item.trim().toLowerCase();
      // Com barra o e-mail não serve de id de documento (ver [validarEmail]).
      if (email.isEmpty || !email.contains('@') || email.contains('/')) {
        continue;
      }
      vistos.add(email);
      if (vistos.length >= 5000) break;
    }
    return vistos.toList()..sort();
  }

  /// Semeia valores sem Firestore, para testes de widget. null mantém o
  /// padrão ligado do campo.
  @visibleForTesting
  void definirParaTeste({
    bool? conversasAtivas,
    bool? souConvidado,
    bool? planoPersonalizadoAtivo,
    bool? cronogramaAtivo,
    bool? manhaAtivo,
    bool? noiteAtivo,
    bool? promessasAtivo,
    bool? ouvirTextosAtivo,
    bool? bibliotecaAtiva,
    bool? comentarioNoCapituloAtivo,
    bool carregado = true,
  }) {
    if (conversasAtivas != null) _conversasAtivas = conversasAtivas;
    if (souConvidado != null) _souConvidado = souConvidado;
    if (planoPersonalizadoAtivo != null) {
      _planoPersonalizadoAtivo = planoPersonalizadoAtivo;
    }
    if (cronogramaAtivo != null) _cronogramaAtivo = cronogramaAtivo;
    if (manhaAtivo != null) _manhaAtivo = manhaAtivo;
    if (noiteAtivo != null) _noiteAtivo = noiteAtivo;
    if (promessasAtivo != null) _promessasAtivo = promessasAtivo;
    if (ouvirTextosAtivo != null) _ouvirTextosAtivo = ouvirTextosAtivo;
    if (bibliotecaAtiva != null) _bibliotecaAtiva = bibliotecaAtiva;
    if (comentarioNoCapituloAtivo != null) {
      _comentarioNoCapituloAtivo = comentarioNoCapituloAtivo;
    }
    _carregado = carregado;
    notifyListeners();
  }

  /// Volta aos padrões ligados, para o `tearDown` dos testes.
  @visibleForTesting
  void redefinirParaTeste() {
    _conversasAtivas = true;
    _emailsLegados = const [];
    _souConvidado = false;
    _planoPersonalizadoAtivo = true;
    _cronogramaAtivo = true;
    _manhaAtivo = true;
    _noiteAtivo = true;
    _promessasAtivo = true;
    _ouvirTextosAtivo = true;
    _bibliotecaAtiva = true;
    _comentarioNoCapituloAtivo = true;
    _carregado = false;
    notifyListeners();
  }

  Future<void> _gravar(Map<String, Object?> dados) =>
      FirebaseFirestore.instance.collection(colecao).doc(documento).set({
        ...dados,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Liga ou desliga um interruptor. [campo] é uma das chaves booleanas do
  /// documento (ver `aplicarMapa`); chave desconhecida é erro de quem chama.
  Future<void> definir(String campo, bool valor) {
    const conhecidos = {
      'conversasAtivas',
      'planoPersonalizadoAtivo',
      'cronogramaAtivo',
      'manhaAtivo',
      'noiteAtivo',
      'promessasAtivo',
      'ouvirTextosAtivo',
      'bibliotecaAtiva',
      'comentarioNoCapituloAtivo',
    };
    if (!conhecidos.contains(campo)) {
      throw ArgumentError('Campo desconhecido: $campo');
    }
    return _gravar({campo: valor});
  }

  /// Normaliza e valida um e-mail digitado no painel. Devolve o normalizado
  /// ou lança [FormatException] com o motivo, para a tela mostrar no aviso.
  static String validarEmail(String cru) {
    final email = cru.trim().toLowerCase();
    if (email.isEmpty) throw const FormatException('Digite um e-mail.');
    if (!email.contains('@') || !email.contains('.')) {
      throw const FormatException('Isto não parece um e-mail.');
    }
    if (email.contains(' ')) {
      throw const FormatException('E-mail não tem espaço.');
    }
    // O e-mail é o id do documento do convite, e id não aceita barra.
    if (email.contains('/')) {
      throw const FormatException('E-mail não tem barra.');
    }
    return email;
  }

  static Map<String, Object?> _convite() => {
    'criadoEm': FieldValue.serverTimestamp(),
  };

  Future<void> adicionarEmail(String cru) =>
      _convidados.doc(validarEmail(cru)).set(_convite());

  Future<void> removerEmail(String email) =>
      _convidados.doc(email.trim().toLowerCase()).delete();

  /// Leva a lista antiga de `config/recursos` para `convidados/{email}` e
  /// apaga o campo, tudo num lote só: ou migra inteiro, ou nada muda. Um lote
  /// do Firestore aceita 500 escritas, teto bem acima da lista de convidados.
  Future<void> migrarConvidados() {
    final firestore = FirebaseFirestore.instance;
    final lote = firestore.batch();
    for (final email in _emailsLegados) {
      lote.set(_convidados.doc(email), _convite());
    }
    lote.set(firestore.collection(colecao).doc(documento), {
      'emailsComConversas': FieldValue.delete(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return lote.commit();
  }
}
