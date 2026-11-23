import 'dart:io';

import 'package:devocional/dados/audio_offline.dart';
import 'package:devocional/dados/canon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Aponta `getApplicationDocumentsPath` para um diretório temporário só
/// desta suíte — sem isto, `AudioOffline` bateria no path_provider de
/// verdade (sem plugin registrado em teste, ele lançaria).
class _PathProviderFalso extends PathProviderPlatform {
  _PathProviderFalso(this.caminho);

  final String caminho;

  @override
  Future<String?> getApplicationDocumentsPath() async => caminho;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('audio_offline_test');
    PathProviderPlatform.instance = _PathProviderFalso(tmp.path);
    // audioBaseUrl é const (String.fromEnvironment): só dá para trocar em
    // runtime por este override, mesmo problema que Voz.baseUrlForTest
    // resolve do lado da leitura em voz.
    AudioOffline.baseUrlParaTeste = 'https://audio.test';
    // AudioOffline é um singleton: sem isto, a contagem em memória de um
    // teste vazaria para o próximo, que aponta para outro diretório
    // temporário vazio.
    await AudioOffline.instancia.atualizarContagens();
  });

  tearDown(() async {
    AudioOffline.baseUrlParaTeste = null;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('baixarCategoria', () {
    test('cancelar() interrompe o lote e preserva o que já baixou', () async {
      final off = AudioOffline.instancia;
      var pedidos = 0;
      final cliente = MockClient((requisicao) async {
        pedidos++;
        // Cancela assim que o primeiro arquivo já tiver sido escrito, para
        // provar que o loop para antes do fim do lote (introducao tem 66
        // chaves — bem mais que os 2-3 que devem ser pedidos aqui).
        if (pedidos == 2) off.cancelar();
        return http.Response.bytes(List.filled(10, 0), 200);
      });

      await off.baixarCategoria('introducao', cliente: cliente);

      expect(
        pedidos,
        lessThan(66),
        reason: 'cancelar() deveria ter parado o loop bem antes do fim',
      );
      expect(off.baixando, isFalse);
      await off.atualizarContagens();
      expect(
        off.contagemPorCategoria['introducao'],
        greaterThan(0),
        reason: 'o que já baixou antes do cancelamento continua no disco',
      );
    });

    test('soma incremental bate com o disco no fim do lote', () async {
      final off = AudioOffline.instancia;
      final cliente = MockClient(
        (requisicao) async => http.Response.bytes(List.filled(100, 0), 200),
      );

      // A menor categoria (66 chaves): o que importa aqui é o lote
      // terminar sem cancelamento, não o tamanho dele.
      await off.baixarCategoria('introducao', cliente: cliente);

      final baixadosDoLoteInteiro = off.contagemPorCategoria['introducao'];
      final bytesDoLoteInteiro = off.tamanhoTotalBytes;

      await off.atualizarContagens();

      expect(off.contagemPorCategoria['introducao'], baixadosDoLoteInteiro);
      expect(off.tamanhoTotalBytes, bytesDoLoteInteiro);
    });
  });

  group('livros', () {
    http.Client clienteDe200(List<Uri> pedidos, {int bytes = 10}) =>
        MockClient((requisicao) async {
          pedidos.add(requisicao.url);
          return http.Response.bytes(List.filled(bytes, 0), 200);
        });

    Future<void> gravar(String relativo) async {
      final f = File('${tmp.path}/audio_offline/$relativo');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(const [1, 2, 3]);
    }

    Future<bool> existe(String relativo) =>
        File('${tmp.path}/audio_offline/$relativo').exists();

    final judas = canon.firstWhere((l) => l.slug == 'judas');
    final tresJoao = canon.firstWhere((l) => l.slug == '3joao');

    test('as pastas e as chaves de um livro seguem o formato da voz', () {
      expect(pastaDoLivroDaBiblia('joao'), 'biblia/joao');
      expect(pastaDoLivroDaBiblioteca('slug_x'), 'livros/slug_x');
      expect(chavesDoLivroDaBiblioteca('x', 0), isEmpty);
      expect(chavesDoLivroDaBiblioteca('x', 3), [
        'livro:x.1',
        'livro:x.2',
        'livro:x.3',
      ]);
      expect(chavesDoLivroDaBiblia(judas), ['capitulo:judas.1']);
      final joao = canon.firstWhere((l) => l.slug == 'joao');
      expect(chavesDoLivroDaBiblia(joao), hasLength(joao.capitulos));
    });

    test('baixar um livro da Biblioteca grava em livros/<slug>/<n>.mp3 e '
        'conta só por livro', () async {
      final off = AudioOffline.instancia;
      final pedidos = <Uri>[];
      final pasta = pastaDoLivroDaBiblioteca('livro_x');

      await off.baixarLivro(
        pasta,
        chavesDoLivroDaBiblioteca('livro_x', 3),
        cliente: clienteDe200(pedidos),
      );

      expect(pedidos.map((u) => u.toString()), [
        'https://audio.test/livros/livro_x/1.mp3',
        'https://audio.test/livros/livro_x/2.mp3',
        'https://audio.test/livros/livro_x/3.mp3',
      ]);
      for (final n in [1, 2, 3]) {
        expect(await existe('livros/livro_x/$n.mp3'), isTrue);
      }
      expect(off.contagemDoLivro(pasta), 3);
      expect(off.contagemPorCategoria.values, everyElement(0));
      expect(off.tamanhoTotalBytes, 30);
      expect(off.baixando, isFalse);
      expect(off.loteAtivo, isNull);
      expect(off.erro, isNull);
      expect(off.loteDoErro, isNull);
    });

    test('baixar um livro da Bíblia soma em "biblia" e no livro', () async {
      final off = AudioOffline.instancia;
      final pasta = pastaDoLivroDaBiblia(judas.slug);

      await off.baixarLivro(
        pasta,
        chavesDoLivroDaBiblia(judas),
        cliente: clienteDe200([]),
      );

      expect(await existe('biblia/judas/1.mp3'), isTrue);
      expect(off.contagemPorCategoria['biblia'], 1);
      expect(off.contagemPorCategoria['introducao'], 0);
      expect(off.contagemDoLivro(pasta), 1);
    });

    test(
      'durante o lote, loteAtivo é a pasta e categoriaAtiva é nula',
      () async {
        final off = AudioOffline.instancia;
        String? lote = 'nada';
        String? categoria = 'nada';
        final cliente = MockClient((requisicao) async {
          lote = off.loteAtivo;
          categoria = off.categoriaAtiva;
          return http.Response.bytes(const [0], 200);
        });

        await off.baixarLivro(
          'livros/livro_x',
          chavesDoLivroDaBiblioteca('livro_x', 1),
          cliente: cliente,
        );

        expect(lote, 'livros/livro_x');
        expect(categoria, isNull);
      },
    );

    test('lista vazia de chaves termina sem pedido nem erro', () async {
      final off = AudioOffline.instancia;
      final pedidos = <Uri>[];
      await off.baixarLivro(
        'livros/vazio',
        const [],
        cliente: clienteDe200(pedidos),
      );
      expect(pedidos, isEmpty);
      expect(off.baixando, isFalse);
      expect(off.erro, isNull);
    });

    test('para no primeiro 403 com um pedido só e o erro do livro', () async {
      final off = AudioOffline.instancia;
      var pedidos = 0;
      final cliente = MockClient((requisicao) async {
        pedidos++;
        return http.Response('', 403);
      });
      const pasta = 'livros/livro_x';

      await off.baixarLivro(
        pasta,
        chavesDoLivroDaBiblioteca('livro_x', 5),
        cliente: cliente,
      );

      expect(pedidos, 1);
      expect(off.erro, 'Áudio deste livro ainda não publicado');
      expect(off.loteDoErro, pasta);
      expect(off.baixando, isFalse);
      expect(await existe('livros/livro_x/1.mp3'), isFalse);
    });

    for (final status in [404, 410]) {
      test('$status também para o lote do livro no primeiro pedido', () async {
        final off = AudioOffline.instancia;
        var pedidos = 0;
        final cliente = MockClient((requisicao) async {
          pedidos++;
          return http.Response('', status);
        });
        await off.baixarLivro(
          'livros/livro_x',
          chavesDoLivroDaBiblioteca('livro_x', 5),
          cliente: cliente,
        );
        expect(pedidos, 1);
        expect(off.erro, 'Áudio deste livro ainda não publicado');
      });
    }

    test('403 no meio do livro preserva o que já baixou', () async {
      final off = AudioOffline.instancia;
      var pedidos = 0;
      final cliente = MockClient((requisicao) async {
        pedidos++;
        return pedidos == 1
            ? http.Response.bytes(const [0], 200)
            : http.Response('', 403);
      });
      await off.baixarLivro(
        'livros/livro_x',
        chavesDoLivroDaBiblioteca('livro_x', 5),
        cliente: cliente,
      );
      expect(pedidos, 2);
      expect(off.contagemDoLivro('livros/livro_x'), 1);
      expect(off.loteDoErro, 'livros/livro_x');
    });

    test(
      'um erro que não é de ausência segue para o próximo capítulo',
      () async {
        final off = AudioOffline.instancia;
        var pedidos = 0;
        final cliente = MockClient((requisicao) async {
          pedidos++;
          return http.Response('', 500);
        });
        await off.baixarLivro(
          'livros/livro_x',
          chavesDoLivroDaBiblioteca('livro_x', 3),
          cliente: cliente,
        );
        expect(pedidos, 3);
        expect(off.erro, contains('500'));
        expect(off.loteDoErro, 'livros/livro_x');
      },
    );

    test('o que já está no disco não é baixado de novo', () async {
      final off = AudioOffline.instancia;
      await gravar('livros/livro_x/1.mp3');
      final pedidos = <Uri>[];
      await off.baixarLivro(
        'livros/livro_x',
        chavesDoLivroDaBiblioteca('livro_x', 2),
        cliente: clienteDe200(pedidos),
      );
      expect(pedidos.map((u) => u.path), ['/livros/livro_x/2.mp3']);
    });

    test('apagarLivro apaga só a pasta do livro e reconta', () async {
      final off = AudioOffline.instancia;
      await off.baixarLivro(
        'livros/livro_x',
        chavesDoLivroDaBiblioteca('livro_x', 2),
        cliente: clienteDe200([]),
      );
      await off.baixarLivro(
        'livros/livro_y',
        chavesDoLivroDaBiblioteca('livro_y', 2),
        cliente: clienteDe200([]),
      );
      await off.baixarLivro(
        pastaDoLivroDaBiblia(judas.slug),
        chavesDoLivroDaBiblia(judas),
        cliente: clienteDe200([]),
      );

      await off.apagarLivro('livros/livro_x');

      expect(await existe('livros/livro_x/1.mp3'), isFalse);
      expect(await existe('livros/livro_y/1.mp3'), isTrue);
      expect(await existe('biblia/judas/1.mp3'), isTrue);
      expect(off.contagemDoLivro('livros/livro_x'), isNull);
      expect(off.contagemDoLivro('livros/livro_y'), 2);
      expect(off.contagemPorCategoria['biblia'], 1);
    });

    test('apagar um livro da Bíblia desconta de "biblia"', () async {
      final off = AudioOffline.instancia;
      await off.baixarLivro(
        pastaDoLivroDaBiblia(judas.slug),
        chavesDoLivroDaBiblia(judas),
        cliente: clienteDe200([]),
      );
      await off.baixarLivro(
        pastaDoLivroDaBiblia(tresJoao.slug),
        chavesDoLivroDaBiblia(tresJoao),
        cliente: clienteDe200([]),
      );
      expect(off.contagemPorCategoria['biblia'], 2);

      await off.apagarLivro(pastaDoLivroDaBiblia(judas.slug));

      expect(off.contagemPorCategoria['biblia'], 1);
      expect(await existe('biblia/3joao/1.mp3'), isTrue);
    });

    test('apagarLivro ignora pasta que não é de livro', () async {
      final off = AudioOffline.instancia;
      await gravar('biblia/joao/1.mp3');
      await gravar('introducoes/joao.mp3');
      await gravar('livros/livro_x/1.mp3');
      await gravar('devocionais/manha_e_noite/manha/1-1.mp3');

      for (final pasta in [
        'biblia',
        'introducoes',
        'livros',
        'devocionais',
        'biblia/joao/extra',
        '',
        '../audio_offline',
      ]) {
        await off.apagarLivro(pasta);
      }

      expect(await existe('biblia/joao/1.mp3'), isTrue);
      expect(await existe('introducoes/joao.mp3'), isTrue);
      expect(await existe('livros/livro_x/1.mp3'), isTrue);
      expect(await existe('devocionais/manha_e_noite/manha/1-1.mp3'), isTrue);
    });

    test('apagarLivro de pasta inexistente não lança', () async {
      final off = AudioOffline.instancia;
      await off.apagarLivro('livros/nao_existe');
      expect(off.contagemDoLivro('livros/nao_existe'), isNull);
    });

    test('atualizarContagens preenche a contagem por livro', () async {
      final off = AudioOffline.instancia;
      await gravar('biblia/joao/1.mp3');
      await gravar('biblia/joao/2.mp3');
      await gravar('livros/livro_x/1.mp3');
      await gravar('introducoes/joao.mp3');

      await off.atualizarContagens();

      expect(off.contagemDoLivro('biblia/joao'), 2);
      expect(off.contagemDoLivro('livros/livro_x'), 1);
      expect(off.contagemDoLivro('introducoes'), isNull);
      expect(off.contagemPorCategoria['biblia'], 2);
      expect(off.contagemPorCategoria['introducao'], 1);
    });

    test('atualizarContagens sem nada no disco zera o que havia', () async {
      final off = AudioOffline.instancia;
      await gravar('livros/livro_x/1.mp3');
      await off.atualizarContagens();
      expect(off.contagemDoLivro('livros/livro_x'), 1);
      await Directory('${tmp.path}/audio_offline').delete(recursive: true);
      await off.atualizarContagens();
      expect(off.contagemDoLivro('livros/livro_x'), isNull);
    });

    test('contarLivro conta só os arquivos da pasta; vazia dá 0', () async {
      final off = AudioOffline.instancia;
      await gravar('livros/livro_x/1.mp3');
      await gravar('livros/livro_x/2.mp3');
      await gravar('livros/livro_y/1.mp3');

      await off.contarLivro('livros/livro_x');
      await off.contarLivro('livros/livro_z');

      expect(off.contagemDoLivro('livros/livro_x'), 2);
      expect(off.contagemDoLivro('livros/livro_z'), 0);
    });
  });
}
