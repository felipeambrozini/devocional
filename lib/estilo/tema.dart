import 'package:flutter/material.dart';

import 'cores.dart';

/// Monta o tema.
///
/// [escalaDeLeitura] multiplica o texto corrido de leitura (bodyLarge/Medium)
/// integralmente e os títulos/rótulos com teto de 1,3× — Regra da Escala do
/// DESIGN.md: aumentar o corpo não pode estourar AppBar/Nav.
///
/// [brilho] escolhe a paleta. As telas nunca leem de [DevocionalCores] direto: tudo sai do
/// `ColorScheme`, senão metade da interface continuaria marrom sobre pergaminho.
ThemeData construirTema({
  Brightness brilho = Brightness.dark,
  double escalaDeLeitura = 1.0,
}) {
  final escuro = brilho == Brightness.dark;

  // O mapeamento para os papéis do Material 3, um por um:
  //   surface                 fundo da página
  //   surfaceContainer        cartão
  //   surfaceContainerHighest cartão dentro de cartão, citação, chip
  //   primary                 título e ícone
  //   secondary               destaque: citação, referência, aba ativa
  //   outline                 borda e filete
  //   onSurface               corpo do texto
  //   onSurfaceVariant        apoio: legenda, rótulo, texto secundário
  final esquema = escuro
      ? const ColorScheme.dark(
          primary: DevocionalCores.dourado,
          onPrimary: DevocionalCores.fundo,
          secondary: DevocionalCores.douradoClaro,
          onSecondary: DevocionalCores.fundo,
          surface: DevocionalCores.fundo,
          onSurface: DevocionalCores.bege,
          surfaceContainer: DevocionalCores.superficie,
          surfaceContainerHighest: DevocionalCores.superficieAlta,
          onSurfaceVariant: DevocionalCores.begeSuave,
          outline: DevocionalCores.douradoEscuro,
          error: Color(0xFFE57373),
        )
      : const ColorScheme.light(
          primary: DevocionalCores.bronze,
          onPrimary: DevocionalCores.pergaminhoAlto,
          secondary: DevocionalCores.bronzeEscuro,
          onSecondary: DevocionalCores.pergaminhoAlto,
          surface: DevocionalCores.pergaminho,
          onSurface: DevocionalCores.tinta,
          surfaceContainer: DevocionalCores.pergaminhoAlto,
          surfaceContainerHighest: DevocionalCores.pergaminhoFundo,
          onSurfaceVariant: DevocionalCores.tintaSuave,
          outline: DevocionalCores.bronzeSuave,
          error: Color(0xFF9B2C2C),
        );

  // Cinzel e Montserrat são fontes variáveis, e o campo `weight` do pubspec não
  // move o eixo `wght` de uma delas: ele só rotula o arquivo. Sem `fontVariations`
  // o peso final fica por conta do casamento e da síntese de fonte do motor, que
  // variam por plataforma. `fontWeight` continua declarado porque é o que o
  // Flutter usa para escolher a família; `fontVariations` é o que pesa a letra.
  //
  // Regra da Escala (DESIGN.md): a escala do usuário multiplica só
  // bodyLarge/bodyMedium — nunca a navegação, o título ou a legenda. Títulos
  // escalam só 30% do solicitado (teto 1,3×) para não estourar AppBar/Nav em 2×.
  double escalarLeitura(double tamanho) => tamanho * escalaDeLeitura;
  double escalarTitulo(double tamanho) {
    final limitada = 1.0 + (escalaDeLeitura - 1.0) * 0.3;
    return tamanho * limitada.clamp(1.0, 1.3);
  }

  TextStyle titulo(double tamanho, FontWeight peso) => TextStyle(
    fontFamily: 'Cinzel',
    fontSize: escalarTitulo(tamanho),
    fontWeight: peso,
    fontVariations: [FontVariation('wght', peso.value.toDouble())],
    color: esquema.primary,
  );
  TextStyle corpo(double tamanho, {Color? cor, FontWeight? peso}) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: escalarTitulo(tamanho),
    color: cor ?? esquema.onSurface,
    fontWeight: peso,
    fontVariations: [
      FontVariation('wght', (peso ?? FontWeight.w400).value.toDouble()),
    ],
  );

  /// Texto corrido de leitura — o único que escala integralmente (1× a 2×).
  TextStyle leitura(double tamanho, {Color? cor}) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: escalarLeitura(tamanho),
    color: cor ?? esquema.onSurface,
    fontVariations: [FontVariation('wght', FontWeight.w400.value.toDouble())],
  );

  final traco = esquema.outline;

  return ThemeData(
    useMaterial3: true,
    brightness: brilho,
    colorScheme: esquema,
    scaffoldBackgroundColor: esquema.surface,
    canvasColor: esquema.surface,
    dividerColor: traco.withValues(alpha: 0.4),
    textTheme: TextTheme(
      displayLarge: titulo(34, FontWeight.w700),
      displayMedium: titulo(28, FontWeight.w700),
      headlineLarge: titulo(26, FontWeight.w600),
      headlineMedium: titulo(22, FontWeight.w600),
      headlineSmall: titulo(19, FontWeight.w600),
      titleLarge: titulo(18, FontWeight.w600),
      titleMedium: corpo(16, peso: FontWeight.w600),
      titleSmall: corpo(
        14,
        peso: FontWeight.w600,
        cor: esquema.onSurfaceVariant,
      ),
      bodyLarge: leitura(17),
      bodyMedium: leitura(15),
      bodySmall: corpo(13, cor: esquema.onSurfaceVariant),
      labelLarge: corpo(14, peso: FontWeight.w600),
      labelMedium: corpo(12, cor: esquema.onSurfaceVariant),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: esquema.surface,
      foregroundColor: esquema.primary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: titulo(20, FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: esquema.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: traco.withValues(alpha: 0.35)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: esquema.surfaceContainer,
      indicatorColor: traco.withValues(alpha: 0.45),
      labelTextStyle: WidgetStatePropertyAll(corpo(11, peso: FontWeight.w600)),
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected)
              ? esquema.secondary
              : esquema.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: esquema.surfaceContainer,
      indicatorColor: traco.withValues(alpha: 0.45),
      selectedIconTheme: IconThemeData(color: esquema.secondary),
      unselectedIconTheme: IconThemeData(color: esquema.onSurfaceVariant),
      selectedLabelTextStyle: corpo(
        12,
        peso: FontWeight.w600,
        cor: esquema.secondary,
      ),
      unselectedLabelTextStyle: corpo(12, cor: esquema.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: esquema.surfaceContainerHighest,
      // O chip escolhido usa o metal cheio com a letra do contrário por cima,
      // igual nas duas paletas. Antes o escuro pintava o fundo de douradoEscuro
      // e deixava a letra bege: 3,7:1, abaixo do mínimo para texto, e o rótulo
      // do mês ou da leitura selecionada era justamente o mais difícil de ler
      // da régua inteira. Com o metal cheio dá 6,8:1 no escuro e 6,0:1 no claro.
      selectedColor: esquema.primary,
      labelStyle: corpo(13),
      secondaryLabelStyle: corpo(13, cor: esquema.onPrimary),
      side: BorderSide(color: traco.withValues(alpha: 0.5)),
    ),
    listTileTheme: ListTileThemeData(
      textColor: esquema.onSurface,
      iconColor: esquema.onSurfaceVariant,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainer,
      hintStyle: corpo(15, cor: esquema.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: traco.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: traco.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.primary),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: esquema.surfaceContainer),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: esquema.surfaceContainer,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: esquema.surfaceContainerHighest,
      contentTextStyle: corpo(14),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      // O anel de carregamento é o único elemento que o Material tingia com a
      // cor padrão dele; o resto do app usa o metal do tema em todo lugar.
      color: esquema.primary,
      circularTrackColor: traco.withValues(alpha: 0.4),
      linearTrackColor: esquema.surfaceContainerHighest,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: esquema.surfaceContainer,
      headerBackgroundColor: esquema.surfaceContainerHighest,
      headerForegroundColor: esquema.primary,
      todayForegroundColor: WidgetStatePropertyAll(esquema.secondary),
      todayBorder: BorderSide(color: esquema.primary),
    ),
  );
}
