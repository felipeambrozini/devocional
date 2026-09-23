import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import 'estado.dart';
import 'eventos.dart';
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
    this.conversaId,
    this.duracaoDoErro = const Duration(seconds: 2),
    this.intervaloMinimo = const Duration(seconds: 3),
  });

  final Persona persona;
  final Estado estado;
  final Future<String> Function({
    required Persona persona,
    required List<Mensagem> historico,
    required String pergunta,
  })
  chamar;

  /// A conversa em que este turno escreve. null enquanto é uma conversa nova
  /// que ainda não tem a primeira mensagem: o id nasce na primeira pergunta
  /// ([enviar] chama [Estado.novaConversa]) e fica visível em [conversaId].
  final String? conversaId;

  String? _id;

  bool _respondendo = false;

  /// Qual turno de pergunta/resposta vale agora. [interromper] e um novo
  /// [_perguntar] passam a geração adiante: a resposta de uma geração antiga
  /// que chegar depois é descartada, em vez de entrar no histórico ou de
  /// derrubar o "respondendo" do turno atual.
  int _geracao = 0;

  /// Falha da última tentativa, mostrada num balão de erro no rodapé da
  /// conversa com o botão de tentar de novo. Vive só aqui: um erro não é
  /// parte do histórico e não deve ser persistido.
  String? _erro;

  /// O balão de erro some sozinho depois de [duracaoDoErro]: um erro de rede
  /// ou de serviço é momentâneo, e quem voltou à tela nesse meio-tempo não
  /// precisa de aviso em pé.
  Timer? _temporizadorDoErro;

  /// A pergunta que está no ar, para o "Tentar de novo" refazê-la sem que o
  /// usuário precise redigitar.
  String _ultimaPergunta = '';

  /// Menor tempo entre dois [enviar]: a chave da Gemini é uma só para todo
  /// mundo que usa o app (embutida no build, sem servidor por trás), e mandar
  /// mensagens em sequência esgota a cota gratuita para todos os usuários, não
  /// só para quem está mandando. Não protege contra alguém que fale direto
  /// com a API por fora do app — só contra o próprio app sendo usado assim.
  final Duration intervaloMinimo;

  DateTime? _ultimoEnvio;

  /// A tela foi fechada antes de a resposta chegar; não notificar depois do
  /// dispose (erro em modo debug) nem tocar no que não existe mais.
  bool _descartado = false;

  bool get respondendo => _respondendo;

  final Duration duracaoDoErro;

  String? get erro => _erro;
  String get ultimaPergunta => _ultimaPergunta;

  /// O id de verdade da conversa: o recebido no construtor, ou o que nasceu
  /// com a primeira pergunta. null só antes da primeira mensagem.
  String? get id => _id ?? conversaId;

  /// Envia uma pergunta nova e espera a resposta.
  ///
  /// Chamadas em sequência mais rápida que [intervaloMinimo] são ignoradas em
  /// silêncio: a tela já desabilita o campo enquanto [respondendo] é `true`,
  /// então só se chega aqui de novo por um toque logo depois de uma resposta
  /// chegar — o intervalo é a defesa contra isso virar spam de verdade.
  Future<void> enviar(String pergunta) async {
    final agora = DateTime.now();
    final ultimoEnvio = _ultimoEnvio;
    if (ultimoEnvio != null &&
        agora.difference(ultimoEnvio) < intervaloMinimo) {
      return;
    }
    _ultimoEnvio = agora;
    unawaited(registrarChatMensagem(persona.id));
    // Uma conversa reaberta pelo histórico já chega com [conversaId]: a
    // primeira mensagem enviada nela precisa continuar essa conversa, não
    // abrir outra vazia. Só quando não há [conversaId] (chat novo) é que
    // nasce uma conversa de verdade, na primeira pergunta.
    final id = _id ??= conversaId ?? await _novaConversa(pergunta);
    // Perguntas antigas que ficaram pendentes ficam para trás: quem envia
    // uma pergunta nova seguiu a vida, e só a mais nova interessa.
    await estado.marcarRespondidas(persona.id, id);
    await estado.registrarMensagem(
      persona.id,
      id,
      Mensagem(
        id: novoIdDeMensagem(),
        papel: Mensagem.papelUsuario,
        texto: pergunta,
        momento: DateTime.now().millisecondsSinceEpoch,
        // Pendente até a resposta chegar: sair da tela no meio da geração
        // deixa a pergunta marcada, e o reabrir oferece "Tentar de novo".
        pendente: true,
      ),
    );
    await _perguntar(pergunta);
  }

  Future<String> _novaConversa(String titulo) async {
    final conversa = await estado.novaConversa(persona.id, titulo: titulo);
    return conversa.id;
  }

  Future<void> repetir() => _perguntar(_ultimaPergunta);

  /// Para a resposta em andamento (o botão parar da tela): a pergunta
  /// continua no histórico como pendente e a tela oferece "Tentar de novo",
  /// como quando a resposta não chega por rede. A resposta que chegar depois
  /// do toque é descartada, não entra no histórico.
  void interromper() {
    if (!_respondendo) return;
    _geracao++;
    _respondendo = false;
    _mostrarErro('Resposta interrompida.');
  }

  /// Reabrir depois de uma resposta interrompida: a última pergunta ficou
  /// pendente, e a tela oferece "Tentar de novo" em vez de deixar a pergunta
  /// respondida pelo silêncio.
  void retomarInterrompida() {
    final id = this.id;
    if (id == null) return;
    final mensagens = estado.mensagensDe(persona.id, id);
    final ultima = mensagens.isEmpty ? null : mensagens.last;
    if (ultima == null || !ultima.doUsuario || !ultima.pendente) return;
    _mostrarErro('A resposta anterior não chegou.');
    _ultimaPergunta = ultima.texto;
  }

  /// Mostra o erro e agenda o sumiço: o balão não fica fixo, ele sai da tela
  /// sozinho depois de [duracaoDoErro]. Uma nova falha no meio do caminho
  /// reinicia a contagem.
  void _mostrarErro(String mensagem) {
    _erro = mensagem;
    _temporizadorDoErro?.cancel();
    _temporizadorDoErro = Timer(duracaoDoErro, () {
      if (_descartado) return;
      _erro = null;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _perguntar(String pergunta) async {
    final id = this.id;
    if (id == null) return;
    final geracao = ++_geracao;
    _respondendo = true;
    _erro = null;
    _temporizadorDoErro?.cancel();
    _ultimaPergunta = pergunta;
    notifyListeners();
    try {
      // A pergunta atual já está no histórico como mensagem pendente (foi
      // gravada em `enviar` antes de chamar `_perguntar`) e vai também no
      // parâmetro `pergunta`: sem excluir esse último item, `ia.dart` recebe
      // a pergunta duas vezes e a envia em dobro para o modelo.
      final historico = estado.mensagensDe(persona.id, id);
      final historicoSemPendente =
          historico.isNotEmpty &&
              historico.last.doUsuario &&
              historico.last.pendente
          ? historico.sublist(0, historico.length - 1)
          : historico;
      final resposta = await chamar(
        persona: persona,
        historico: historicoSemPendente,
        pergunta: pergunta,
      );
      // Parou no meio do caminho (ou um turno novo assumiu): a resposta
      // tardia não entra no histórico.
      if (geracao != _geracao) return;
      await estado.registrarMensagem(
        persona.id,
        id,
        Mensagem(
          id: novoIdDeMensagem(),
          papel: Mensagem.papelAssistente,
          texto: resposta,
          momento: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await estado.marcarRespondidas(persona.id, id);
    } on IaExcecao catch (erro) {
      if (geracao != _geracao) return;
      _mostrarErro(erro.mensagem);
    } finally {
      // Só a geração atual derruba o estado: um turno novo (repetir) já
      // assumiu o "respondendo".
      if (geracao == _geracao) {
        _respondendo = false;
        notifyListeners();
      }
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
    _temporizadorDoErro?.cancel();
    super.dispose();
  }
}
