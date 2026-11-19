import 'package:cloud_firestore/cloud_firestore.dart';

import 'modelos.dart';
import 'nuvem.dart';
import 'versao.dart';

/// Motivos da denúncia: código gravado no Firestore e rótulo mostrado no
/// diálogo. O código é o que as regras validam (firestore.rules) e o que o
/// dono lê no console; mudar o rótulo não muda o dado já gravado.
const motivosDeDenuncia = <String, String>{
  'inadequada': 'Resposta inadequada ou perigosa',
  'doutrina': 'Informação bíblica errada',
  'fora_do_tema': 'Não responde à pergunta',
  'outro': 'Outro motivo',
};

/// Uma denúncia de resposta gerada por IA, pronta para virar documento.
///
/// Pergunta e resposta vão junto porque é impossível julgar a resposta sem o
/// que a motivou — e quem denuncia está pedindo essa revisão. O e-mail, o uid
/// e o nome da conta não entram no texto; só o uid do documento, para o
/// Firestore saber de quem é a denúncia e as regras conferirem o dono.
class Denuncia {
  Denuncia({
    required this.motivo,
    required this.persona,
    required this.conversaId,
    required this.mensagemId,
    required this.pergunta,
    required this.resposta,
    this.detalhe = '',
  });

  final String motivo;
  final String persona;
  final String conversaId;
  final String mensagemId;
  final String pergunta;
  final String resposta;
  final String detalhe;

  static String _cortar(String texto, int limite) =>
      texto.length <= limite ? texto : texto.substring(0, limite);

  /// O documento de `denuncias/{id}`. Os tetos repetem os das regras: um
  /// texto maior seria recusado com PERMISSION_DENIED em vez de chegar ao
  /// dono, então o cliente corta antes.
  Map<String, dynamic> paraJson({
    required String uid,
    required Object criadoEm,
    required String versao,
    required String plataforma,
  }) => {
    'uid': uid,
    'criadoEm': criadoEm,
    'motivo': motivo,
    'detalhe': _cortar(detalhe, 1000),
    'persona': _cortar(persona, 40),
    'conversaId': _cortar(conversaId, 100),
    'mensagemId': _cortar(mensagemId, 100),
    'pergunta': _cortar(pergunta, 20000),
    'resposta': _cortar(resposta, 30000),
    'versao': _cortar(versao, 40),
    'plataforma': _cortar(plataforma, 20),
  };
}

/// Sem conta logada não há denúncia: a regra exige uid igual ao da conta
/// Google. O chat já é só para convidados logados; isto é a defesa do
/// caminho, não um estado esperado.
class DenunciaSemConta implements Exception {
  const DenunciaSemConta();
}

/// Gravação das denúncias (ver `denuncias/{id}` em firestore.rules).
abstract final class Denuncias {
  /// Injetável para teste de widget: sem ele, tocar em "Enviar" falaria com
  /// um Firestore que o ambiente de teste não tem.
  static Future<void> Function(Denuncia denuncia) enviador = _enviar;

  static Future<void> registrar(Denuncia denuncia) => enviador(denuncia);

  static Future<void> _enviar(Denuncia denuncia) async {
    final uid = Nuvem.instancia.uid;
    if (uid == null || uid.isEmpty) throw const DenunciaSemConta();
    final versao = await versaoDoApp();
    await FirebaseFirestore.instance
        .collection('denuncias')
        .add(
          denuncia.paraJson(
            uid: uid,
            criadoEm: FieldValue.serverTimestamp(),
            versao: versao,
            plataforma: plataformaDoApp(),
          ),
        );
  }
}

/// Monta a denúncia a partir da resposta da IA e da pergunta que a antecedeu.
/// [pergunta] pode ser nula (conversa importada ou primeira fala sem par):
/// nesse caso o campo vai vazio, e a denúncia ainda aponta a mensagem.
Denuncia denunciaDaResposta({
  required Mensagem resposta,
  Mensagem? pergunta,
  required String persona,
  required String? conversaId,
  required String motivo,
  String detalhe = '',
}) => Denuncia(
  motivo: motivo,
  persona: persona,
  conversaId: conversaId ?? '',
  mensagemId: resposta.id,
  pergunta: pergunta?.texto ?? '',
  resposta: resposta.texto,
  detalhe: detalhe,
);
