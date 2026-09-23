import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'registro.dart';

/// Configuração remota do painel admin (só web, só o dono).
///
/// Um documento só no Firestore (`config/recursos`), lido por todo mundo e
/// escrito só pelo admin (ver `firestore.rules`): interruptores de cada
/// recurso mais a allowlist de e-mails do chat. Sem ele (primeiro deploy,
/// sem rede, teste) vale o padrão ligado de cada campo, e a allowlist fica
/// vazia — o chat só abre depois de o documento chegar.
///
/// Não importa `recursos.dart` de propósito: é `recursos.dart` quem lê daqui,
/// e o contrário fecharia um ciclo.
class ConfigAdmin extends ChangeNotifier {
  static ConfigAdmin instancia = ConfigAdmin._();
  ConfigAdmin._();

  static const colecao = 'config';
  static const documento = 'recursos';

  bool _conversasAtivas = true;
  List<String> _emails = const [];
  bool _planoPersonalizadoAtivo = true;
  bool _cronogramaAtivo = true;
  bool _manhaAtivo = true;
  bool _noiteAtivo = true;
  bool _promessasAtivo = true;
  bool _ouvirTextosAtivo = true;

  /// Se algum snapshot (ou mapa de teste) já foi aplicado. Antes disso os
  /// getters valem os padrões acima, e `Recursos.conversas` usa o
  /// `--dart-define` legado em vez da lista ainda vazia.
  bool _carregado = false;

  bool get conversasAtivas => _conversasAtivas;
  List<String> get emailsComConversas => List.unmodifiable(_emails);
  bool get planoPersonalizadoAtivo => _planoPersonalizadoAtivo;
  bool get cronogramaAtivo => _cronogramaAtivo;
  bool get manhaAtivo => _manhaAtivo;
  bool get noiteAtivo => _noiteAtivo;
  bool get promessasAtivo => _promessasAtivo;
  bool get ouvirTextosAtivo => _ouvirTextosAtivo;
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

  @override
  void dispose() {
    _assinatura?.cancel();
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
    bool ligado(String chave) {
      final valor = mapa[chave];
      return valor is bool ? valor : true;
    }

    _conversasAtivas = ligado('conversasAtivas');
    _emails = normalizarEmails(mapa['emailsComConversas']);
    _planoPersonalizadoAtivo = ligado('planoPersonalizadoAtivo');
    _cronogramaAtivo = ligado('cronogramaAtivo');
    _manhaAtivo = ligado('manhaAtivo');
    _noiteAtivo = ligado('noiteAtivo');
    _promessasAtivo = ligado('promessasAtivo');
    _ouvirTextosAtivo = ligado('ouvirTextosAtivo');
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
      if (email.isEmpty || !email.contains('@')) continue;
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
    List<String>? emails,
    bool? planoPersonalizadoAtivo,
    bool? cronogramaAtivo,
    bool? manhaAtivo,
    bool? noiteAtivo,
    bool? promessasAtivo,
    bool? ouvirTextosAtivo,
    bool carregado = true,
  }) {
    if (conversasAtivas != null) _conversasAtivas = conversasAtivas;
    if (emails != null) _emails = normalizarEmails(emails);
    if (planoPersonalizadoAtivo != null) {
      _planoPersonalizadoAtivo = planoPersonalizadoAtivo;
    }
    if (cronogramaAtivo != null) _cronogramaAtivo = cronogramaAtivo;
    if (manhaAtivo != null) _manhaAtivo = manhaAtivo;
    if (noiteAtivo != null) _noiteAtivo = noiteAtivo;
    if (promessasAtivo != null) _promessasAtivo = promessasAtivo;
    if (ouvirTextosAtivo != null) _ouvirTextosAtivo = ouvirTextosAtivo;
    _carregado = carregado;
    notifyListeners();
  }

  /// Volta aos padrões ligados, para o `tearDown` dos testes.
  @visibleForTesting
  void redefinirParaTeste() {
    _conversasAtivas = true;
    _emails = const [];
    _planoPersonalizadoAtivo = true;
    _cronogramaAtivo = true;
    _manhaAtivo = true;
    _noiteAtivo = true;
    _promessasAtivo = true;
    _ouvirTextosAtivo = true;
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
    return email;
  }

  Future<void> adicionarEmail(String cru) => _gravar({
    'emailsComConversas': FieldValue.arrayUnion([validarEmail(cru)]),
  });

  Future<void> removerEmail(String email) => _gravar({
    'emailsComConversas': FieldValue.arrayRemove([email.trim().toLowerCase()]),
  });
}
