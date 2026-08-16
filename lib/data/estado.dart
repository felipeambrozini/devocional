import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'canon.dart';
import 'modelos.dart';

/// Estado persistido do app: progresso de leitura, favoritos, notas e preferências.
///
/// ponytail: um blob JSON por domínio em SharedPreferences, sem banco. Escala para
/// centenas de notas; o teto é o localStorage da web, por volta de 5 MB. Se as notas
/// crescerem além disso, o caminho é `drift`. Escolhido por ser o único
/// armazenamento que funciona igual em mobile, web e desktop sem ramificar código.
class Estado extends ChangeNotifier {
  Estado(this._prefs) {
    _lerTudo();
  }

  static const _kLidos = 'dias_lidos';
  static const _kMarcacoes = 'marcacoes';
  static const _kVersao = 'versao_preferida';
  static const _kUltima = 'ultima_leitura';
  static const _kEscala = 'escala_de_leitura';
  static const _kModoDoTema = 'modo_do_tema';
  static const _kAjudaDispensada = 'ajuda_dispensada';
  static const _kLembretesAtivos = 'lembretes_ativos';
  static const _kMinutosLembreteManha = 'minutos_lembrete_manha';
  static const _kMinutosLembreteNoite = 'minutos_lembrete_noite';
  static const _kConversas = 'conversas';

  /// 6h e 18h, os horários padrão do lembrete. Minutos desde meia-noite, não
  /// `TimeOfDay`: `estado.dart` não importa `material.dart`, e um `int` grava
  /// direto no `SharedPreferences` sem serialização própria.
  static const minutosPadraoManha = 6 * 60;
  static const minutosPadraoNoite = 18 * 60;

  final SharedPreferences _prefs;

  /// Datas 'DD-MM' do cronograma já marcadas como lidas.
  Set<String> _lidos = {};

  /// Favoritos e notas, indexados por [Marcacao.chave].
  Map<String, Marcacao> _marcacoes = {};

  Versao _versao = Versao.bkj;

  /// Onde a leitura parou, para o botão "continuar".
  (String, int)? _ultimaLeitura;

  /// Multiplicador do tamanho do texto de leitura. Ver [escalasDeLeitura].
  double _escalaDeLeitura = 1.0;

  /// Claro, escuro ou o do aparelho. Padrão: o do aparelho.
  ModoDoTema _modoDoTema = ModoDoTema.sistema;

  /// A primeira visita ainda não dispensou o cartão "Como usar" da Hoje.
  bool _ajudaDispensada = false;

  /// Se os três lembretes diários estão ligados. Padrão false: notificação é
  /// opt-in, nunca ligada sem o usuário pedir.
  bool _lembretesAtivos = false;

  int _minutosLembreteManha = minutosPadraoManha;
  int _minutosLembreteNoite = minutosPadraoNoite;

  /// Histórico das conversas do chat, indexado pelo id da persona (ver
  /// `lib/data/personas.dart`). Vai sempre ao SharedPreferences, e quem entra
  /// na conta na web também o sincroniza na nuvem (ver `nuvem.dart`).
  Map<String, List<Mensagem>> _conversas = {};

  static Future<Estado> abrir() async =>
      Estado(await SharedPreferences.getInstance());

