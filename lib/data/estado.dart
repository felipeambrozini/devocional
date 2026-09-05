import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'canon.dart';
import 'conversas.dart';
import 'modelos.dart';
import 'planos.dart';
import 'registro.dart';

/// Estado persistido do app: progresso de leitura, favoritos, notas e preferências.
///
/// ponytail: um blob JSON por domínio em SharedPreferences, sem banco. Escala para
/// centenas de notas; o teto é o localStorage da web, por volta de 5 MB. Se as notas
/// crescerem além disso, o caminho é `drift`. Escolhido por ser o único
/// armazenamento que funciona igual em Android e web sem ramificar código.
class Estado extends ChangeNotifier {
  Estado(this._prefs) {
    conversas = Conversas.ler(_prefs, notifyListeners);
    _lerTudo();
  }

  static const _kLidos = 'dias_lidos';
  static const _kMarcacoes = 'marcacoes';
  static const _kUltima = 'ultima_leitura';
  static const _kEscala = 'escala_de_leitura';
  // Pública (as outras são privadas de propósito): a notificação do lembrete
  // precisa ler o tema escolhido para colorir o destaque no Android, mesmo
  // com o app morto (ver `_corDoTema` em lib/data/lembretes.dart).
  static const chaveModoDoTema = 'modo_do_tema';
  static const _kAjudaDispensada = 'ajuda_dispensada';
  static const _kAceiteDeColeta = 'aceite_de_coleta';
  static const _kBaloesVisiveis = 'baloes_visiveis';
  static const _kBaloesTooltipDispensado = 'baloes_tooltip_dispensado';
  static const _kSwipeTooltipDispensado = 'swipe_tooltip_dispensado';
  static const _kSetasDoRodape = 'setas_do_rodape';
  static const _kLembretesAtivos = 'lembretes_ativos';
  static const _kMinutosLembreteManha = 'minutos_lembrete_manha';
  static const _kMinutosLembretePromessas = 'minutos_lembrete_promessas';
  static const _kMinutosLembreteLeitura = 'minutos_lembrete_leitura';
  static const _kMinutosLembreteNoite = 'minutos_lembrete_noite';
  static const _kPlanos = 'planos_do_usuario';
  static const _kPlanosLidos = 'planos_lidos';

  /// 6h e 18h, os horários padrão do lembrete. Minutos desde meia-noite, não
  /// `TimeOfDay`: `estado.dart` não importa `material.dart`, e um `int` grava
  /// direto no `SharedPreferences` sem serialização própria.
  static const minutosPadraoManha = 6 * 60;
  static const minutosPadraoPromessas = 6 * 60;
  static const minutosPadraoLeitura = 6 * 60;
  static const minutosPadraoNoite = 18 * 60;

  final SharedPreferences _prefs;

  /// Datas 'DD-MM' do cronograma já marcadas como lidas.
  Set<String> _lidos = {};

  /// Favoritos e notas, indexados por [Marcacao.chave].
  Map<String, Marcacao> _marcacoes = {};

  /// Onde a leitura parou, para o botão "continuar".
  (String, int)? _ultimaLeitura;

  /// Multiplicador do tamanho do texto de leitura. Ver [escalasDeLeitura].
  double _escalaDeLeitura = 1.0;

  /// Claro, escuro ou o do aparelho. Padrão: o do aparelho.
  ModoDoTema _modoDoTema = ModoDoTema.sistema;

  /// A primeira visita ainda não dispensou o cartão "Como usar" da Hoje.
  bool _ajudaDispensada = false;

  /// `null` = ainda não respondeu (ver TelaDeAceiteDeColeta); `true`/`false`
  /// é a resposta já dada.
  bool? _aceiteDeColeta;

  /// Se os balões de conversa aparecem nas bordas das telas. Padrão true: o
  /// chat só é descoberto pelos retratos, escondê-los esconde o caminho.
  bool _baloesVisiveis = true;

