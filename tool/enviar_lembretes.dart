// Roda fora do app, via `dart run tool/enviar_lembretes.dart`, disparado a
// cada 5 min por .github/workflows/lembretes-push.yml. Decide quem venceu o
// horário agora (Firestore, coleção `lembretes` — contrato em
// firestore.rules) e manda o push via FCM, com o versículo do dia
// (Manhã/Noite) ou "título | versículo" (Promessas) — ver
// lib/data/lembretes.dart para o lado do app.
//
// "Venceu", e não "bate exato": o cron do GitHub Actions atrasa de 10 a 30
// min (às vezes mais) e sai da grade de 5 min, então exigir minuto igual
// pulava lembrete quase todo dia. Em vez disso, cada rodada envia para quem
// está dentro da janela de tolerência ([toleranciaDeAtrasoMinutos] depois do
// horário cadastrado) e ainda não recebeu hoje — a data do último envio fica
// gravada no próprio documento (`ultimoEnvioManha`/`ultimoEnvioNoite`,
// escritas só por este script), o que garante um único push por dia mesmo
// com várias rodadas dentro da janela.
//
// Não importa `lib/data/conteudo.dart`: `Conteudo` carrega os assets via
// `rootBundle`, que só existe com o engine do Flutter — um `dart run` puro
// não resolve `package:flutter/services.dart` (que depende de `dart:ui`,
// ausente no SDK Dart standalone). Em vez de criar uma costura só para isto,
// este arquivo lê os mesmos JSONs direto do disco e reaproveita as únicas
// partes de `Conteudo` que valem a pena não duplicar: a análise de
// referência e o nome dos livros, em `lib/data/canon.dart` (Dart puro, sem
// import nenhum) — o resto é a mesma leitura de arquivo com outra API de
// E/S.
//
// Também simplifica [Conteudo._comVersiculosResolvidos]: resolve só a
// primeira passagem da epígrafe (a mesma que o app mostra "em destaque"),
// sem [Devocional.outrosVersiculos] — o push não tem espaço para uma
// citação encadeada inteira mesmo.
import 'dart:convert';
import 'dart:io';

import 'package:felipe_ambrozini/data/canon.dart';
import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as banco_de_fusos;
import 'package:timezone/timezone.dart' as tz;

const _colecao = 'lembretes';

/// Minutos depois do horário cadastrado em que o lembrete ainda conta como
/// "de hoje". O cron atrasa (ver comentário no topo); com 60 min de janela,
/// um run que caia até uma hora depois do horário ainda entrega — e o
/// marcador de último envio garante que não vira spam de rodada em rodada.
const toleranciaDeAtrasoMinutos = 60;

/// Um registro de lembrete, já validado — o contrato é o mesmo que
/// firestore.rules exige para gravar.
class _Lembrete {
  const _Lembrete({
    required this.token,
    required this.minutosManha,
    required this.minutosNoite,
    required this.fuso,
    this.ultimoEnvioManha,
    this.ultimoEnvioNoite,
  });

  final String token;
  final int minutosManha;
  final int minutosNoite;
  final String fuso;

  /// Data ISO (`yyyy-MM-dd`, no fuso do registro) do último push enviado
  /// para cada slot — escrita por [_marcarEnviado]. null = nunca enviou
  /// (ou o app regravou o documento, o `.set()` do app substitui tudo).
  final String? ultimoEnvioManha;
  final String? ultimoEnvioNoite;
}

/// Quantos minutos [agoraMinuto] está depois de [alvoMinuto], considerando a
/// virada da meia-noite (alvo 23:55, agora 00:03 → 8; agora antes do alvo no
/// mesmo dia → volta pelo fim do dia, ex. alvo 06:00, agora 05:50 → 1430).
int atrasoEmMinutos(int agoraMinuto, int alvoMinuto) {
  final diferenca = (agoraMinuto - alvoMinuto) % 1440;
  return diferenca < 0 ? diferenca + 1440 : diferenca;
}

/// Se o push deste slot é devido nesta rodada: está dentro da janela de
/// tolerância depois do horário cadastrado e ainda não foi enviado hoje.
bool deveEnviarLembrete({
  required int agoraMinutoDoDia,
  required int alvoMinutoDoDia,
  required String? ultimoEnvio,
  required String hoje,
}) =>
    ultimoEnvio != hoje &&
    atrasoEmMinutos(agoraMinutoDoDia, alvoMinutoDoDia) <=
        toleranciaDeAtrasoMinutos;

