import 'package:devocional/funcoes/link_do_site.dart';
import 'package:flutter_test/flutter_test.dart';

String? rota(String link) => rotaDoLinkDoSite(Uri.parse(link));

void main() {
  group('rotaDoLinkDoSite', () {
    test('tira o prefixo do site e mantém a data do devocional', () {
      expect(
        rota('/tabernaculo/devocional/manha?data=2026-11-26'),
        '/devocional/manha?data=2026-11-26',
      );
    });

    test('a raiz do site, com ou sem barra, vira a raiz do app', () {
      expect(rota('/tabernaculo'), '/');
      expect(rota('/tabernaculo/'), '/');
    });

    test('?ler abre o versículo, com ou sem o prefixo', () {
      expect(rota('/?ler=joao.3.16'), '/ler/joao/3?versiculos=16');
      expect(rota('/tabernaculo/?ler=joao.3.16'), '/ler/joao/3?versiculos=16');
    });

    test('?ler sem versículo abre o capítulo', () {
      expect(rota('/?ler=joao.3'), '/ler/joao/3');
    });

    test('?ler inválido só some, para cair na Hoje', () {
      expect(rota('/?ler=inexistente.1.1'), '/');
      expect(rota('/?ler=joao.99'), '/');
    });

    test('?plano abre o plano pelo id, sem o slug legível', () {
      expect(rota('/?plano=genesis-em-30-dias-abc123'), '/plano/abc123');
      expect(rota('/tabernaculo/?plano=abc123'), '/plano/abc123');
    });

    test('?plano com id que não é de plano só some, para cair na Hoje', () {
      expect(rota('/?plano=..%2Fperfil'), '/');
      expect(rota('/?plano=a%2Fb'), '/');
      expect(rota('/?plano=x%3Fler%3Djoao.3'), '/');
      expect(rota('/?plano='), '/');
    });

    test('a URL inteira, como o Android a entrega, também é traduzida', () {
      expect(
        rota(
          'https://www.felipeambrozini.com.br/tabernaculo/devocional/manha'
          '?data=2026-11-26',
        ),
        '/devocional/manha?data=2026-11-26',
      );
    });

    test('?plano vence ?ler quando os dois vêm juntos', () {
      expect(rota('/?plano=abc123&ler=joao.3.16'), '/plano/abc123');
    });

    test('rota interna do app não muda', () {
      expect(rota('/devocional/manha'), isNull);
      expect(rota('/hoje'), isNull);
      expect(rota('/ler/joao/3?versiculos=16'), isNull);
      expect(rota('/'), isNull);
    });

    test('caminho que só começa com o mesmo nome não é o prefixo', () {
      expect(rota('/tabernaculos'), isNull);
    });
  });
}
