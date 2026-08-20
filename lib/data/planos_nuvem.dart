import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'canon.dart';
import 'estado.dart';
import 'planos.dart';
import 'registro.dart';

/// Falha de rede, regra ou login numa operação de plano compartilhado.
class PlanosNaNuvemException implements Exception {
  const PlanosNaNuvemException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Planos de leitura compartilhados, no Firestore.
///
/// Um plano compartilhado vive num documento `planos/{id}` (o mesmo id do
/// plano local), e cada participante tem a própria entrada no mapa
/// `participantes`, com nome e dias lidos. É isso que permite ver o
/// progresso de cada um: o documento inteiro é legível por qualquer
/// participante, e cada um só escreve na própria entrada (ver
/// firestore.rules).
///
/// Contrato do documento `planos/{planoId}`:
///   titulo        string
///   livros        list de slugs do canon
///   dias          int
///   criadoPor     string — uid de quem criou
///   criadoEm      timestamp do servidor
///   participantes mapa uid -> {nome: string, lidos: list de int}
///
/// O espelho local (em [Estado]) continua sendo a lista instantânea; este
/// arquivo é quem leva o plano para a nuvem e traz de volta. A sincronia é
/// pontual, não em tempo real: escreve na hora do gesto e puxa ao entrar na
/// conta. Quem quer ver o plano e o progresso dos outros em tempo real
/// assina [deUmPlano] na tela do plano.
class PlanosNaNuvem {
  PlanosNaNuvem._();

  static final PlanosNaNuvem instancia = PlanosNaNuvem._();

  static const _colecao = 'planos';

  Estado? _estado;
  StreamSubscription<User?>? _assinatura;

  bool get pronta => _pronta;
  bool _pronta = false;

  /// Prepara a sincronia dos planos compartilhados. Chamar uma vez, em
  /// `main.dart`, só quando [nuvemSuportada] e depois de `Nuvem.iniciar`:
  /// precisa do Firebase já inicializado. Se ele não inicializou (projeto
  /// não configurado, sem rede), os planos continuam só locais.
  Future<void> iniciar(Estado estado) async {
    if (Firebase.apps.isEmpty) return;
    _estado = estado;
    _pronta = true;
    _assinatura = FirebaseAuth.instance.authStateChanges().listen((usuario) {
      if (usuario == null) {
        // Sem conta a sincronia fica parada; o próximo login re-assina.
        _assinatura?.cancel();
        return;
      }
      unawaited(_puxarOsMeus(usuario.uid));
    });
  }

  /// Traz para o espelho local todos os planos em que o usuário participa,
  /// com os próprios dias lidos. Sem isto, um plano criado ou aceito noutro
  /// navegador nunca apareceria na lista de Meus Planos daqui.
  Future<void> _puxarOsMeus(String uid) async {
    final estado = _estado;
    if (estado == null) return;
    try {
      final resultados = await FirebaseFirestore.instance
          .collection(_colecao)
          .where('participantes.$uid', isNotEqualTo: null)
          .get();
      for (final doc in resultados.docs) {
        final dados = doc.data();
        final participantes =
            dados['participantes'] as Map<String, dynamic>? ?? const {};
        final minhaEntrada = participantes[uid];
        final lidos = minhaEntrada is Map<String, dynamic> &&
                minhaEntrada['lidos'] is List
            ? {
                for (final d in minhaEntrada['lidos'] as List)
                  if (d is int) d,
              }
            : <int>{};
        final criadoEm = dados['criadoEm'] is Timestamp
            ? (dados['criadoEm'] as Timestamp).toDate()
            : DateTime.now();
        await estado.aplicarPlanoDaNuvem(
          PlanoDoUsuario.doJsonDaNuvem(dados, id: doc.id, criadoEm: criadoEm),
          lidos: lidos,
        );
      }
    } catch (erro, pilha) {
      // Sem rede ou sem permissão: o espelho local continua intacto, e a
      // próxima entrada na conta tenta de novo. Falhar aqui não pode
      // derrubar nada (mesma regra da sincronia da Nuvem).
      Registro.erro('PlanosNaNuvem.sincronizar', erro, pilha);
    }
  }