String _dataIso(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';

Future<void> main() async {
  banco_de_fusos.initializeTimeZones();

  final credenciaisJson = Platform.environment['GOOGLE_SERVICE_ACCOUNT'];
  if (credenciaisJson == null || credenciaisJson.isEmpty) {
    stderr.writeln('GOOGLE_SERVICE_ACCOUNT não definido.');
    exitCode = 1;
    return;
  }
  final credenciaisMapa = json.decode(credenciaisJson) as Map<String, dynamic>;
  final projectId = credenciaisMapa['project_id'] as String;

  final cliente = http.Client();
  final credenciaisDeAcesso = await auth.obtainAccessCredentialsViaServiceAccount(
    auth.ServiceAccountCredentials.fromJson(credenciaisMapa),
    const [
      'https://www.googleapis.com/auth/datastore',
      'https://www.googleapis.com/auth/firebase.messaging',
    ],
    cliente,
  );
  final cabecalhos = {
    'Authorization': 'Bearer ${credenciaisDeAcesso.accessToken.data}',
    'Content-Type': 'application/json',
  };

  try {
    final registros = await _listarLembretes(cliente, cabecalhos, projectId);
    stdout.writeln('${registros.length} lembrete(s) cadastrado(s).');

    var enviados = 0;
    var removidos = 0;
    final agora = DateTime.now().toUtc();

    for (final registro in registros) {
      tz.TZDateTime local;
      try {
        local = tz.TZDateTime.from(agora, tz.getLocation(registro.fuso));
      } catch (_) {
        stderr.writeln('Fuso inválido em ${registro.token}: ${registro.fuso}');
        continue;
      }
      final minutoAgora = local.hour * 60 + local.minute;
      final hoje = _dataIso(local);

      // Venceu = está dentro da janela depois do horário cadastrado e ainda
      // não recebeu hoje. O push chega com `minutos` no payload para o app
      // saber se um fallback local já cobriu o atraso (ver
      // lib/data/lembretes.dart).
      final venceuManha = deveEnviarLembrete(
        agoraMinutoDoDia: minutoAgora,
        alvoMinutoDoDia: registro.minutosManha,
        ultimoEnvio: registro.ultimoEnvioManha,
        hoje: hoje,
      );
      final venceuNoite = deveEnviarLembrete(
        agoraMinutoDoDia: minutoAgora,
        alvoMinutoDoDia: registro.minutosNoite,
        ultimoEnvio: registro.ultimoEnvioNoite,
        hoje: hoje,
      );
      if (!venceuManha && !venceuNoite) continue;

      final mensagens = <(String chave, String titulo, String corpo)>[];
      if (venceuManha) {
        final manha = _devocional(local, Periodo.manha);
        if (manha != null) {
          mensagens.add(('manha', 'Devocional da Manhã', manha.versiculo));
        }
        final promessa = _promessa(local);
        if (promessa != null) {
          mensagens.add((
            'promessas',
            'Promessas de Deus',
            '${promessa.titulo} | ${promessa.versiculo}',
          ));
        }
      }
      if (venceuNoite) {
        final noite = _devocional(local, Periodo.noite);
        if (noite != null) {
          mensagens.add(('noite', 'Devocional da Noite', noite.versiculo));
        }
      }

      var okManha = venceuManha;
      var okNoite = venceuNoite;
      var apagado = false;
      for (final (chave, titulo, corpo) in mensagens) {
        final status = await _enviar(
          cliente,
          cabecalhos,
          projectId,
          registro.token,
          chave,
          titulo,
          corpo,
          chave == 'manha'
              ? registro.minutosManha
              : chave == 'noite'
              ? registro.minutosNoite
              : registro.minutosManha,
        );
        if (status == 200) {
          enviados++;
          continue;
        }
        stderr.writeln('Falha ao enviar $chave para ${registro.token}: $status');
        // Falha passageira não marca o slot como enviado — a próxima rodada
        // tenta de novo dentro da janela sem perder o cadastro nem gerar
        // silêncio.
        if (chave == 'noite') {
          okNoite = false;
        } else {
          okManha = false;
        }
        // 404 é o código que o FCM devolve para token cancelado/expirado —
        // só nesse caso apaga o registro.
        if (status == 404) {
          await _apagarLembrete(cliente, cabecalhos, projectId, registro.token);
          removidos++;
          apagado = true;
          break;
        }
      }
      if (apagado) continue;

      final marcadores = <String, String>{
        if (okManha && registro.ultimoEnvioManha != hoje)
          'ultimoEnvioManha': hoje,
        if (okNoite && registro.ultimoEnvioNoite != hoje) 'ultimoEnvioNoite': hoje,
      };
      if (marcadores.isNotEmpty) {
        await _marcarEnviado(
          cliente,
          cabecalhos,
          projectId,
          registro.token,
          marcadores,
        );
      }
    }

    stdout.writeln(
      '$enviados push(es) enviado(s), $removidos token(s) inválido(s) removido(s).',
    );
  } finally {
    cliente.close();
  }
}

Future<List<_Lembrete>> _listarLembretes(
  http.Client cliente,
  Map<String, String> cabecalhos,
  String projectId,
) async {
  final registros = <_Lembrete>[];
  String? proximaPagina;
  do {
    final query = {'pageSize': '300'};
    if (proximaPagina != null) query['pageToken'] = proximaPagina;
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/$_colecao',
      query,
    );
    final resposta = await cliente.get(uri, headers: cabecalhos);
    if (resposta.statusCode != 200) {
      stderr.writeln(
        'Falha ao listar $_colecao: ${resposta.statusCode} ${resposta.body}',
      );
      break;
    }
    final corpo = json.decode(resposta.body) as Map<String, dynamic>;
    for (final doc in (corpo['documents'] as List? ?? const [])) {
      final campos = (doc as Map<String, dynamic>)['fields'] as Map<String, dynamic>;
      String? stringOpcional(String nome) =>
          (campos[nome] as Map<String, dynamic>?)?['stringValue'] as String?;
      try {
        registros.add(
          _Lembrete(
            token: campos['token']['stringValue'] as String,
            minutosManha: int.parse(
              campos['minutosManha']['integerValue'] as String,
            ),
            minutosNoite: int.parse(
              campos['minutosNoite']['integerValue'] as String,
            ),
            fuso: campos['fuso']['stringValue'] as String,
            ultimoEnvioManha: stringOpcional('ultimoEnvioManha'),
            ultimoEnvioNoite: stringOpcional('ultimoEnvioNoite'),
          ),
        );
      } catch (erro) {
        stderr.writeln('Documento fora do contrato em $_colecao: $erro');
      }
    }
    proximaPagina = corpo['nextPageToken'] as String?;
  } while (proximaPagina != null);
  return registros;
}

