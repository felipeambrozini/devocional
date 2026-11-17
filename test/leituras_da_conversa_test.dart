import 'package:devocional/dados/biblioteca.dart';
import 'package:devocional/dados/leituras_da_conversa.dart';
import 'package:devocional/dados/personas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('leituraPedida', () {
    test('Manhã, Noite e Dia pedem os períodos de Manhã e Noite', () {
      expect(leituraPedida('17/11 | Manhã | Salmos 23:1')?.leituras, {
        LeituraDoDia.manha,
      });
      expect(leituraPedida('17/11/2026 | noite | João 3:16')?.leituras, {
        LeituraDoDia.noite,
      });
      expect(
        leituraPedida(
          'Faça a descrição: 05/01 | Devocional do Dia | Gn 1:4',
        )?.leituras,
        {LeituraDoDia.manha, LeituraDoDia.noite},
      );
    });

    test('outro texto no meio é o título de uma promessa', () {
      final pedida = leituraPedida(
        '01/01 | A primeira promessa da Bíblia | Gênesis 3:15',
      );
      expect(pedida?.leituras, {LeituraDoDia.promessa});
      expect(pedida?.data.day, 1);
      expect(pedida?.data.month, 1);
    });

    test('29/02 sem ano existe, data impossível e texto comum não', () {
      expect(leituraPedida('29/02 | Manhã | Rm 8:28')?.data.month, 2);
      expect(leituraPedida('31/02 | Manhã | Rm 8:28'), isNull);
      expect(leituraPedida('Como orar quando estou triste?'), isNull);
    });
  });

  group('instrução de sistema', () {
    final agora = DateTime(2026, 11, 17, 8, 0);

    test('as duas personas conhecem os livros da Biblioteca', () {
      for (final persona in todasAsPersonas) {
        final sistema = instrucaoDoSistema(persona, agora);
        for (final obra in obrasDaBiblioteca) {
          expect(sistema, contains(obra.titulo));
        }
      }
    });

    test('as leituras do app entram só quando vêm', () {
      final com = instrucaoDoSistema(
        personaSpurgeon,
        agora,
        leituras: '### Promessas de Deus\nTexto da promessa.',
      );
      expect(com, contains('Leituras de Spurgeon neste aplicativo'));
      expect(com, contains('Texto da promessa.'));
      expect(
        instrucaoDoSistema(personaSpurgeon, agora),
        isNot(contains('Leituras de Spurgeon neste aplicativo')),
      );
    });
  });

  testWidgets('carrega dos assets as leituras de hoje e as da data pedida', (
    tester,
  ) async {
    final texto = await tester.runAsync(
      () => leiturasDaConversa(
        'Descrição: 05/01 | Dia | Gênesis 1:4',
        DateTime(2026, 11, 17, 8),
      ),
    );

    expect(texto, isNotNull);
    for (final trecho in [
      'Manhã e Noite, leitura da Manhã, 17 de novembro (Hoje)',
      'Manhã e Noite, leitura da Noite, 17 de novembro (Hoje)',
      'Promessas de Deus, 17 de novembro (Hoje)',
      'Manhã e Noite, leitura da Manhã, 5 de janeiro',
      'Manhã e Noite, leitura da Noite, 5 de janeiro',
      'a luz era boa',
    ]) {
      expect(texto, contains(trecho));
    }
    expect(texto, isNot(contains('Promessas de Deus, 5 de janeiro')));
  });
}
