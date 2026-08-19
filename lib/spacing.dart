/// O ritmo de espaçamento do app.
///
/// Cada token guarda o próprio valor em pixels: é o conjunto de números que o
/// layout pode usar, não uma palavra que esconde o número. Isso permite trocar
/// o valor de um degrau inteiro num lugar só e deixa explícito no código o
/// espaço usado. A escala cresce de 2 em 2 até 6, salta para 8 e depois anda
/// por múltiplos de 2 (10, 12, 14, 16, 18, 20), refletindo o que as telas
/// realmente precisam; a partir de 24 sobe em saltos de 8, e os degraus maiores
/// (40 a 200) ficam reservados para vãos estruturais e áreas de respiro.
abstract final class Spacing {
  static const double sp2 = 2.0;
  static const double sp3 = 3.0;
  static const double sp4 = 4.0;
  static const double sp5 = 5.0;
  static const double sp6 = 6.0;
  static const double sp8 = 8.0;
  static const double sp10 = 10.0;
  static const double sp12 = 12.0;
  static const double sp14 = 14.0;
  static const double sp16 = 16.0;
  static const double sp18 = 18.0;
  static const double sp20 = 20.0;
  static const double sp24 = 24.0;
  static const double sp32 = 32.0;
  static const double sp40 = 40.0;
  static const double sp48 = 48.0;
  static const double sp56 = 56.0;
  static const double sp64 = 64.0;
  static const double sp80 = 80.0;
  static const double sp120 = 120.0;
  static const double sp160 = 160.0;
  static const double sp200 = 200.0;
}