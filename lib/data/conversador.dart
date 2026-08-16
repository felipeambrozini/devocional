import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'estado.dart';
import 'ia.dart';
import 'modelos.dart';
import 'personas.dart';

/// Um turno de conversa com a persona: registra a pergunta no [Estado],
/// chama a inteligência artificial, grava a resposta e cuida do estado de
/// "respondendo"/erro que a tela mostra.
///
/// Saiu de `lib/telas/chat.dart` num refactor: a tela ficou só com o desenho,
/// e o fluxo inteiro (pergunta pendente → resposta → tentar de novo) ganhou
/// teste com um `chamar` falso, sem abrir HTTP nenhum.
///
/// [chamar] é a função `perguntar` de `ia.dart`, injetada pelo mesmo motivo
/// que o `cliente` de lá: o teste não tem como falar com a Google.
class Conversador extends ChangeNotifier {
  Conversador({
    required this.persona,
    required this.estado,
    required this.chamar,
  });

  final Persona persona;
  final Estado estado;
  final Future<String> Function({
    required Persona persona,
    required List<Mensagem> historico,
    required String pergunta,
  }) chamar;

  bool _respondendo = false;

  /// Falha da última tentativa, mostrada num balão de erro no rodapé da
  /// conversa com o botão de tentar de novo. Vive só aqui: um erro não é
  /// parte do histórico e não deve ser persistido.
  String? _erro;

  /// A pergunta que está no ar, para o "Tentar de novo" refazê-la sem que o
  /// usuário precise redigitar.
  String _ultimaPergunta = '';

  /// A tela foi fechada antes de a resposta chegar; não notificar depois do
  /// dispose (erro em modo debug) nem tocar no que não existe mais.
  bool _descartado = false;

  bool get respondendo => _respondendo;
  String? get erro => _erro;
  String get ultimaPergunta => _ultimaPergunta;

  /// Envia uma pergunta nova e espera a resposta.
  Future<void> enviar(String pergunta) async {
    final id = persona.id;
    // Perguntas antigas que ficaram pendentes ficam para trás: quem envia
    // uma pergunta nova seguiu a vida, e só a mais nova interessa.
    await estado.marcarRespondidas(id);
    await estado.registrarMensagem(
      id,
      Mensagem(
        id: novoIdDeMensagem(),
        papel: 'user',
        texto: pergunta,
        momento: DateTime.now().millisecondsSinceEpoch,
        // Pendente até a resposta chegar: sair da tela no meio da geração
        // deixa a pergunta marcada, e o reabrir oferece "Tentar de novo".
        pendente: true,
      ),
    );
    await _perguntar(pergunta);
  }

  /// Refaz a última pergunta que falhou, sem o usuário redigitar.
  Future<void> repetir() => _perguntar(_ultimaPergunta);

  /// Reabrir depois de uma resposta interrompida: a última pergunta ficou
  /// pendente, e a tela oferece "Tentar de novo" em vez de deixar a pergunta
  /// respondida pelo silêncio.
  void retomarInterrompida() {
    final mensagens = estado.mensagensDe(persona.id);
    final ultima = mensagens.isEmpty ? null : mensagens.last;
    if (ultima == null || !ultima.doUsuario || !ultima.pendente) return;
    _erro = 'A resposta anterior não chegou.';
    _ultimaPergunta = ultima.texto;
    notifyListeners();
  }

  /// Chama a IA com a pergunta já registrada no histórico.
  Future<void> _perguntar(String pergunta) async {
    _respondendo = true;
    _erro = null;
    _ultimaPergunta = pergunta;
    notifyListeners();
    try {
      final resposta = await chamar(
        persona: persona,
        historico: estado.mensagensDe(persona.id),
        pergunta: pergunta,
      );
      await estado.registrarMensagem(
        persona.id,
        Mensagem(
          id: novoIdDeMensagem(),
          papel: 'assistant',
          texto: resposta,
          momento: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      // A resposta chegou: nada fica pendente nesta conversa.
      await estado.marcarRespondidas(persona.id);
    } on IaException catch (erro) {
      _erro = erro.mensagem;
    } finally {
      _respondendo = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    // A resposta pode chegar depois de a tela ter sido fechada (o usuário
    // voltou e o widget foi desmontado); notificar um ChangeNotifier
    // descartado é erro em modo debug.
    if (_descartado) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}