/// Só o núcleo do FCM v1: título e corpo vão no `data` (e não num payload
/// `notification`), porque a exibição é manual dos dois lados — no Android
/// pelo handler de fundo do app via notificação local (que também cancela o
/// fallback de T+5 min; ver lib/data/lembretes.dart) e na web pelo service
/// worker. Mensagem sem `notification` é data-only: acorda o handler mesmo
/// com o app morto, em vez de virar bolha do sistema que ninguém consegue
/// cancelar. `minutos` é o horário cadastrado do slot — o app usa para saber
/// se um push tardio ainda vale ou se o fallback local já avisou.
///
/// Devolve o código HTTP da resposta do FCM — 200 é sucesso, o resto o
/// chamador decide o que fazer.
Future<int> _enviar(
  http.Client cliente,
  Map<String, String> cabecalhos,
  String projectId,
  String token,
  String chave,
  String titulo,
  String corpo,
  int minutosDoSlot,
) async {
  final uri = Uri.https(
    'fcm.googleapis.com',
    '/v1/projects/$projectId/messages:send',
  );
  final resposta = await cliente.post(
    uri,
    headers: cabecalhos,
    body: json.encode({
      'message': {
        'token': token,
        // HIGH: data-only em prioridade normal pode esperar Doze entregar;
        // lembrete atrasado perde o sentido.
        'android': {'priority': 'HIGH'},
        'data': {
          'chave': chave,
          'titulo': titulo,
          'corpo': corpo,
          'minutos': '$minutosDoSlot',
        },
      },
    }),
  );
  return resposta.statusCode;
}