  /// Se o tooltip de primeiro uso dos balões já foi dispensado.
  bool _baloesTooltipDispensado = false;

  /// Se o tooltip de primeiro uso do deslize para trocar capítulo já foi dispensado.
  bool _swipeTooltipDispensado = false;

  /// Se os chevrons de capítulo aparecem no rodapé do leitor. Padrão true:
  /// na web são o caminho que quem só tem mouse descobre sem ler manual —
  /// e, desde que os atalhos de teclado chegaram, é escolha: quem prefere
  /// virar página por setas, Enter ou espaço esconde os botões na folha de
  /// ajustes. Existe só para a web; no celular o rodapé nem existe.
  bool _setasDoRodape = true;

  /// Se os três lembretes diários estão ligados. Padrão false: notificação é
  /// opt-in, nunca ligada sem o usuário pedir.
  bool _lembretesAtivos = false;

  int _minutosLembreteManha = minutosPadraoManha;
  int _minutosLembretePromessas = minutosPadraoPromessas;
  int _minutosLembreteLeitura = minutosPadraoLeitura;
  int _minutosLembreteNoite = minutosPadraoNoite;

  /// Planos de leitura do usuário, do mais novo ao mais antigo.
  List<PlanoDoUsuario> _planos = [];

  /// Dias marcados como lidos em cada plano, por id do plano. Nos planos
  /// compartilhados isto é só o espelho local: a verdade vive no documento
  /// `planos/{id}` do Firestore, e quem a aplica é `aplicarPlanoDaNuvem`.
  Map<String, Set<int>> _planosLidos = {};