  void _lerTudo() {
    _lidos = (_prefs.getStringList(_kLidos) ?? const []).toSet();

    final marcacoesCruas = _prefs.getString(_kMarcacoes);
    if (marcacoesCruas != null && marcacoesCruas.isNotEmpty) {
      try {
        final lista = json.decode(marcacoesCruas) as List;
        _marcacoes = {};
        for (final item in lista) {
          final marcacao = Marcacao.doJson(item as Map<String, dynamic>);
          _marcacoes[marcacao.chave] = marcacao;
        }
      } catch (_) {
        // Dado corrompido não deve impedir o app de abrir. Perde-se o índice, não a fé.
        _marcacoes = {};
      }
    }

    final versaoSalva = _prefs.getString(_kVersao);
    _versao = Versao.values.firstWhere(
      (v) => v.pasta == versaoSalva,
      orElse: () => Versao.bkj,
    );

    final ultima = _prefs.getString(_kUltima);
    if (ultima != null) {
      final partes = ultima.split('/');
      if (partes.length == 2) {
        final capitulo = int.tryParse(partes[1]);
        if (capitulo != null && livroPorSlug(partes[0]) != null) {
          _ultimaLeitura = (partes[0], capitulo);
        }
      }
    }

    // Um valor gravado por uma versão futura, ou corrompido, não deve deixar o
    // app com texto ilegível: só passa o que está na lista de passos conhecidos.
    final escala = _prefs.getDouble(_kEscala);
    if (escala != null && escalasDeLeitura.contains(escala)) {
      _escalaDeLeitura = escala;
    }

    final modo = _prefs.getString(_kModoDoTema);
    _modoDoTema = ModoDoTema.values.firstWhere(
      (m) => m.chave == modo,
      orElse: () => ModoDoTema.sistema,
    );

    _ajudaDispensada = _prefs.getBool(_kAjudaDispensada) ?? false;

    _lembretesAtivos = _prefs.getBool(_kLembretesAtivos) ?? false;
    _minutosLembreteManha = _minutosValidos(
      _prefs.getInt(_kMinutosLembreteManha),
      minutosPadraoManha,
    );
    _minutosLembreteNoite = _minutosValidos(
      _prefs.getInt(_kMinutosLembreteNoite),
      minutosPadraoNoite,
    );

    final conversasCruas = _prefs.getString(_kConversas);
    if (conversasCruas != null && conversasCruas.isNotEmpty) {
      try {
        final mapa = json.decode(conversasCruas) as Map<String, dynamic>;
        _conversas = {};
        for (final entrada in mapa.entries) {
          if (entrada.value is! List) continue;
          _conversas[entrada.key] = [
            for (final item in entrada.value as List)
              if (item is Map<String, dynamic>) Mensagem.doJson(item),
          ];
        }
      } catch (_) {
        // Histórico corrompido não deve impedir o app de abrir; perde-se a
        // conversa, não a fé. Mesma regra das marcações acima.
        _conversas = {};
      }
    }
  }

  /// Um valor fora de 0..1439 não é um horário do dia; volta ao padrão em vez
  /// de deixar o lembrete agendado para uma hora que não existe.
  int _minutosValidos(int? gravado, int padrao) =>
      (gravado != null && gravado >= 0 && gravado < 24 * 60) ? gravado : padrao;

  // --- claro ou escuro ------------------------------------------------------ //

  ModoDoTema get modoDoTema => _modoDoTema;

  Future<void> definirModoDoTema(ModoDoTema novo) async {
    if (novo == _modoDoTema) return;
    _modoDoTema = novo;
    notifyListeners();
    await _prefs.setString(_kModoDoTema, novo.chave);
  }

  // --- lembretes diários ---------------------------------------------------- //

  bool get lembretesAtivos => _lembretesAtivos;

  /// Minutos desde meia-noite. Some ao aparelho quem lê a UI; o `Estado` só
  /// guarda o número.
  int get minutosLembreteManha => _minutosLembreteManha;
  int get minutosLembreteNoite => _minutosLembreteNoite;

  /// Só liga/desliga e persiste; quem agenda de verdade no plugin é a tela que
  /// chama isto, com `Lembretes.instancia` (`estado.dart` não fala com
  /// plataforma nenhuma, só com `SharedPreferences`).
  Future<void> definirLembretesAtivos(bool novo) async {
    if (novo == _lembretesAtivos) return;
    _lembretesAtivos = novo;
    notifyListeners();
    await _prefs.setBool(_kLembretesAtivos, novo);
  }

  Future<void> definirHorariosDeLembrete({
    required int minutosManha,
    required int minutosNoite,
  }) async {
    if (minutosManha == _minutosLembreteManha &&
        minutosNoite == _minutosLembreteNoite) {
      return;
    }
    _minutosLembreteManha = minutosManha;
    _minutosLembreteNoite = minutosNoite;
    notifyListeners();
    await _prefs.setInt(_kMinutosLembreteManha, minutosManha);
    await _prefs.setInt(_kMinutosLembreteNoite, minutosNoite);
  }

