import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/data/voz.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('textoDeCapitulo', () {
    test('começa pela referência e lê cada versículo sem o número', () {
      const capitulo = Capitulo(
        livro: 'joao',
        numero: 3,
        titulo: '',
        nome: 'João',
        versiculos: [
          (1, 'Havia entre os fariseus um homem chamado Nicodemos.'),
          (16, 'Porque Deus amou o mundo de tal maneira.'),
        ],
      );
      expect(
        textoDeCapitulo(capitulo),
        'João 3 Havia entre os fariseus um homem chamado Nicodemos. '
        'Porque Deus amou o mundo de tal maneira.',
      );
    });

    test('lê o sobrescrito quando o capítulo tem um (os Salmos)', () {
      const salmo = Capitulo(
        livro: 'salmos',
        numero: 23,
        titulo: 'Salmo de Davi.',
        nome: 'Salmos',
        versiculos: [(1, 'O Senhor é o meu pastor.')],
      );
      expect(
        textoDeCapitulo(salmo),
        'Salmos 23 Salmo de Davi. O Senhor é o meu pastor.',
      );
    });
  });

  group('textoDeIntroducao', () {
    test('lê o título, as seções em ordem e a frase com a atribuição', () {
      const introducao = Introducao(
        livro: 'João',
        secoes: [('Estrutura', 'Primeiro parágrafo.\n\nSegundo parágrafo.')],
        frase: 'Grandes coisas!',
        fraseComprovada: true,
        fonteDaFrase: 'O Tesouro de Davi',
      );
      expect(
        textoDeIntroducao(introducao),
        'Introdução de João. Estrutura Primeiro parágrafo. Segundo '
        'parágrafo. "Grandes coisas!" Charles H. Spurgeon, O Tesouro de Davi',
      );
    });

    test('sem frase comprovada lê a introdução sem a citação', () {
      const semFrase = Introducao(
        livro: 'João',
        secoes: [('Estrutura', 'Um parágrafo.')],
        frase: '',
        fraseComprovada: false,
        fonteDaFrase: '',
      );
      expect(
        textoDeIntroducao(semFrase),
        'Introdução de João. Estrutura Um parágrafo.',
      );
    });
  });

  group('textoDeDevocional', () {
    test('lê o cabeçalho, o versículo-base com a referência e o comentário',
        () {
      const dev = Devocional(
        referencia: 'João 6:37',
        versiculo: 'Tudo o que o Pai me dá virá a mim.',
        texto: 'Que palavra doce é esta.',
        titulo: '',
      );
      expect(
        textoDeDevocional(
          dev,
          cabecalho: 'Devocional da manhã, 18 de agosto',
        ),
        'Devocional da manhã, 18 de agosto "Tudo o que o Pai me dá virá a '
        'mim." João 6:37 Que palavra doce é esta.',
      );
    });

    test('lê o título e os versículos adicionais do dia raro', () {
      const dev = Devocional(
        referencia: 'Judas 1:1',
        versiculo: 'Judas, servo de Jesus Cristo.',
        titulo: 'Uma promessa para hoje',
        outrosVersiculos: [
          ('1 Coríntios 1:2', 'À igreja de Deus.'),
        ],
        texto: 'O comentário.',
      );
      expect(
        textoDeDevocional(dev, cabecalho: 'Promessa para 18 de agosto'),
        'Promessa para 18 de agosto Uma promessa para hoje "Judas, servo de '
        'Jesus Cristo." Judas 1:1 "À igreja de Deus." 1 Coríntios 1:2 O '
        'comentário.',
      );
    });

    test('sem versículo falado (Manhã e Noite) só anuncia a referência', () {
      const dev = Devocional(
        referencia: 'João 6:37',
        versiculo: '',
        texto: 'O versículo vem embutido no próprio comentário.',
        titulo: '',
      );
      expect(
        textoDeDevocional(dev, cabecalho: 'Devocional da noite, 18 de agosto'),
        'Devocional da noite, 18 de agosto João 6:37 O versículo vem embutido '
        'no próprio comentário.',
      );
    });
  });

  group('chaves de áudio', () {
    test('chaveDeCapitulo e chaveDaIntroducao geram formato esperado', () {
      expect(chaveDeCapitulo('joao', 3), 'capitulo:joao.3');
      expect(chaveDaIntroducao('genesis'), 'introducao:genesis');
    });
  });
}
