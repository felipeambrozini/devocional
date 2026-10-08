import 'package:felipe_ambrozini/funcoes/cartao_imagem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gera PNG válido para um versículo curto', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await gerarImagemDoCartao(
      texto: '"Porque Deus amou o mundo de tal maneira."',
      referencia: 'João 3:16',
      rodape: 'https://www.felipeambrozini.com.br/devocional/?ler=joao.3.16',
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
    // Assinatura do PNG: 137 80 78 71 13 10 26 10.
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('texto longo também gera PNG válido, sem estourar', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final longo = List.filled(20, 'Palavra que permanece. ').join();
    final bytes = await gerarImagemDoCartao(
      texto: '"$longo"',
      referencia: 'Salmos 119:160',
    );
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