  // --- tamanho do texto de leitura ----------------------------------------- //

  double get escalaDeLeitura => _escalaDeLeitura;

  Future<void> definirEscalaDeLeitura(double nova) async {
    if (nova == _escalaDeLeitura || !escalasDeLeitura.contains(nova)) return;
    _escalaDeLeitura = nova;
    notifyListeners();
    await _prefs.setDouble(_kEscala, nova);
  }

  // --- ajuda de primeira visita ------------------------------------------- //

  bool get ajudaDispensada => _ajudaDispensada;

  /// Ajuda é para quem chega: depois de "Entendi", não volta nunca mais.
  Future<void> dispensarAjuda() async {
    if (_ajudaDispensada) return;
    _ajudaDispensada = true;
    notifyListeners();
    await _prefs.setBool(_kAjudaDispensada, true);
  }

  // --- versão preferida ---------------------------------------------------- //

  Versao get versao => _versao;

  Future<void> definirVersao(Versao nova) async {
    if (nova == _versao) return;
    _versao = nova;
    notifyListeners();
    await _prefs.setString(_kVersao, nova.pasta);
  }

  // --- progresso do cronograma --------------------------------------------- //

  int get diasLidos => _lidos.length;

  bool foiLido(String data) => _lidos.contains(data);

  Future<void> alternarLido(String data) async {
    if (!_lidos.remove(data)) _lidos.add(data);
    notifyListeners();
    await _prefs.setStringList(_kLidos, _lidos.toList()..sort());
  }

  /// Fração do cronograma concluída, para a barra de progresso.
  ///
  /// O total entra por parâmetro em vez de ser 365 fixo: em ano bissexto o
  /// cronograma tem 366 dias, e com o divisor errado marcar o ano inteiro daria
  /// mais de cem por cento. Quem chama pega o número em [Conteudo.diasDoAno], e
  /// assim o Estado continua sem saber de assets.
  double progressoDoAno(int totalDeDias) => _lidos.length / totalDeDias;

  // --- última leitura ------------------------------------------------------ //

  (String, int)? get ultimaLeitura => _ultimaLeitura;

  Future<void> registrarLeitura(String livro, int capitulo) async {
    _ultimaLeitura = (livro, capitulo);
    notifyListeners();
    await _prefs.setString(_kUltima, '$livro/$capitulo');
  }

  // --- favoritos e notas --------------------------------------------------- //

  List<Marcacao> get marcacoes {
    final lista = _marcacoes.values.toList();
    // Ordem canônica, depois capítulo e versículo: a lista de favoritos lê como
    // uma Bíblia, não como um histórico de cliques.
    lista.sort((a, b) {
      final ordemA = canon.indexWhere((l) => l.slug == a.livro);
      final ordemB = canon.indexWhere((l) => l.slug == b.livro);
      if (ordemA != ordemB) return ordemA.compareTo(ordemB);
      if (a.capitulo != b.capitulo) return a.capitulo.compareTo(b.capitulo);
      return a.versiculo.compareTo(b.versiculo);
    });
    return lista;
  }

  List<Marcacao> get comNota =>
      marcacoes.where((m) => m.nota.trim().isNotEmpty).toList();

  Marcacao? marcacaoDe(
    Versao versao,
    String livro,
    int capitulo,
    int versiculo,
  ) => _marcacoes['${versao.pasta}/$livro/$capitulo/$versiculo'];

  bool ehFavorito(Versao versao, String livro, int capitulo, int versiculo) =>
      _marcacoes.containsKey('${versao.pasta}/$livro/$capitulo/$versiculo');