/// Grava a data do último envio por slot (`updateMask`, só os campos que
/// mudaram). Escrita direta via REST com a conta de serviço: ignora as regras
/// do Firestore (App Check é exigência para clientes, não para admin).
Future<void> _marcarEnviado(
  http.Client cliente,
  Map<String, String> cabecalhos,
  String projectId,
  String token,
  Map<String, String> campos,
) async {
  final uri = Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$projectId/databases/(default)/documents/$_colecao/$token',
    {'updateMask.fieldPaths': campos.keys.toList()},
  );
  final resposta = await cliente.patch(
    uri,
    headers: cabecalhos,
    body: json.encode({
      'fields': {
        for (final entrada in campos.entries)
          entrada.key: {'stringValue': entrada.value},
      },
    }),
  );
  if (resposta.statusCode != 200) {
    stderr.writeln(
      'Falha ao marcar envio de $token: ${resposta.statusCode}',
    );
  }
}

Future<void> _apagarLembrete(
  http.Client cliente,
  Map<String, String> cabecalhos,
  String projectId,
  String token,
) async {
  final uri = Uri.https(
    'firestore.googleapis.com',
    '/v1/projects/$projectId/databases/(default)/documents/$_colecao/$token',
  );
  await cliente.delete(uri, headers: cabecalhos);
}

String _chaveDoDia(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}-'
    '${data.month.toString().padLeft(2, '0')}';

Map<String, dynamic>? _devocionaisCache;
Map<String, dynamic> _carregarDevocionais() => _devocionaisCache ??=
    json.decode(File('assets/devotionals/manha_e_noite.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic>? _promessasCache;
bool _tentouPromessas = false;
Map<String, dynamic>? _carregarPromessas() {
  if (!_tentouPromessas) {
    _tentouPromessas = true;
    try {
      _promessasCache = json.decode(
        File('assets/devotionals/promessas_de_deus.json').readAsStringSync(),
      ) as Map<String, dynamic>;
    } catch (_) {
      _promessasCache = null;
    }
  }
  return _promessasCache;
}

Devocional? _devocional(DateTime data, Periodo periodo) {
  final dia =
      _carregarDevocionais()[_chaveDoDia(data)] as Map<String, dynamic>?;
  final entrada = dia?[periodo.chave] as Map<String, dynamic>?;
  if (entrada == null) return null;
  return _comVersiculoResolvido(Devocional.doJson(entrada));
}

Devocional? _promessa(DateTime data) {
  final dados = _carregarPromessas();
  final dia = dados?[_chaveDoDia(data)] as Map<String, dynamic>?;
  if (dia == null) return null;
  return _comVersiculoResolvido(Devocional.doJson(dia));
}

final _livrosCache = <String, Map<String, dynamic>?>{};

Map<String, dynamic>? _carregarLivro(String slug) {
  if (_livrosCache.containsKey(slug)) return _livrosCache[slug];
  Map<String, dynamic>? dados;
  try {
    dados = json.decode(File('assets/biblia/$slug.json').readAsStringSync())
        as Map<String, dynamic>;
  } catch (_) {
    dados = null;
  }
  _livrosCache[slug] = dados;
  return dados;
}

String _versiculoOuFaixa(String slug, int capitulo, int deVersiculo, int ateVersiculo) {
  final livro = _carregarLivro(slug);
  if (livro == null) return '';
  final capitulos = livro['capitulos'] as Map<String, dynamic>;
  final cap = capitulos['$capitulo'] as Map<String, dynamic>?;
  if (cap == null) return '';
  final versiculos = cap['versiculos'] as Map<String, dynamic>;
  final textos = <String>[
    for (var n = deVersiculo; n <= ateVersiculo; n++)
      if (versiculos['$n'] is String) versiculos['$n'] as String,
  ];
  return textos.join(' ');
}

/// Só a primeira passagem da referência — ver o comentário no topo do
/// arquivo sobre por que [Devocional.outrosVersiculos] não se aplica aqui.
Devocional _comVersiculoResolvido(Devocional dev) {
  final resolvidos = faixasDaReferencia(dev.referencia);
  if (resolvidos.isEmpty) return dev;
  final (livro, capitulo, deVersiculo, ateVersiculo) = resolvidos.first;
  final texto = _versiculoOuFaixa(livro.slug, capitulo, deVersiculo, ateVersiculo);
  if (texto.isEmpty) return dev;
  return Devocional(
    referencia: dev.referencia,
    texto: dev.texto,
    titulo: dev.titulo,
    versiculo: texto,
  );
}
