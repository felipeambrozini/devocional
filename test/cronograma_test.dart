import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TipoDeDevocional', () {
    test('rota bate com o path das 3 leituras (/manha, /noite, /promessas)', () {
      expect(TipoDeDevocional.manha.rota, 'manha');
      expect(TipoDeDevocional.noite.rota, 'noite');
      expect(TipoDeDevocional.promessa.rota, 'promessas');
    });
  });

  group('ItemDoDia', () {
    test('ItemDeCapitulo guarda a faixa', () {
      const faixa = Faixa(livro: 'genesis', deCapitulo: 1, ateCapitulo: 3);
      const item = ItemDeCapitulo(faixa);
      expect(item.faixa, faixa);
    });

    test('ItemDeDevocional guarda tipo e chave do dia', () {
      const item = ItemDeDevocional(
        tipo: TipoDeDevocional.noite,
        chaveDoDia: '05-01',
      );
      expect(item.tipo, TipoDeDevocional.noite);
      expect(item.chaveDoDia, '05-01');
    });
  });
}