  /// Histórico das conversas do chat, com a fusão e as lápides de exclusão.
  ///
  /// Moram em `lib/data/conversas.dart`; o Estado só repassa (ver os métodos
  /// no fim da classe), para que a notificação e a sincronia com a nuvem
  /// continuem ouvindo um único ChangeNotifier.
  late final Conversas conversas;

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
      } catch (erro, pilha) {
        // Dado corrompido não deve impedir o app de abrir. Perde-se o índice, não a fé.
        Registro.erro('Estado.lerTudo', erro, pilha);
        _marcacoes = {};
      }
    }

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

    final modo = _prefs.getString(chaveModoDoTema);
    _modoDoTema = ModoDoTema.values.firstWhere(
      (m) => m.chave == modo,
      orElse: () => ModoDoTema.sistema,
    );

    _ajudaDispensada = _prefs.getBool(_kAjudaDispensada) ?? false;
    _aceiteDeColeta = _prefs.getBool(_kAceiteDeColeta);

    _baloesVisiveis = _prefs.getBool(_kBaloesVisiveis) ?? true;

    _baloesTooltipDispensado =
        _prefs.getBool(_kBaloesTooltipDispensado) ?? false;

    _swipeTooltipDispensado = _prefs.getBool(_kSwipeTooltipDispensado) ?? false;

    _setasDoRodape = _prefs.getBool(_kSetasDoRodape) ?? true;

    _lembretesAtivos = _prefs.getBool(_kLembretesAtivos) ?? false;
    _minutosLembreteManha = _minutosValidos(
      _prefs.getInt(_kMinutosLembreteManha),
      minutosPadraoManha,
    );
    _minutosLembretePromessas = _minutosValidos(
      _prefs.getInt(_kMinutosLembretePromessas),
      minutosPadraoPromessas,
    );
    _minutosLembreteLeitura = _minutosValidos(
      _prefs.getInt(_kMinutosLembreteLeitura),
      minutosPadraoLeitura,
    );
    _minutosLembreteNoite = _minutosValidos(
      _prefs.getInt(_kMinutosLembreteNoite),
      minutosPadraoNoite,
    );

    final planosCru = _prefs.getString(_kPlanos);
    if (planosCru != null && planosCru.isNotEmpty) {
      try {
        _planos = [
          for (final item in json.decode(planosCru) as List)
            PlanoDoUsuario.doJson(item as Map<String, dynamic>),
        ];
      } catch (erro, pilha) {
        // Dado corrompido não deve impedir o app de abrir, mesma regra das
        // marcações.
        Registro.erro('Estado.lerTudo', erro, pilha);
        _planos = [];
      }
    }

    final planosLidosCru = _prefs.getString(_kPlanosLidos);
    if (planosLidosCru != null && planosLidosCru.isNotEmpty) {
      try {
        final mapa = json.decode(planosLidosCru) as Map<String, dynamic>;
        _planosLidos = {
          for (final MapEntry(key: id, value: dias) in mapa.entries)
            id: {
              for (final dia in dias as List)
                if (dia is int) dia,
            },
        };
      } catch (erro, pilha) {
        Registro.erro('Estado.lerTudo', erro, pilha);
        _planosLidos = {};
      }
    }
    // As conversas do chat são lidas pelo próprio `conversas`, no construtor.
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
    await _prefs.setString(chaveModoDoTema, novo.chave);
  }

  // --- lembretes diários ---------------------------------------------------- //

  bool get lembretesAtivos => _lembretesAtivos;

  /// Minutos desde meia-noite. Some ao aparelho quem lê a UI; o `Estado` só
  /// guarda o número.
  int get minutosLembreteManha => _minutosLembreteManha;
  int get minutosLembretePromessas => _minutosLembretePromessas;
  int get minutosLembreteLeitura => _minutosLembreteLeitura;
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
    required int minutosPromessas,
    required int minutosLeitura,
    required int minutosNoite,
  }) async {
    if (minutosManha == _minutosLembreteManha &&
        minutosPromessas == _minutosLembretePromessas &&
        minutosLeitura == _minutosLembreteLeitura &&
        minutosNoite == _minutosLembreteNoite) {
      return;
    }
    _minutosLembreteManha = minutosManha;
    _minutosLembretePromessas = minutosPromessas;
    _minutosLembreteLeitura = minutosLeitura;
    _minutosLembreteNoite = minutosNoite;
    notifyListeners();
    await _prefs.setInt(_kMinutosLembreteManha, minutosManha);
    await _prefs.setInt(_kMinutosLembretePromessas, minutosPromessas);
    await _prefs.setInt(_kMinutosLembreteLeitura, minutosLeitura);
    await _prefs.setInt(_kMinutosLembreteNoite, minutosNoite);
  }

  // --- balões de conversa ---------------------------------------------------- //

  bool get baloesVisiveis => _baloesVisiveis;

  bool get baloesTooltipDispensado => _baloesTooltipDispensado;

  /// Tooltip de primeiro uso dos balões: depois de "Entendi", não volta nunca mais.
  Future<void> dispensarBalcaoTooltip() async {
    if (_baloesTooltipDispensado) return;
    _baloesTooltipDispensado = true;
    notifyListeners();
    await _prefs.setBool(_kBaloesTooltipDispensado, true);
  }

  /// Volta a exibir a dica de primeiro uso dos balões (o caminho inverso de
  /// [dispensarBalcaoTooltip], usado pela folha de ajustes).
  Future<void> reexibirDicaDosBaloes() async {
    if (!_baloesTooltipDispensado) return;
    _baloesTooltipDispensado = false;
    notifyListeners();
    await _prefs.setBool(_kBaloesTooltipDispensado, false);
  }

  bool get swipeTooltipDispensado => _swipeTooltipDispensado;

  /// Tooltip de primeiro uso do deslize: depois de "Entendi", não volta nunca mais.
  Future<void> dispensarSwipeTooltip() async {
    if (_swipeTooltipDispensado) return;
    _swipeTooltipDispensado = true;
    notifyListeners();
    await _prefs.setBool(_kSwipeTooltipDispensado, true);
  }

  // --- setas do rodapé do leitor (web) -------------------------------------- //

  bool get setasDoRodape => _setasDoRodape;

  /// Só persiste; quem obedece é a barra de chevrons no leitor (`biblia.dart`).
  Future<void> definirSetasDoRodape(bool novo) async {
    if (novo == _setasDoRodape) return;
    _setasDoRodape = novo;
    notifyListeners();
    await _prefs.setBool(_kSetasDoRodape, novo);
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

  // --- aceite de coleta remota --------------------------------------------- //

  /// `null` enquanto o usuário não respondeu ao diálogo de aceite — é o sinal
  /// para [mostrarAceiteDeColetaSeNecessario] mostrá-lo. Só grava a escolha;
  /// quem liga ou desliga o Sentry e o Analytics de verdade é
  /// `aplicarAceiteDeColeta` (lib/data/coleta.dart), que este arquivo não
  /// importa de propósito — `Estado` não conhece Firebase.
  bool? get aceiteDeColeta => _aceiteDeColeta;

  Future<void> definirAceiteDeColeta(bool aceito) async {
    _aceiteDeColeta = aceito;
    notifyListeners();
    await _prefs.setBool(_kAceiteDeColeta, aceito);
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

  Marcacao? marcacaoDe(String livro, int capitulo, int versiculo) =>
      _marcacoes['$livro/$capitulo/$versiculo'];

  bool ehFavorito(String livro, int capitulo, int versiculo) =>
      _marcacoes.containsKey('$livro/$capitulo/$versiculo');

  Future<void> alternarFavorito(
    String livro,
    int capitulo,
    int versiculo,
  ) async {
    final marcacao = Marcacao(
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
    String livro,
    int capitulo,
    int versiculo,
    String nota,
  ) async {
    final base = Marcacao(
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

  // --- planos de leitura do usuário ---------------------------------------- //

  /// Do mais novo ao mais antigo.
  List<PlanoDoUsuario> get planosDoUsuario => List.unmodifiable(_planos);

  PlanoDoUsuario? planoDoUsuario(String id) {
    for (final plano in _planos) {
      if (plano.id == id) return plano;
    }
    return null;
  }

  bool foiLidoNoPlano(String planoId, int dia) =>
      _planosLidos[planoId]?.contains(dia) ?? false;

  int diasLidosDoPlano(String planoId) => _planosLidos[planoId]?.length ?? 0;

  Future<PlanoDoUsuario> criarPlano({
    required String titulo,
    required List<String> livros,
    required int dias,
    bool incluirDevocionais = false,
    bool devocionalAntes = true,
  }) async {
    final plano = PlanoDoUsuario(
      id: novoIdDePlano(),
      titulo: titulo.trim().isEmpty
          ? tituloDePlano(livros, dias)
          : titulo.trim(),
      livros: livros,
      dias: dias,
      criadoEm: DateTime.now(),
      incluirDevocionais: incluirDevocionais,
      devocionalAntes: devocionalAntes,
    );
    _planos.insert(0, plano);
    notifyListeners();
    await _gravarPlanos();
    return plano;
  }

  /// Revisa um plano depois de criado: nome, livros, dias, e a inclusão e
  /// posição dos devocionais — todas escolhas feitas em
  /// `lib/telas/novo_plano.dart` na criação. Mudar livros ou dias remonta os
  /// dias do plano (ver `PlanoDoUsuario.diasDoPlano`), o que reaproveita o
  /// número de cada dia para um conteúdo diferente — por isso o progresso
  /// marcado deste aparelho é apagado junto, para não sobrar dia marcado
  /// como lido que na verdade nunca foi. Quem chama já confirmou isso com o
  /// usuário antes (ver `editarPlano` em `lib/funcoes/planos_acoes.dart`).
  Future<PlanoDoUsuario> atualizarPlano(
    String id, {
    String? titulo,
    List<String>? livros,
    int? dias,
    bool? incluirDevocionais,
    bool? devocionalAntes,
  }) async {
    final i = _planos.indexWhere((p) => p.id == id);
    if (i == -1) throw ArgumentError('Plano não encontrado: $id');
    final atual = _planos[i];
    final novosLivros = livros ?? atual.livros;
    final novosDias = dias ?? atual.dias;
    final atualizado = PlanoDoUsuario(
      id: atual.id,
      titulo: titulo?.trim().isNotEmpty == true ? titulo!.trim() : atual.titulo,
      livros: novosLivros,
      dias: novosDias,
      criadoEm: atual.criadoEm,
      compartilhado: atual.compartilhado,
      criadoPor: atual.criadoPor,
      incluirDevocionais: incluirDevocionais ?? atual.incluirDevocionais,
      devocionalAntes: devocionalAntes ?? atual.devocionalAntes,
    );
    _planos[i] = atualizado;
    final mudouODiaADia =
        !_mesmaLista(novosLivros, atual.livros) || novosDias != atual.dias;
    if (mudouODiaADia) _planosLidos.remove(id);
    notifyListeners();
    await _gravarPlanos();
    if (mudouODiaADia) await _gravarPlanosLidos();
    return atualizado;
  }

  bool _mesmaLista(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> removerPlano(String id) async {
    final antes = _planos.length;
    _planos.removeWhere((p) => p.id == id);
    if (_planos.length == antes) return;
    _planosLidos.remove(id);
    notifyListeners();
    await _gravarPlanos();
    await _gravarPlanosLidos();
  }

  Future<void> alternarLidoNoPlano(String planoId, int dia) async {
    final lidos = _planosLidos.putIfAbsent(planoId, () => <int>{});
    if (!lidos.remove(dia)) lidos.add(dia);
    notifyListeners();
    await _gravarPlanosLidos();
  }

  /// Substitui os dias lidos de um plano inteiros. Usado pelos planos
  /// compartilhados, onde o documento é a verdade: alternar a partir de um
  /// espelho velho apagaria dias marcados noutro aparelho.
  Future<void> substituirLidosDoPlano(String planoId, Set<int> lidos) async {
    _planosLidos[planoId] = {...lidos};
    notifyListeners();
    await _gravarPlanosLidos();
  }

  /// Guarda (ou substitui) um plano que veio da nuvem, com os dias que o
  /// usuário já marcou lá. Usado pela sincronia ao entrar na conta e pela
  /// tela do plano aberto por link. Substitui pela cópia da nuvem em caso de
  /// duplicata: o documento é a verdade do plano compartilhado.
  Future<void> aplicarPlanoDaNuvem(
    PlanoDoUsuario plano, {
    required Set<int> lidos,
  }) async {
    final i = _planos.indexWhere((p) => p.id == plano.id);
    if (i >= 0) {
      // Já está na lista (aberto por link, ou outra cópia do app): troca no
      // lugar, para a posição na lista não saltar a cada abertura.
      _planos[i] = plano;
    } else {
      _planos.insert(0, plano);
    }
    _planosLidos[plano.id] = lidos;
    notifyListeners();
    await _gravarPlanos();
    await _gravarPlanosLidos();
  }

  /// Marca um plano como compartilhado depois de ele subir para a nuvem.
  Future<void> marcarCompartilhado(String id) async {
    final i = _planos.indexWhere((p) => p.id == id);
    if (i == -1) return;
    _planos[i] = _planos[i].compartilhadoComo(true);
    notifyListeners();
    await _gravarPlanos();
  }

  Future<void> _gravarPlanos() async {
    await _prefs.setString(
      _kPlanos,
      json.encode([for (final p in _planos) p.paraJson()]),
    );
  }

  Future<void> _gravarPlanosLidos() async {
    await _prefs.setString(
      _kPlanosLidos,
      json.encode({
        for (final MapEntry(key: id, value: dias) in _planosLidos.entries)
          id: dias.toList()..sort(),
      }),
    );
  }

  // --- conversas do chat --------------------------------------------------- //

  // O histórico, a fusão e as lápides vivem em `conversas`
  // (lib/data/conversas.dart). O Estado só repassa com as mesmas assinaturas:
  // as telas e a sincronia com a nuvem continuam falando com ele, e toda
  // mutação notifica os ouvintes do Estado (a nuvem é um deles, e é o que
  // faz a mudança subir sozinha).

  List<Conversa> conversasDe(String persona) => conversas.conversasDe(persona);

  Conversa? conversaDe(String persona, String conversaId) =>
      conversas.conversaDe(persona, conversaId);

  List<Mensagem> mensagensDe(String persona, String conversaId) =>
      conversas.mensagensDe(persona, conversaId);

  Future<Conversa> novaConversa(String persona, {required String titulo}) =>
      conversas.novaConversa(persona, titulo: titulo);

  Future<void> registrarMensagem(
    String persona,
    String conversaId,
    Mensagem mensagem,
  ) => conversas.registrarMensagem(persona, conversaId, mensagem);

  Future<void> marcarRespondidas(String persona, String conversaId) =>
      conversas.marcarRespondidas(persona, conversaId);

  Future<void> limparConversa(String persona, String conversaId) =>
      conversas.limparConversa(persona, conversaId);

  Future<void> limparTodasDe(String persona) =>
      conversas.limparTodasDe(persona);

  /// O que a cópia na nuvem recebe para as conversas. Ver o método homônimo
  /// em `Conversas`.
  String serializarConversas() => conversas.serializarConversas();

  Future<void> fundirConversas(String remota) =>
      conversas.fundirConversas(remota);

  // --- lembretes (horários sincronizados quando logado) --------------------- //

  String serializarLembretes() => json.encode({
    'ativo': _lembretesAtivos,
    'manha': _minutosLembreteManha,
    'promessas': _minutosLembretePromessas,
    'leitura': _minutosLembreteLeitura,
    'noite': _minutosLembreteNoite,
  });

  /// Funde horários remotos vindos da nuvem. Retorna true se algo mudou
  /// e o chamador deve rearmar os alarmes / regravar o token.
  Future<bool> fundirLembretes(String remota) async {
    try {
      final mapa = json.decode(remota) as Map<String, dynamic>;
      final ativo = mapa['ativo'] as bool? ?? _lembretesAtivos;
      final manha = _minutosValidos(mapa['manha'] as int?, minutosPadraoManha);
      final promessas = _minutosValidos(
        mapa['promessas'] as int?,
        minutosPadraoPromessas,
      );
      final leitura = _minutosValidos(
        mapa['leitura'] as int?,
        minutosPadraoLeitura,
      );
      final noite = _minutosValidos(mapa['noite'] as int?, minutosPadraoNoite);
      final mudou =
          ativo != _lembretesAtivos ||
          manha != _minutosLembreteManha ||
          promessas != _minutosLembretePromessas ||
          leitura != _minutosLembreteLeitura ||
          noite != _minutosLembreteNoite;
      if (!mudou) return false;
      _lembretesAtivos = ativo;
      _minutosLembreteManha = manha;
      _minutosLembretePromessas = promessas;
      _minutosLembreteLeitura = leitura;
      _minutosLembreteNoite = noite;
      notifyListeners();
      await _prefs.setBool(_kLembretesAtivos, ativo);
      await _prefs.setInt(_kMinutosLembreteManha, manha);
      await _prefs.setInt(_kMinutosLembretePromessas, promessas);
      await _prefs.setInt(_kMinutosLembreteLeitura, leitura);
      await _prefs.setInt(_kMinutosLembreteNoite, noite);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- planos (sincronizados quando logado, mesmo sem compartilhar) --------- //

  /// O que a cópia na nuvem recebe para os planos. Vai num campo próprio
  /// (`planos`) no documento `usuarios/{uid}`, separado da cópia manual de
  /// favoritos/notas: planos já viviam só no aparelho e por isso um plano
  /// criado no celular nunca aparecia na web — agora sobem sozinhos quando
  /// há conta, sem precisar compartilhar por link.
  String serializarPlanos() => json.encode({
    'planos': [for (final p in _planos) p.paraJson()],
    'planos_lidos': {
      for (final MapEntry(key: id, value: dias) in _planosLidos.entries)
        id: dias.toList()..sort(),
    },
  });

  /// Funde planos remotos com os locais, por id e por dias lidos.
  ///
  /// Funde, não substitui: criar planos em dois aparelhos offline e depois
  /// conectar não perde nenhum. O mesmo vale para os dias marcados: a união
  /// dos dois lados é o que fica. Remoção não sincroniza (mesma limitação da
  /// cópia de favoritos em `importar()`): apagar num aparelho e o plano
  /// continua no outro até ser apagado lá também — o caminho para lápides é
  /// análogo ao do chat, mas ainda não é necessário para o bug de criação.
  Future<void> fundirPlanos(String remota) async {
    try {
      final mapa = json.decode(remota) as Map<String, dynamic>;
      final planosRemotos = mapa['planos'] as List? ?? const [];
      final lidosRemotos =
          mapa['planos_lidos'] as Map<String, dynamic>? ?? const {};

      var mudou = false;
      final idsLocais = {for (final p in _planos) p.id};

      for (final item in planosRemotos) {
        if (item is! Map<String, dynamic>) continue;
        final PlanoDoUsuario plano;
        try {
          plano = PlanoDoUsuario.doJson(item);
        } catch (_) {
          continue;
        }
        if (plano.id.isEmpty) continue;
        if (idsLocais.contains(plano.id)) {
          // Mesmo id já existe: se o remoto marcou como compartilhado e o
          // local ainda não, promove. Título/livros/dias são imutáveis após
          // criação, então não há o que mesclar além do flag.
          final idx = _planos.indexWhere((p) => p.id == plano.id);
          final local = _planos[idx];
          if (!local.compartilhado && plano.compartilhado) {
            _planos[idx] = local.compartilhadoComo(true);
            mudou = true;
          } else if (local.criadoPor == null && plano.criadoPor != null) {
            _planos[idx] = PlanoDoUsuario(
              id: local.id,
              titulo: local.titulo,
              livros: local.livros,
              dias: local.dias,
              criadoEm: local.criadoEm,
              compartilhado: local.compartilhado,
              criadoPor: plano.criadoPor,
              incluirDevocionais: local.incluirDevocionais,
              devocionalAntes: local.devocionalAntes,
            );
            mudou = true;
          }
          continue;
        }
        _planos.add(plano);
        idsLocais.add(plano.id);
        mudou = true;
      }

      if (mudou) {
        // Mantém a ordem "mais novo primeiro", que é a da lista de Meus Planos.
        _planos.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
      }

      for (final entry in lidosRemotos.entries) {
        final id = entry.key;
        final dias = entry.value;
        if (dias is! List) continue;
        final remotos = {
          for (final d in dias)
            if (d is int) d,
        };
        if (remotos.isEmpty) continue;
        final locais = _planosLidos[id];
        if (locais == null) {
          _planosLidos[id] = remotos;
          mudou = true;
        } else {
          final antes = locais.length;
          locais.addAll(remotos);
          if (locais.length != antes) mudou = true;
        }
      }

      if (!mudou) return;
      notifyListeners();
      await _gravarPlanos();
      await _gravarPlanosLidos();
    } catch (erro, pilha) {
      Registro.erro('Estado.fundirPlanos', erro, pilha);
    }
  }

  // --- cópia de segurança --------------------------------------------------- //

  /// Versão do formato da cópia. Existe para que uma cópia velha ainda possa ser
  /// lida se o formato mudar, em vez de ser recusada sem explicação.
  static const versaoDaCopia = 1;

  /// Tudo que o usuário escreveu ou marcou, num JSON legível.
  ///
  /// Só favoritos, notas e dias lidos. O tamanho da fonte fica de fora de
  /// propósito: é preferência do aparelho, e restaurar uma cópia do celular no
  /// computador não deve mudar o tamanho da letra de lá.
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
