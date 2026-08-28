/// Uma conversa do chat com uma persona: um fio de [Mensagem] com identidade,
/// título e momento próprios.
///
/// Antes havia uma conversa só por persona, e o histórico era a própria lista
/// de mensagens. Agora cada persona guarda quantas conversas quiser; [titulo]
/// (a primeira pergunta) e [momento] (a última fala) são o que a lista de
/// histórico mostra. [id] é o que a fusão com a nuvem usa para não duplicar,
/// como o id das mensagens.
class Conversa {
  Conversa({
    required this.id,
    required this.titulo,
    required this.momento,
    required this.mensagens,
    this.cortada = false,
  });

  factory Conversa.doJson(Map<String, dynamic> json) => Conversa(
    id: json['id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    momento: json['momento'] as int? ?? 0,
    cortada: json['cortada'] as bool? ?? false,
    mensagens: [
      for (final m in json['mensagens'] as List? ?? const [])
        if (m is Map<String, dynamic>) Mensagem.doJson(m),
    ],
  );

  final String id;

  /// A primeira pergunta do visitante. Vazio numa conversa que só recebeu
  /// falas da persona (raro, mas possível vinda de uma migração).
  final String titulo;

  /// A última fala, em milissegundos desde a época. É o que a lista de
  /// histórico mostra como data e o que a ordena, do mais recente ao mais
  /// antigo.
  final int momento;

  final List<Mensagem> mensagens;

  /// Verdadeiro quando esta conversa atingiu o teto de mensagens e as falas
  /// mais antigas saíram do histórico. O chat mostra um aviso quieto para o
  /// usuário saber que o corte aconteceu, em vez de falas sumindo em silêncio.
  final bool cortada;

  Map<String, dynamic> paraJson() => {
    'id': id,
    'titulo': titulo,
    'momento': momento,
    'cortada': cortada,
    'mensagens': [for (final m in mensagens) m.paraJson()],
  };

  /// Corta do começo o que passar do [teto] e devolve a lista com se cortou.
  /// A regra única do corte do histórico, usada por quem cresce a conversa
  /// ([comMensagem] e [comMensagemDeTodas]).
  static (List<Mensagem>, bool) _aplicarTeto(
    List<Mensagem> mensagens,
    int? teto,
  ) {
    var cortou = false;
    if (teto != null && mensagens.length > teto) {
      cortou = true;
      mensagens.removeRange(0, mensagens.length - teto);
    }
    return (mensagens, cortou);
  }

  /// Uma cópia com a mensagem nova no fim e o momento atualizado, para o
  /// histórico listar a conversa na posição de quem acabou de falar.
  Conversa comMensagem(Mensagem mensagem, {int? teto}) {
    final (novas, cortou) = _aplicarTeto([...mensagens, mensagem], teto);
    return Conversa(
      id: id,
      titulo: titulo.isEmpty && mensagem.doUsuario ? mensagem.texto : titulo,
      momento: mensagem.momento,
      mensagens: novas,
      cortada: cortada || cortou,
    );
  }

  /// Uma cópia com várias mensagens fundidas, ordenadas por momento. Usada
  /// pela fusão com a nuvem, que pode trazer um lote inteiro de uma vez.
  Conversa comMensagemDeTodas(List<Mensagem> novas, {int? teto}) {
    final (todas, cortou) = _aplicarTeto(
      [...mensagens, ...novas]..sort((a, b) => a.momento.compareTo(b.momento)),
      teto,
    );
    final ultimo = todas.last.momento;
    return Conversa(
      id: id,
      titulo: titulo,
      momento: ultimo > momento ? ultimo : momento,
      mensagens: todas,
      cortada: cortada || cortou,
    );
  }

  /// Uma cópia só com o título novo. Usada pela fusão, que pode trazer o
  /// título de uma conversa que nasceu apagada ou sem fala do visitante.
  Conversa comTitulo(String novo) => Conversa(
    id: id,
    titulo: novo,
    momento: momento,
    mensagens: mensagens,
    cortada: cortada,
  );
}

/// Uma mensagem do chat com uma persona.
///
/// [id] é o que faz a fusão com a cópia da nuvem não duplicar: uma mensagem
/// que chega com um id já visto é ignorada. [momento] em milissegundos desde
/// a época, para ordenar depois de uma fusão de dois aparelhos.
///
/// [papel] é string de propósito, como a ponte `Leitura` de
/// `AchadoDevocional`: o chat envia papéis ao Gemini como "user"/"model", e a
/// UI lê "assistant" com [doUsuario] para saber de que lado desenhar o balão.
class Mensagem {
  /// Os papéis como o chat grava e lê: "user" fala, "assistant" responde.
  /// Constantes e não literais soltos: um erro de digitação num papel não dá
  /// erro de compilação — dá balão do lado errado. O vocabulário do Gemini
  /// ("user"/"model") fica em `ia.dart`, que traduz na hora do pedido.
  static const papelUsuario = 'user';
  static const papelAssistente = 'assistant';

  const Mensagem({
    required this.id,
    required this.papel,
    required this.texto,
    required this.momento,
    this.pendente = false,
  });

  factory Mensagem.doJson(Map<String, dynamic> json) => Mensagem(
    id: json['id'] as String? ?? '',
    papel: json['papel'] as String? ?? papelAssistente,
    texto: json['texto'] as String? ?? '',
    momento: json['momento'] as int? ?? 0,
    pendente: json['pendente'] as bool? ?? false,
  );

  final String id;
  final String papel;
  final String texto;
  final int momento;

  /// A pergunta foi enviada e a resposta não chegou (a pessoa saiu da tela no
  /// meio da geração). O chat reabre oferecendo "Tentar de novo" em vez de
  /// deixar a pergunta respondida pelo silêncio. Só faz sentido em mensagem
  /// do usuário; vai junto na serialização para a marca sobreviver ao
  /// reabrir, ao trocar de aparelho e à nuvem.
  final bool pendente;

  bool get doUsuario => papel == papelUsuario;

  Map<String, dynamic> paraJson() => {
    'id': id,
    'papel': papel,
    'texto': texto,
    'momento': momento,
    if (pendente) 'pendente': true,
  };
}
