import 'package:felipe_ambrozini/estilo/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Prova que o eixo `wght` das fontes variáveis está de fato sendo aplicado.
///
/// Cinzel e Montserrat são variáveis. O campo `weight` do pubspec **não** move o
/// eixo: ele só rotula o arquivo, e sem `fontVariations` o motor desenha a
/// instância padrão, que é Regular no Cinzel e Thin no Montserrat. O app inteiro
/// saía no peso errado e nada acusava, porque `fontWeight` continuava lá no
/// código e a análise estática não vê a diferença.
///
/// A medição é a prova: numa fonte variável de verdade, o mesmo texto ocupa
/// larguras diferentes em pesos diferentes. Se as larguras baterem, o eixo está
/// sendo ignorado e é o defeito voltando.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Carrega o arquivo real do bundle. Sem isto o teste usaria a fonte de
  /// medida do ambiente de teste e mediria qualquer coisa menos as nossas.
  Future<void> carregar(String familia, String caminho) async {
    final carregador = FontLoader(familia)..addFont(rootBundle.load(caminho));
    await carregador.load();
  }

  setUpAll(() async {
    await carregar('Cinzel', 'assets/fonts/Cinzel-Variable.ttf');
    await carregar('Montserrat', 'assets/fonts/Montserrat-Variable.ttf');
  });

  double largura(String familia, {required double peso, String? variacao}) {
    final pintor = TextPainter(
      text: TextSpan(
        text: 'No princípio criou Deus o céu e a terra',
        style: TextStyle(
          fontFamily: familia,
          fontSize: 40,
          fontWeight: FontWeight.values.firstWhere((w) => w.value == peso),
          fontVariations: variacao == null
              ? null
              : [FontVariation('wght', peso)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return pintor.width;
  }

  test('Montserrat responde ao eixo wght', () {
    final fina = largura('Montserrat', peso: 100, variacao: 'sim');
    final normal = largura('Montserrat', peso: 400, variacao: 'sim');
    final grossa = largura('Montserrat', peso: 700, variacao: 'sim');

    expect(
      normal,
      greaterThan(fina),
      reason: 'Thin e Regular não podem medir igual numa fonte variável',
    );
    expect(
      grossa,
      greaterThan(normal),
      reason: 'Regular e Bold não podem medir igual numa fonte variável',
    );
  });

  test('Cinzel responde ao eixo wght', () {
    final normal = largura('Cinzel', peso: 400, variacao: 'sim');
    final grossa = largura('Cinzel', peso: 700, variacao: 'sim');
    expect(grossa, greaterThan(normal));
  });

  test('os estilos do tema saem em pesos distintos de verdade', () {
    // Ponta a ponta, sobre o tema que o app usa, e não sobre estilos montados
    // aqui: se alguém tirar o fontVariations de theme.dart, corpo e destaque
    // passam a medir igual e este teste cai.
    final tema = construirTema().textTheme;

    double medir(TextStyle? estilo) => (TextPainter(
      text: TextSpan(text: 'Deus é amor', style: estilo),
      textDirection: TextDirection.ltr,
    )..layout()).width;

    // titleMedium é o corpo em w600; igualando o tamanho ao dele, o que sobra de
    // diferença entre os dois é só o peso.
    final destaque = tema.titleMedium!;
    final corpoNoMesmoTamanho = tema.bodyMedium!.copyWith(
      fontSize: destaque.fontSize,
    );
    expect(
      medir(destaque),
      isNot(medir(corpoNoMesmoTamanho)),
      reason:
          'mesma família e mesmo tamanho, pesos diferentes: se medirem '
          'igual, o eixo wght parou de ser aplicado',
    );
  });
}
