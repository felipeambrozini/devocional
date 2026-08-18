import 'package:flutter/material.dart';

/// As duas paletas: marrom e dourada no escuro, pergaminho e bronze no claro.
///
/// A clara não é a escura invertida. O dourado `#C9A227` sobre pergaminho dá
/// 2,1:1 e é ilegível: o que carrega a identidade num fundo claro é o mesmo
/// metal, mas escuro, e por isso o par de destaques vira bronze. A relação entre
/// os tons é que se mantém, não os valores.
///
/// Todo par abaixo foi conferido contra o fundo em que é usado. Os números estão
/// anotados porque é a única forma de a próxima pessoa saber que não pode
/// clarear o bronze "só um pouco" sem refazer a conta.
abstract final class Cores {
  // Escuro. Corpo em [bege] e não em dourado puro: dourado sobre marrom fica em
  // torno de 4:1, que cansa a vista num capítulo inteiro, e o bege chega a 11:1.
  static const fundo = Color(0xFF2E1B10);
  static const superficie = Color(0xFF3D2417);
  static const superficieAlta = Color(0xFF4A2E1D);
  static const dourado = Color(0xFFC9A227); // 6,8:1 sobre o fundo
  static const douradoClaro = Color(0xFFE3C567); // destaque, mais claro
  static const douradoEscuro = Color(0xFF8C6D1F); // traço e borda
  static const bege = Color(0xFFEDE0C8); // corpo, 11:1
  static const begeSuave = Color(0xFFC9B99A); // apoio, 8,5:1

  // Claro. A hierarquia espelha a de cima: o destaque é o tom mais distante do
  // fundo, que aqui quer dizer mais escuro em vez de mais claro.
  static const pergaminho = Color(0xFFF7F1E3);
  static const pergaminhoAlto = Color(0xFFFFFBF2);
  static const pergaminhoFundo = Color(0xFFEFE4CE);
  static const bronze = Color(0xFF7A5C12); // 5,5:1 sobre o pergaminho
  static const bronzeEscuro = Color(0xFF5E4409); // destaque, 8,1:1
  static const bronzeSuave = Color(0xFFC2AE86); // traço e borda
  static const tinta = Color(0xFF3D2417); // corpo, 12,8:1
  static const tintaSuave = Color(0xFF6B5842); // apoio, 6,0:1
}

/// Monta o tema.
///
/// [escalaDeLeitura] multiplica só os estilos do texto corrido, que é o que o
/// leitor da Bíblia, o devocional e as introduções usam. Rótulo de navegação,
/// título e legenda ficam parados: aumentar a fonte de leitura não deve empurrar
/// a barra de baixo nem quebrar o cabeçalho.
///
/// [brilho] escolhe a paleta. As telas nunca leem de [Cores] direto: tudo sai do
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
          primary: Cores.dourado,
          onPrimary: Cores.fundo,
          secondary: Cores.douradoClaro,
          onSecondary: Cores.fundo,
          surface: Cores.fundo,
          onSurface: Cores.bege,
          surfaceContainer: Cores.superficie,
          surfaceContainerHighest: Cores.superficieAlta,
          onSurfaceVariant: Cores.begeSuave,
          outline: Cores.douradoEscuro,
          error: Color(0xFFE57373),
        )
      : const ColorScheme.light(
          primary: Cores.bronze,
          onPrimary: Cores.pergaminhoAlto,
          secondary: Cores.bronzeEscuro,
          onSecondary: Cores.pergaminhoAlto,
          surface: Cores.pergaminho,
          onSurface: Cores.tinta,
          surfaceContainer: Cores.pergaminhoAlto,
          surfaceContainerHighest: Cores.pergaminhoFundo,
          onSurfaceVariant: Cores.tintaSuave,
          outline: Cores.bronzeSuave,
          error: Color(0xFF9B2C2C),
        );

  // Cinzel e Montserrat são fontes variáveis, e o campo `weight` do pubspec não
  // move o eixo `wght` de uma delas: ele só rotula o arquivo. Sem `fontVariations`
  // o peso final fica por conta do casamento e da síntese de fonte do motor, que
  // variam por plataforma. `fontWeight` continua declarado porque é o que o
  // Flutter usa para escolher a família; `fontVariations` é o que pesa a letra.
  TextStyle titulo(double tamanho, FontWeight peso) => TextStyle(
    fontFamily: 'Cinzel',
    fontSize: tamanho,
    fontWeight: peso,
    fontVariations: [FontVariation('wght', peso.value.toDouble())],
    color: esquema.primary,
  );
  TextStyle corpo(double tamanho, {Color? cor, FontWeight? peso}) => TextStyle(
    fontFamily: 'Montserrat',
    fontSize: tamanho,
    color: cor ?? esquema.onSurface,
    fontWeight: peso,
    fontVariations: [
      FontVariation('wght', (peso ?? FontWeight.w400).value.toDouble()),
    ],
  );

  /// Texto corrido de leitura, o único que a escala do usuário afeta.
  TextStyle leitura(double tamanho) => corpo(tamanho * escalaDeLeitura);

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
