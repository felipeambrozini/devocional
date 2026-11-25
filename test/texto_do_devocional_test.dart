import 'package:devocional/dados/modelos.dart';
import 'package:devocional/funcoes/citacao.dart';
import 'package:devocional/funcoes/datas.dart';
import 'package:flutter_test/flutter_test.dart';

/// O texto que Copiar e Compartilhar do Devocional levam: leitura, data,
/// título do dia (Promessas), citação e comentário, nessa ordem, e o link no
/// fim. Antes, Copiar levava só o comentário, e Compartilhar trocava a leitura
/// e a data pelo título do cartão (em Promessas, o título do dia).
void main() {
  // No ano corrente, a data sai sem ano ("1 de janeiro").
  final anoAtual = DateTime.now().year;

  const manha = Devocional(
    referencia: 'Josué 5:12',
    versiculo: '...mas comeram do fruto da terra de Canaã naquele ano.',
    texto: 'As fatigantes peregrinações de Israel estavam terminadas.',
  );
  const promessas = Devocional(
    referencia: 'Gênesis 3:15',
    versiculo: 'E porei inimizade entre ti e a mulher.',
    titulo: 'A primeira promessa da Bíblia',
    texto: 'Esta é a primeira promessa ao homem caído.',
  );

  test('Manhã: leitura, data, citação, comentário e link, nessa ordem', () {
    expect(
      textoDoDevocional(
        nomeDaLeitura: 'Devocional da manhã',
        data: DateTime(anoAtual, 1, 1),
        dev: manha,
        link: 'https://exemplo.test/devocional/manha',
      ),
      'Devocional da manhã\n1 de janeiro\n\n'
      '"...mas comeram do fruto da terra de Canaã naquele ano." JOSUÉ 5:12\n\n'
      'As fatigantes peregrinações de Israel estavam terminadas.\n\n'
      'https://exemplo.test/devocional/manha',
    );
  });

  test('Noite: o nome da leitura muda, o resto segue a mesma ordem', () {
    final texto = textoDoDevocional(
      nomeDaLeitura: 'Devocional da noite',
      data: DateTime(anoAtual, 11, 25),
      dev: manha,
    );
    expect(texto, startsWith('Devocional da noite\n25 de novembro\n\n'));
    expect(texto, contains('JOSUÉ 5:12'));
    expect(texto, endsWith(manha.texto));
  });

  test('Promessas: "Promessas de Deus", a data e o título do dia, depois a '
      'citação', () {
    final texto = textoDoDevocional(
      nomeDaLeitura: 'Promessas de Deus',
      data: DateTime(anoAtual, 1, 1),
      dev: promessas,
      link: 'https://exemplo.test/devocional/promessas',
    );
    expect(
      texto,
      startsWith(
        'Promessas de Deus\n1 de janeiro\n\nA primeira promessa da Bíblia\n\n',
      ),
    );
    final partes = [
      'Promessas de Deus',
      '1 de janeiro',
      'A primeira promessa da Bíblia',
      '"E porei inimizade entre ti e a mulher." GÊNESIS 3:15',
      'Esta é a primeira promessa ao homem caído.',
      'https://exemplo.test/devocional/promessas',
    ];
    final posicoes = [for (final parte in partes) texto.indexOf(parte)];
    expect(posicoes, everyElement(isNonNegative));
    expect(posicoes, orderedEquals([...posicoes]..sort()));
  });

  test('dia com mais de um versículo-base: uma linha por versículo', () {
    const encadeado = Devocional(
      referencia: 'Judas 1:1',
      versiculo: 'aos chamados',
      outrosVersiculos: [('1 Coríntios 1:2', 'santificados em Cristo Jesus')],
      texto: 'Comentário.',
    );
    expect(
      textoDoDevocional(
        nomeDaLeitura: 'Devocional da manhã',
        data: DateTime(anoAtual, 7, 12),
        dev: encadeado,
      ),
      'Devocional da manhã\n12 de julho\n\n'
      '"aos chamados" JUDAS 1:1\n'
      '"santificados em Cristo Jesus" 1 CORÍNTIOS 1:2\n\n'
      'Comentário.',
    );
  });

  test('o comentário passado vence o do devocional; sem link, não há link', () {
    final texto = textoDoDevocional(
      nomeDaLeitura: 'Devocional da manhã',
      data: DateTime(anoAtual, 1, 1),
      dev: manha,
      comentario: 'Outro comentário.',
    );
    expect(texto, endsWith('\n\nOutro comentário.'));
    expect(texto, isNot(contains(manha.texto)));
  });

  test('sem versículo nem referência, a citação sai e não deixa buraco', () {
    expect(
      textoDoDevocional(
        nomeDaLeitura: 'Promessas de Deus',
        data: DateTime(anoAtual, 2, 3),
        dev: const Devocional(referencia: '', texto: 'Só o comentário.'),
      ),
      'Promessas de Deus\n3 de fevereiro\n\nSó o comentário.',
    );
  });

  test('fora do ano corrente, a data leva o ano, como na tela', () {
    final data = DateTime(anoAtual - 1, 3, 10);
    expect(
      textoDoDevocional(
        nomeDaLeitura: 'Devocional da noite',
        data: data,
        dev: manha,
      ),
      startsWith('Devocional da noite\n${dataLonga(data)}\n\n'),
    );
    expect(dataLonga(data), endsWith('${anoAtual - 1}'));
  });
}
