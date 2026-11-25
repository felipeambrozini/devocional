import 'dart:convert';

import 'package:devocional/dados/monitoramento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('o relatório de erro é JSON com o contrato do servidor', () {
    final texto = jsonEncode(
      Monitoramento.jsonDoRelatorio(
        contexto: 'Chat.enviar',
        mensagem: 'falhou',
        pilha: '#0 main',
        url: '/tabernaculo/hoje',
        versao: '1.22.0+47',
        plataforma: 'web-android',
      ),
    );
    final json = jsonDecode(texto) as Map<String, dynamic>;

    expect(json['origem'], 'dart');
    expect(json['contexto'], 'Chat.enviar');
    expect(json['mensagem'], 'falhou');
    expect(json['pilha'], '#0 main');
    expect(json['arquivo'], '');
    expect(json['linha'], 0);
    expect(json['url'], '/tabernaculo/hoje');
    expect(json['versao'], '1.22.0+47');
    expect(json['plataforma'], 'web-android');
  });
}
