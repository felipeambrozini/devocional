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
  static const _kLatitude = 'latitude';
  static const _kLongitude = 'longitude';

  final SharedPreferences _prefs;

  /// Datas 'MM-DD' do cronograma já marcadas como lidas.
  Set<String> _lidos = {};

  /// Favoritos e notas, indexados por [Marcacao.chave].
  Map<String, Marcacao> _marcacoes = {};

  Versao _versao = Versao.bkj;

  /// Onde a leitura parou, para o botão "continuar".
  (String, int)? _ultimaLeitura;

  /// Último lugar conhecido, para calcular nascer e pôr do sol. Fica guardado
  /// porque o devocional precisa dele já na abertura, antes de o GPS responder.
  (double, double)? _lugar;

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

    final lat = _prefs.getDouble(_kLatitude);
    final lon = _prefs.getDouble(_kLongitude);
    if (lat != null && lon != null) _lugar = (lat, lon);

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
  }

  // --- lugar, para o nascer e o pôr do sol --------------------------------- //

  (double, double)? get lugar => _lugar;

  /// Guarda o lugar só quando ele muda o bastante para mexer no horário do sol.
  /// Um décimo de grau é cerca de onze quilômetros, o que desloca o pôr do sol
  /// em menos de um minuto: abaixo disso, gravar e redesenhar não muda nada.
  Future<void> definirLugar(double latitude, double longitude) async {
    final antes = _lugar;
    if (antes != null &&
        (antes.$1 - latitude).abs() < 0.1 &&
        (antes.$2 - longitude).abs() < 0.1) {
      return;
    }
    _lugar = (latitude, longitude);
    notifyListeners();
    await _prefs.setDouble(_kLatitude, latitude);
    await _prefs.setDouble(_kLongitude, longitude);
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

  Marcacao? marcacaoDe(Versao versao, String livro, int capitulo, int versiculo) =>
      _marcacoes['${versao.pasta}/$livro/$capitulo/$versiculo'];

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
}

/// Acesso ao [Estado] pela árvore de widgets, sem pacote de gerenciamento de estado.
/// Seis telas não têm o problema que Riverpod ou bloc resolvem.
class EscopoDoEstado extends InheritedNotifier<Estado> {
  const EscopoDoEstado({super.key, required Estado estado, required super.child})
      : super(notifier: estado);

  static Estado de(BuildContext context) {
    final escopo = context.dependOnInheritedWidgetOfExactType<EscopoDoEstado>();
    assert(escopo?.notifier != null, 'EscopoDoEstado ausente acima deste widget');
    return escopo!.notifier!;
  }
}