  Future<void> alternarFavorito(
    Versao versao,
    String livro,
    int capitulo,
    int versiculo,
  ) async {
    final marcacao = Marcacao(
      versao: versao,
      livro: livro,
      capitulo: capitulo,
      versiculo: versiculo,
    );
    final existente = _marcacoes[marcacao.chave];
    if (existente == null) {
      _marcacoes[marcacao.chave] = marcacao;
    } else if (existente.nota.trim().isEmpty) {
      _marcacoes.remove(marcacao.chave);
    } else {
      // Desmarcar um versículo que tem nota apagaria a nota junto. A nota é trabalho
      // do usuário, então ela manda: o favorito permanece enquanto houver nota.
      return;
    }
    notifyListeners();
    await _gravarMarcacoes();
  }

  Future<void> definirNota(
    Versao versao,
    String livro,
    int capitulo,
    int versiculo,
    String nota,
  ) async {
    final base = Marcacao(
      versao: versao,
      livro: livro,
      capitulo: capitulo,
      versiculo: versiculo,
    );
    if (nota.trim().isEmpty) {
      final existente = _marcacoes[base.chave];
      if (existente == null) return;
      _marcacoes[base.chave] = existente.comNota('');
    } else {
      _marcacoes[base.chave] = base.comNota(nota.trim());
    }
    notifyListeners();
    await _gravarMarcacoes();
  }

  Future<void> removerMarcacao(Marcacao marcacao) async {
    if (_marcacoes.remove(marcacao.chave) == null) return;
    notifyListeners();
    await _gravarMarcacoes();
  }

  Future<void> _gravarMarcacoes() async {
    final lista = [for (final m in _marcacoes.values) m.paraJson()];
    await _prefs.setString(_kMarcacoes, json.encode(lista));
  }

  // --- conversas do chat --------------------------------------------------- //

  /// Teto de mensagens por conversa. O histórico inteiro volta ao modelo a
  /// cada pergunta, então a cauda antiga além disto custa contexto sem ganhar
  /// qualidade; também segura o tamanho do documento no Firestore.
  static const _maxMensagensPorConversa = 120;

  /// O histórico da persona, na ordem em que foi conversado.
  List<Mensagem> mensagensDe(String persona) =>
      List.unmodifiable(_conversas[persona] ?? const []);

  Future<void> registrarMensagem(String persona, Mensagem mensagem) async {
    final lista = _conversas[persona] ??= [];
    lista.add(mensagem);
    if (lista.length > _maxMensagensPorConversa) {
      lista.removeRange(0, lista.length - _maxMensagensPorConversa);
    }
    notifyListeners();
    await _gravarConversas();
  }

  Future<void> limparConversa(String persona) async {
    if (_conversas.remove(persona) == null) return;
    notifyListeners();
    await _gravarConversas();
  }

  Future<void> _gravarConversas() async {
    final objeto = <String, dynamic>{
      for (final e in _conversas.entries)
        e.key: [for (final m in e.value) m.paraJson()],
    };
    await _prefs.setString(_kConversas, json.encode(objeto));
  }

  /// O que a cópia na nuvem recebe para as conversas, num JSON à parte do
  /// `exportar()`: o histórico não entra na cópia de segurança manual que se
  /// exporta e importa, porque aquela é sobre trabalho do usuário (notas,
  /// favoritos) e esta é só o cache do chat entre aparelhos.
  String serializarConversas() => json.encode({
    for (final e in _conversas.entries)
      e.key: [for (final m in e.value) m.paraJson()],
  });

  /// Funde o histórico remoto com o local, por id de mensagem: uma mensagem
  /// que já existe aqui não é duplicada, e nada que existia só num dos lados
  /// se perde. Lixo remoto é engolido, como em `importar()`.
  Future<void> fundirConversas(String remota) async {
    try {
      final mapa = json.decode(remota) as Map<String, dynamic>;
      var mudou = false;
      for (final entrada in mapa.entries) {
        if (entrada.value is! List) continue;
        final lista = [...(_conversas[entrada.key] ?? const <Mensagem>[])];
        final ids = lista.map((m) => m.id).toSet();
        var mudouNesta = false;
        for (final cru in entrada.value as List) {
          if (cru is! Map<String, dynamic>) continue;
          final mensagem = Mensagem.doJson(cru);
          if (mensagem.id.isEmpty || !ids.add(mensagem.id)) continue;
          lista.add(mensagem);
          mudouNesta = true;
        }
        if (mudouNesta) {
          lista.sort((a, b) => a.momento.compareTo(b.momento));
          if (lista.length > _maxMensagensPorConversa) {
            lista.removeRange(0, lista.length - _maxMensagensPorConversa);
          }
          _conversas[entrada.key] = lista;
          mudou = true;
        }
      }
      if (mudou) {
        notifyListeners();
        await _gravarConversas();
      }
    } catch (_) {
      // Cópia ilegível: o local continua intacto e vai subir por cima.
    }
  }

