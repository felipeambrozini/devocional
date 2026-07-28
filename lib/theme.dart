import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta marrom e dourada.
///
/// Sobre "letras douradas": dourado puro sobre marrom fica em torno de 4:1 de
/// contraste, o que cansa a vista numa leitura de capítulo inteiro, que é
/// justamente o uso deste app. Então título e destaque ficam dourados, e o corpo
/// do texto fica em [bege], um dourado claro que atinge 11:1 e se lê por horas.
abstract final class Cores {
  static const fundo = Color(0xFF2E1B10);
  static const superficie = Color(0xFF3D2417);
  static const superficieAlta = Color(0xFF4A2E1D);
  static const dourado = Color(0xFFC9A227);
  static const douradoClaro = Color(0xFFE3C567);
  static const douradoEscuro = Color(0xFF8C6D1F);
  static const bege = Color(0xFFEDE0C8);
  static const begeSuave = Color(0xFFC9B99A);
}

ThemeData construirTema() {
  const esquema = ColorScheme.dark(
    primary: Cores.dourado,
    onPrimary: Cores.fundo,
    secondary: Cores.douradoClaro,
    onSecondary: Cores.fundo,
    surface: Cores.superficie,
    onSurface: Cores.bege,
    surfaceContainerHighest: Cores.superficieAlta,
    outline: Cores.douradoEscuro,
    error: Color(0xFFE57373),
  );

  TextStyle titulo(double tamanho, FontWeight peso) =>
      GoogleFonts.cinzel(fontSize: tamanho, fontWeight: peso, color: Cores.dourado);
  TextStyle corpo(double tamanho, {Color cor = Cores.bege, FontWeight? peso}) =>
      GoogleFonts.montserrat(fontSize: tamanho, color: cor, fontWeight: peso);

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Cores.fundo,
    canvasColor: Cores.fundo,
    dividerColor: Cores.douradoEscuro.withValues(alpha: 0.4),
    textTheme: TextTheme(
      displayLarge: titulo(34, FontWeight.w700),
      displayMedium: titulo(28, FontWeight.w700),
      headlineLarge: titulo(26, FontWeight.w600),
      headlineMedium: titulo(22, FontWeight.w600),
      headlineSmall: titulo(19, FontWeight.w600),
      titleLarge: titulo(18, FontWeight.w600),
      titleMedium: corpo(16, peso: FontWeight.w600),
      titleSmall: corpo(14, peso: FontWeight.w600, cor: Cores.begeSuave),
      bodyLarge: corpo(17),
      bodyMedium: corpo(15),
      bodySmall: corpo(13, cor: Cores.begeSuave),
      labelLarge: corpo(14, peso: FontWeight.w600),
      labelMedium: corpo(12, cor: Cores.begeSuave),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Cores.fundo,
      foregroundColor: Cores.dourado,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: titulo(20, FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: Cores.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Cores.douradoEscuro.withValues(alpha: 0.35)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Cores.superficie,
      indicatorColor: Cores.douradoEscuro.withValues(alpha: 0.45),
      labelTextStyle: WidgetStatePropertyAll(corpo(11, peso: FontWeight.w600)),
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected) ? Cores.douradoClaro : Cores.begeSuave,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Cores.superficie,
      indicatorColor: Cores.douradoEscuro.withValues(alpha: 0.45),
      selectedIconTheme: const IconThemeData(color: Cores.douradoClaro),
      unselectedIconTheme: const IconThemeData(color: Cores.begeSuave),
      selectedLabelTextStyle: corpo(12, peso: FontWeight.w600, cor: Cores.douradoClaro),
      unselectedLabelTextStyle: corpo(12, cor: Cores.begeSuave),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Cores.superficieAlta,
      selectedColor: Cores.douradoEscuro,
      labelStyle: corpo(13),
      side: BorderSide(color: Cores.douradoEscuro.withValues(alpha: 0.5)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Cores.bege,
      iconColor: Cores.begeSuave,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Cores.superficie,
      hintStyle: corpo(15, cor: Cores.begeSuave),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Cores.douradoEscuro.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Cores.douradoEscuro.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cores.dourado),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: Cores.superficie),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Cores.superficie),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Cores.superficieAlta,
      contentTextStyle: corpo(14),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Cores.superficie,
      headerBackgroundColor: Cores.superficieAlta,
      headerForegroundColor: Cores.dourado,
      todayForegroundColor: const WidgetStatePropertyAll(Cores.douradoClaro),
      todayBorder: const BorderSide(color: Cores.dourado),
    ),
  );
}
