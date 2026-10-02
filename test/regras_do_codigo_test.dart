import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Trava mecânica das duas regras do projeto que o analyzer não conhece: o
/// texto do app sem travessão e sem aspas curvas, e a Regra dos Papéis do
/// DESIGN.md (tela e widget nunca leem `DevocionalCores`).
///
/// Varre `lib/` porque é o que vira tela. `test/`, `tools/` e `assets/` ficam
/// de fora de propósito: comentário e dado bruto não são texto que a pessoa
/// lê.
void main() {
  final fontes = <({String caminho, String fonte})>[
    for (final arquivo in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>())
      if (arquivo.path.endsWith('.dart'))
        (
          caminho: arquivo.path.replaceAll(r'\', '/'),
          fonte: arquivo.readAsStringSync(),
        ),
  ];

  group('texto do app', () {
    test('sem travessão e sem aspas curvas fora de comentário', () {
      const proibidos = {
        '—': 'travessão',
        '–': 'meio-travessão',
        '“': 'aspa curva de abertura',
        '”': 'aspa curva de fechamento',
        '‘': 'apóstolo curva de abertura',
        '’': 'apóstolo curva de fechamento',
      };
      // Exceção de duas linhas, e ela se declara: a regra "sem travessão" é
      // escrita dentro do prompt da IA, e ali o travessão é o próprio exemplo
      // do que não usar. Se um dia o prompt mudar de frase, a exceção some
      // junto e o teste volta a valer para o arquivo inteiro.
      const ondeSeDeclara = 'PROIBIDO usar travessões';

      final achados = <String>[];
      for (final arquivo in fontes) {
        for (final linha in _codigoPorLinha(arquivo.fonte)) {
          if (linha.texto.contains(ondeSeDeclara)) continue;
          for (final proibido in proibidos.entries) {
            if (!linha.texto.contains(proibido.key)) continue;
            achados.add(
              '${arquivo.caminho}:${linha.numero}: '
              '${proibido.value} em "${_recorte(linha.texto)}"',
            );
          }
        }
      }

      expect(
        achados,
        isEmpty,
        reason:
            'Texto visível sem travessão e sem aspas curvas (README.md, '
            '"Regras de texto do produto"). Nada de aspas curvas: vírgula, '
            'ponto e vírgula ou ponto. Os achados:\n'
            '${achados.join('\n')}',
      );
    });
  });

  group('Regra dos Papéis', () {
    test('nenhuma tela nem widget lê a paleta direto', () {
      final achados = <String>[];
      for (final arquivo in fontes) {
        if (!arquivo.caminho.startsWith('lib/telas/') &&
            !arquivo.caminho.startsWith('lib/widgets/')) {
          continue;
        }
        for (final linha in _codigoPorLinha(arquivo.fonte)) {
          if (!linha.texto.contains('DevocionalCores')) continue;
          achados.add(
            '${arquivo.caminho}:${linha.numero}: ${linha.texto.trim()}',
          );
        }
      }

      expect(
        achados,
        isEmpty,
        reason:
            'Tela e widget leem tudo de Theme.of(context).colorScheme; só '
            'lib/estilo/tema.dart importa a paleta (DESIGN.md, "Regra dos '
            'Papéis"). Achados:\n${achados.join('\n')}',
      );
    });
  });
}

class _Linha {
  const _Linha(this.numero, this.texto);

  final int numero;
  final String texto;
}

/// As linhas do arquivo com o comentário de linha apagado (o resto byte a
/// byte, para o número da linha continuar valendo). É o que os dois testes
/// precisam: um travessão que sobra só pode estar em string, e a
/// `DevocionalCores` que sobra só pode ser referência de verdade, não a
/// citação da própria regra.
List<_Linha> _codigoPorLinha(String fonte) {
  final linhas = <_Linha>[];
  var numero = 0;
  for (final linha in fonte.split('\n')) {
    numero++;
    linhas.add(_Linha(numero, _semComentarioDeLinha(linha)));
  }
  return linhas;
}

/// A linha sem o comentário que começa nela.
///
/// Conta aspas da esquerda para a direita para saber quando está dentro de
/// uma string, porque um `//` dentro de um literal (`'a//b'`) não abre
/// comentário. Vale enquanto `lib/` não tiver string de três aspas nem
/// comentário de bloco: os dois dariam ambiguidade, e um teste que dá resultado
/// errado em silêncio é pior do que nenhum teste. Se um dia aparecer um dos
/// dois, é este método que precisa virar lexer.
String _semComentarioDeLinha(String linha) {
  var dentroDeAspas = false;
  var delimitador = '';
  for (var i = 0; i < linha.length; i++) {
    final caractere = linha[i];
    // Só dentro da string o contrabarra escapa o próximo caractere.
    if (dentroDeAspas && caractere == r'\') {
      i++;
      continue;
    }
    if (dentroDeAspas && caractere == delimitador) {
      dentroDeAspas = false;
      continue;
    }
    if (!dentroDeAspas && (caractere == "'" || caractere == '"')) {
      dentroDeAspas = true;
      delimitador = caractere;
      continue;
    }
    if (!dentroDeAspas && linha.startsWith('//', i)) {
      return linha.substring(0, i);
    }
  }
  return linha;
}

/// O trecho com o caractere proibido em volta, para o teste apontar onde está
/// sem despejar a linha inteira na mensagem.
String _recorte(String texto) {
  for (final indice in [
    texto.indexOf('—'),
    texto.indexOf('–'),
    texto.indexOf('“'),
    texto.indexOf('”'),
    texto.indexOf('‘'),
    texto.indexOf('’'),
  ]) {
    if (indice < 0) continue;
    final comecar = indice - 30 < 0 ? 0 : indice - 30;
    final fim = indice + 30 > texto.length ? texto.length : indice + 30;
    return texto.substring(comecar, fim).trim();
  }
  return texto.trim();
}