  // --- cópia de segurança --------------------------------------------------- //

  /// Versão do formato da cópia. Existe para que uma cópia velha ainda possa ser
  /// lida se o formato mudar, em vez de ser recusada sem explicação.
  static const versaoDaCopia = 1;

  /// Tudo que o usuário escreveu ou marcou, num JSON legível.
  ///
  /// Só favoritos, notas e dias lidos. A versão preferida e o tamanho da fonte
  /// ficam de fora de propósito: são preferências do aparelho, e restaurar uma
  /// cópia do celular no computador não deve mudar o tamanho da letra de lá.
  String exportar() => const JsonEncoder.withIndent('  ').convert({
    'versao': versaoDaCopia,
    'marcacoes': [for (final m in _marcacoes.values) m.paraJson()],
    'dias_lidos': _lidos.toList()..sort(),
  });

  /// Funde uma cópia com o que já existe. Devolve quantas marcações e quantos
  /// dias entraram, ou lança [FormatException] se o texto não for uma cópia.
  ///
  /// Funde, não substitui: importar no aparelho errado, ou importar duas vezes,
  /// nunca apaga uma nota que só existe aqui. Em conflito de mesma referência,
  /// vence quem tem nota, pela mesma razão de [alternarFavorito]: a nota é
  /// trabalho do usuário e some sem ter como voltar.
  Future<(int marcacoes, int dias)> importar(String texto) async {
    final Object? cru;
    try {
      cru = json.decode(texto);
    } on FormatException {
      throw const FormatException('O texto não é um JSON válido.');
    }
    if (cru is! Map<String, dynamic>) {
      throw const FormatException(
        'A cópia deveria começar com um objeto JSON.',
      );
    }
    if (cru['versao'] != versaoDaCopia) {
      throw FormatException(
        'Cópia na versão ${cru['versao']}; este app lê a versão $versaoDaCopia.',
      );
    }

    var novasMarcacoes = 0;
    for (final item in (cru['marcacoes'] as List? ?? const [])) {
      final Marcacao chegando;
      try {
        chegando = Marcacao.doJson(item as Map<String, dynamic>);
      } catch (_) {
        // Uma entrada quebrada não deve derrubar a importação inteira.
        continue;
      }
      final existente = _marcacoes[chegando.chave];
      if (existente != null && chegando.nota.trim().isEmpty) continue;
      if (existente == null || existente.nota != chegando.nota) {
        novasMarcacoes++;
      }
      _marcacoes[chegando.chave] = chegando;
    }

    var novosDias = 0;
    for (final dia in (cru['dias_lidos'] as List? ?? const [])) {
      if (dia is String && _lidos.add(dia)) novosDias++;
    }

    notifyListeners();
    await _gravarMarcacoes();
    await _prefs.setStringList(_kLidos, _lidos.toList()..sort());
    return (novasMarcacoes, novosDias);
  }
}

/// Acesso ao [Estado] pela árvore de widgets, sem pacote de gerenciamento de estado.
/// Seis telas não têm o problema que Riverpod ou bloc resolvem.
class EscopoDoEstado extends InheritedNotifier<Estado> {
  const EscopoDoEstado({
    super.key,
    required Estado estado,
    required super.child,
  }) : super(notifier: estado);

  static Estado de(BuildContext context) {
    final escopo = context.dependOnInheritedWidgetOfExactType<EscopoDoEstado>();
    assert(
      escopo?.notifier != null,
      'EscopoDoEstado ausente acima deste widget',
    );
    return escopo!.notifier!;
  }
}