  /// Cria o documento do plano na nuvem, com a participação de quem
  /// compartilha. Devolve o link para divulgar. Falha com
  /// [PlanosNaNuvemException] sem conta ou sem rede.
  Future<String> compartilhar(PlanoDoUsuario plano) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      throw const PlanosNaNuvemException(
        'Entre na sua conta para compartilhar o plano.',
      );
    }
    try {
      await FirebaseFirestore.instance.collection(_colecao).doc(plano.id).set({
        'titulo': plano.titulo,
        'livros': plano.livros,
        'dias': plano.dias,
        'criadoPor': usuario.uid,
        'criadoEm': FieldValue.serverTimestamp(),
        'participantes': {
          usuario.uid: _entradaDoUsuario(usuario, const []),
        },
      });
    } catch (erro, pilha) {
      Registro.erro('PlanosNaNuvem.compartilhar', erro, pilha);
      throw const PlanosNaNuvemException(
        'Não foi possível compartilhar agora. Verifique a conexão e tente de novo.',
      );
    }
    return linkDoPlano(plano.id, titulo: plano.titulo);
  }

  /// Escreve os dias lidos do usuário na própria entrada do documento.
  /// Idempotente, e a regra do Firestore só deixa tocar a própria entrada.
  Future<void> gravarDias(String planoId, List<int> lidos) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      throw const PlanosNaNuvemException(
        'Entre na sua conta para marcar dias no plano.',
      );
    }
    try {
      await FirebaseFirestore.instance
          .collection(_colecao)
          .doc(planoId)
          .update({'participantes.${usuario.uid}.lidos': lidos});
    } catch (erro, pilha) {
      Registro.erro('PlanosNaNuvem.gravarDias', erro, pilha);
      throw const PlanosNaNuvemException(
        'Não foi possível guardar. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// Entra num plano pelo link: escreve a própria participação. Falha com
  /// [PlanosNaNuvemException] se o documento não existe (link errado) ou se
  /// a regra recusar.
  Future<void> entrar(String planoId) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      throw const PlanosNaNuvemException(
        'Entre na sua conta para participar do plano.',
      );
    }
    try {
      await FirebaseFirestore.instance
          .collection(_colecao)
          .doc(planoId)
          .update({'participantes.${usuario.uid}': _entradaDoUsuario(usuario, const [])});
    } catch (erro, pilha) {
      Registro.erro('PlanosNaNuvem.entrar', erro, pilha);
      throw const PlanosNaNuvemException(
        'Plano não encontrado, ou sem conexão. Verifique o link e tente de novo.',
      );
    }
  }

  /// Sai do plano: apaga a própria participação. O documento continua para
  /// os outros; só o criador pode apagar o plano inteiro.
  Future<void> sair(String planoId) async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(_colecao)
          .doc(planoId)
          .update({'participantes.${usuario.uid}': FieldValue.delete()});
    } catch (erro, pilha) {
      Registro.erro('PlanosNaNuvem.sair', erro, pilha);
      throw const PlanosNaNuvemException(
        'Não foi possível sair agora. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// O criador apaga o plano para todos.
  Future<void> excluir(String planoId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_colecao)
          .doc(planoId)
          .delete();
    } catch (erro, pilha) {
      Registro.erro('PlanosNaNuvem.excluir', erro, pilha);
      throw const PlanosNaNuvemException(
        'Não foi possível excluir agora. Verifique a conexão e tente de novo.',
      );
    }
  }

  /// O documento do plano em tempo real, para a tela do plano. Só funciona
  /// para participantes; quem chega por link passa por [entrar] antes.
  Stream<DocumentSnapshot<Map<String, dynamic>>> deUmPlano(String planoId) =>
      FirebaseFirestore.instance.collection(_colecao).doc(planoId).snapshots();

  Map<String, dynamic> _entradaDoUsuario(User usuario, List<int> lidos) => {
    'nome': _nomeDoUsuario(usuario),
    'lidos': lidos,
  };

  /// Primeiro nome para a lista de participantes; sem nome no perfil Google,
  /// o que aparece é o endereço de e-mail, para a pessoa não virar um "—".
  String _nomeDoUsuario(User usuario) {
    final nome = usuario.displayName?.trim();
    if (nome != null && nome.isNotEmpty) return nome;
    final email = usuario.email;
    if (email != null && email.isNotEmpty) return email;
    return 'Participante';
  }
}

/// Acentos comuns do português, para o slug do link não sair cheio de `%C3%A3`
/// nem preservar letra que a URL só mostraria escapada.
const _acentos = {
  'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// O título em minúsculas, sem acento e com hífen no lugar de espaço ou
/// pontuação — só a parte legível do link, ver [linkDoPlano].
String _slugDoTitulo(String titulo) {
  final semAcento = titulo
      .toLowerCase()
      .split('')
      .map((c) => _acentos[c] ?? c)
      .join();
  final slug = semAcento
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  // Um título com o livro inteiro da Bíblia não pode virar um link gigante.
  return slug.length <= 50
      ? slug
      : slug.substring(0, 50).replaceAll(RegExp(r'-+$'), '');
}

/// O link de um plano compartilhado, para mandar a alguém. O `?plano=` é
/// lido em `main.dart`, que abre a tela do plano sobre qualquer aba.
///
/// [titulo], quando dado, vira um slug legível na frente do id de verdade
/// ("genesis-em-30-dias-hlj2pu6uw801b99b") — só estética: quem abre o link
/// busca pelo plano sempre pelo id, o último trecho depois do último hífen
/// (ver [idDoParametroDePlano]), que continua único mesmo que duas pessoas
/// deem o mesmo nome a planos diferentes.
String linkDoPlano(String planoId, {String? titulo}) {
  final slug = titulo == null ? '' : _slugDoTitulo(titulo);
  final caminho = slug.isEmpty ? planoId : '$slug-$planoId';
  return '$enderecoDoSite?plano=$caminho';
}

/// O id de verdade de dentro do parâmetro `?plano=` da URL — despe o slug
/// legível que [linkDoPlano] põe na frente, se houver. O id nunca tem
/// hífen (vem de [novoIdDePlano], puro base 36), então o último trecho
/// depois do último hífen sempre é ele, com ou sem slug na frente.
String idDoParametroDePlano(String parametro) => parametro.split('-').last;