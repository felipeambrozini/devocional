import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../dados/registro.dart';

/// Cartão-imagem para compartilhar: o versículo em pergaminho escuro com o
/// filete de metal, na identidade da Estante (couro `#2E1B10`, bege de
/// leitura, ouro claro). A imagem viaja junto do texto de sempre, que continua
/// sendo o que o link e a cópia usam — a imagem é o que rende no WhatsApp e
/// no Instagram, onde texto puro morre sem rosto.
///
/// Sem dependência nova: `share_plus` (arquivos) e `path_provider` (temp)
/// já são do app. Na web cai para texto puro, que é o que o share da web
/// suporta de verdade.

const _largura = 1080.0;
const _margem = 96.0;
const _fundo = ui.Color(0xFF2E1B10);
const _corTexto = ui.Color(0xFFEDE0C8);
const _destaque = ui.Color(0xFFE3C567);
const _apoio = ui.Color(0xFFC9B99A);

TextPainter _pintor(
  String texto, {
  required double tamanho,
  required ui.Color cor,
  bool italico = false,
  bool negrito = false,
  double altura = 1.5,
  double espacamento = 0,
}) {
  final pintor = TextPainter(
    text: TextSpan(
      text: texto,
      style: TextStyle(
        color: cor,
        fontSize: tamanho,
        height: altura,
        fontStyle: italico ? FontStyle.italic : FontStyle.normal,
        fontWeight: negrito ? FontWeight.w700 : FontWeight.w400,
        letterSpacing: espacamento,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: _largura - _margem * 2);
  return pintor;
}

/// Gera o PNG do cartão. `texto` é o versículo (com aspas), `referencia` é
/// quem assina (ex.: "João 3:16" ou o título da leitura) e `rodape` é o link
/// que reabre a leitura. Puro em disco: não toca em rede nem em plugin, então
/// dá para testar sem mock.
Future<Uint8List> gerarImagemDoCartao({
  required String texto,
  required String referencia,
  String? rodape,
}) async {
  final marca = _pintor(
    'DEVOCIONAL',
    tamanho: 34,
    cor: _apoio,
    espacamento: 8,
  );
  final corpo = _pintor(
    texto,
    tamanho: 54,
    cor: _corTexto,
    italico: true,
  );
  final assinatura = _pintor(
    referencia,
    tamanho: 46,
    cor: _destaque,
    negrito: true,
  );
  final pe = (rodape == null || rodape.isEmpty)
      ? null
      : _pintor(rodape, tamanho: 34, cor: _apoio, altura: 1.4);

  const espaco = 40.0;
  const fileteAltura = 8.0;
  const fileteLargura = 192.0;
  var altura =
      _margem * 2 + marca.height + espaco + fileteAltura + espaco * 1.5;
  altura += corpo.height + espaco + assinatura.height;
  if (pe != null) altura += espaco + pe.height;

  final gravador = ui.PictureRecorder();
  final tela = Canvas(gravador);
  tela.drawRect(
    Rect.fromLTWH(0, 0, _largura, altura),
    Paint()..color = _fundo,
  );
  var y = _margem;
  marca.paint(tela, Offset(_margem, y));
  y += marca.height + espaco;
  tela.drawRect(
    Rect.fromLTWH(_margem, y, fileteLargura, fileteAltura),
    Paint()..color = _destaque,
  );
  y += fileteAltura + espaco * 1.5;
  corpo.paint(tela, Offset(_margem, y));
  y += corpo.height + espaco;
  assinatura.paint(tela, Offset(_margem, y));
  y += assinatura.height;
  if (pe != null) {
    y += espaco;
    pe.paint(tela, Offset(_margem, y));
  }
  final imagem = await gravador.endRecording().toImage(
    _largura.toInt(),
    altura.ceil(),
  );
  final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
  imagem.dispose();
  if (dados == null) throw StateError('cartao_imagem: PNG vazio');
  return dados.buffer.asUint8List();
}

/// Compartilha o cartão-imagem com o texto de sempre junto. Se a imagem
/// falhar por qualquer motivo, cai para o texto puro — nunca deixa o gesto
/// sem resposta.
Future<void> compartilharCartao({
  required String texto,
  required String referencia,
  String? link,
  String? textoParaAcompanhar,
}) async {
  final acompanhamento =
      textoParaAcompanhar ?? '$texto\n$referencia${link == null ? '' : '\n$link'}';
  if (kIsWeb) {
    await SharePlus.instance.share(ShareParams(text: acompanhamento));
    return;
  }
  try {
    final bytes = await gerarImagemDoCartao(
      texto: texto,
      referencia: referencia,
      rodape: link,
    );
    final dir = await getTemporaryDirectory();
    final arquivo = File(
      '${dir.path}/devocional-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await arquivo.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(arquivo.path)], text: acompanhamento),
    );
  } catch (erro, pilha) {
    Registro.erro('compartilharCartao.imagem', erro, pilha);
    await SharePlus.instance.share(ShareParams(text: acompanhamento));
  }
}
