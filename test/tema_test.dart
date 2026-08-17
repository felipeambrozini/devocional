import 'dart:math' as math;

import 'package:felipe_ambrozini/data/modelos.dart';
import 'package:felipe_ambrozini/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('peso das fontes variáveis', () {
    // Cinzel e Montserrat são variáveis, e o campo `weight` do pubspec não move
    // o eixo `wght`: sem `fontVariations` o motor desenha a instância padrão de
    // cada arquivo, que é Regular no Cinzel e Thin no Montserrat. Todo o app
    // saía no peso errado e nenhum `fontWeight` do tema tinha efeito. Este teste
    // é o que impede a regressão, porque ela é invisível na análise estática.
    double? eixoDePeso(TextStyle? estilo) {
      final variacao = estilo?.fontVariations
          ?.where((v) => v.axis == 'wght')
          .firstOrNull;
      return variacao?.value;
    }

    test('os títulos em Cinzel pedem o eixo wght, não só o fontWeight', () {
      final tema = construirTema().textTheme;
      expect(eixoDePeso(tema.displayLarge), 700);
      expect(eixoDePeso(tema.headlineMedium), 600);
      expect(eixoDePeso(tema.titleLarge), 600);
    });

    test(
      'o corpo em Montserrat pede o eixo wght, inclusive no peso padrão',
      () {
        final tema = construirTema().textTheme;
        expect(
          eixoDePeso(tema.bodyLarge),
          400,
          reason: 'sem isto o corpo do app inteiro sairia em Thin',
        );
        expect(eixoDePeso(tema.titleMedium), 600);
        expect(eixoDePeso(tema.labelLarge), 600);
      },
    );

    test('todo estilo do tema declara o eixo', () {
      final tema = construirTema().textTheme;
      final estilos = <String, TextStyle?>{
        'displayLarge': tema.displayLarge,
        'displayMedium': tema.displayMedium,
        'headlineLarge': tema.headlineLarge,
        'headlineMedium': tema.headlineMedium,
        'headlineSmall': tema.headlineSmall,
        'titleLarge': tema.titleLarge,
        'titleMedium': tema.titleMedium,
        'titleSmall': tema.titleSmall,
        'bodyLarge': tema.bodyLarge,
        'bodyMedium': tema.bodyMedium,
        'bodySmall': tema.bodySmall,
        'labelLarge': tema.labelLarge,
        'labelMedium': tema.labelMedium,
      };
      for (final MapEntry(key: nome, value: estilo) in estilos.entries) {
        expect(eixoDePeso(estilo), isNotNull, reason: nome);
      }
    });
  });

  group('contraste das duas paletas', () {
    // A conta da WCAG. Está aqui porque os números do comentário de theme.dart
    // não valem nada se ninguém os verificar: clarear o bronze "só um pouco"
    // para ficar mais bonito é exatamente o tipo de mudança que passa numa
    // revisão e deixa o texto ilegível no sol.
    double luminancia(Color c) {
      double canal(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4) as double;
      return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
    }

    double contraste(Color a, Color b) {
      final la = luminancia(a);
      final lb = luminancia(b);
      final (maior, menor) = la > lb ? (la, lb) : (lb, la);
      return (maior + 0.05) / (menor + 0.05);
    }

    for (final brilho in Brightness.values) {
      final nome = brilho == Brightness.dark ? 'escuro' : 'claro';
      final cor = construirTema(brilho: brilho).colorScheme;

      test('$nome: o corpo do texto passa de 7:1 sobre o fundo', () {
        // 4,5:1 é o mínimo da AA, mas o uso deste app é ler capítulo inteiro
        // todo dia, e por isso o corpo mira o AAA.
        expect(contraste(cor.onSurface, cor.surface), greaterThan(7));
      });

      test('$nome: apoio, título e destaque passam de 4,5:1 sobre o fundo', () {
        expect(
          contraste(cor.onSurfaceVariant, cor.surface),
          greaterThan(4.5),
          reason: 'legenda e texto secundário',
        );
        expect(
          contraste(cor.primary, cor.surface),
          greaterThan(4.5),
          reason: 'título e ícone',
        );
        expect(
          contraste(cor.secondary, cor.surface),
          greaterThan(4.5),
          reason: 'citação e referência',
        );
      });

      test(
        '$nome: o texto também passa sobre o cartão, não só sobre o fundo',
        () {
          // O cartão é outro fundo, e é onde quase todo texto do app fica.
          expect(
            contraste(cor.onSurface, cor.surfaceContainer),
            greaterThan(7),
          );
          expect(
            contraste(cor.onSurfaceVariant, cor.surfaceContainer),
            greaterThan(4.5),
          );
          expect(
            contraste(cor.primary, cor.surfaceContainer),
            greaterThan(4.5),
          );
          expect(
            contraste(cor.secondary, cor.surfaceContainer),
            greaterThan(4.5),
          );
        },
      );

      test(
        '$nome: o chip escolhido tem letra legível sobre o próprio fundo',
        () {
          // Lê do ChipThemeData, e não de `primary` na mão: a primeira versão
          // deste teste checava o par errado e passava enquanto o chip de
          // verdade ficava em 3,7:1. O chip é o alternador de mês e de leitura,
          // ou seja, texto que se lê o tempo todo.
          final chip = construirTema(brilho: brilho).chipTheme;
          expect(
            contraste(chip.secondaryLabelStyle!.color!, chip.selectedColor!),
            greaterThan(4.5),
          );
          // E o chip não escolhido também tem fundo próprio.
          expect(
            contraste(chip.labelStyle!.color!, chip.backgroundColor!),
            greaterThan(4.5),
          );
        },
      );

      test(
        '$nome: o botão de voz ativo tem letra legível sobre o próprio fundo',
        () {
          // O "Parar" do botão de ouvir usa primaryContainer com o metal
          // cheio, a mesma receita do chip escolhido. Se alguém trocar o
          // container por um tom sem contraste, o teste avisa.
          final cor = construirTema(brilho: brilho).colorScheme;
          expect(
            contraste(cor.onPrimaryContainer, cor.primaryContainer),
            greaterThan(4.5),
          );
        },
      );
    }

    test('o destaque é o tom mais distante do fundo nas duas paletas', () {
      // A hierarquia precisa espelhar: no escuro o destaque é mais claro que o
      // título, no claro é mais escuro. Inverter isso faria a citação parecer
      // menos importante que o texto em volta.
      final escuro = construirTema(brilho: Brightness.dark).colorScheme;
      final claro = construirTema(brilho: Brightness.light).colorScheme;
      expect(
        contraste(escuro.secondary, escuro.surface),
        greaterThan(contraste(escuro.primary, escuro.surface)),
      );
      expect(
        contraste(claro.secondary, claro.surface),
        greaterThan(contraste(claro.primary, claro.surface)),
      );
    });
  });

  group('as duas paletas', () {
    test('o claro não é o escuro reaproveitado', () {
      final escuro = construirTema(brilho: Brightness.dark).colorScheme;
      final claro = construirTema(brilho: Brightness.light).colorScheme;
      expect(claro.brightness, Brightness.light);
      expect(escuro.brightness, Brightness.dark);
      expect(claro.primary, isNot(escuro.primary));
      expect(claro.surface, isNot(escuro.surface));
    });

    test('a escala de leitura vale nos dois', () {
      for (final brilho in Brightness.values) {
        final t = construirTema(brilho: brilho, escalaDeLeitura: 1.3).textTheme;
        expect(
          t.bodyLarge?.fontSize,
          closeTo(17 * 1.3, 0.001),
          reason: '$brilho',
        );
      }
    });
  });

  group('escala do texto de leitura', () {
    test('sem escala, os tamanhos são os de sempre', () {
      final tema = construirTema().textTheme;
      expect(tema.bodyLarge?.fontSize, 17);
      expect(tema.bodyMedium?.fontSize, 15);
    });

    test('a escala multiplica só o texto corrido de leitura', () {
      final padrao = construirTema().textTheme;
      final grande = construirTema(escalaDeLeitura: 1.3).textTheme;

      expect(grande.bodyLarge?.fontSize, closeTo(17 * 1.3, 0.001));
      expect(grande.bodyMedium?.fontSize, closeTo(15 * 1.3, 0.001));

      // Rótulo de navegação, título e legenda ficam parados: aumentar a fonte de
      // leitura não deve empurrar a barra de baixo nem quebrar o cabeçalho.
      expect(grande.bodySmall?.fontSize, padrao.bodySmall?.fontSize);
      expect(grande.labelMedium?.fontSize, padrao.labelMedium?.fontSize);
      expect(grande.headlineMedium?.fontSize, padrao.headlineMedium?.fontSize);
      expect(grande.titleSmall?.fontSize, padrao.titleSmall?.fontSize);
    });

    test('os passos oferecidos têm um rótulo cada e incluem o padrão', () {
      expect(rotulosDeEscala.length, escalasDeLeitura.length);
      expect(escalasDeLeitura, contains(1.0));
      expect(escalasDeLeitura, orderedEquals([...escalasDeLeitura]..sort()));
    });
  });
}
