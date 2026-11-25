import 'package:material_ui/material_ui.dart';

import 'cores.dart';

/// [escalaDeLeitura] multiplica o texto corrido de leitura (bodyLarge/Medium)
/// integralmente e os títulos/rótulos com teto de 1,3× — Regra da Escala do
/// DESIGN.md: aumentar o corpo não pode estourar AppBar/Nav.
///
/// [brilho] escolhe a paleta. As telas nunca leem de [TabernaculoCores] direto: tudo sai do
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
  //   tertiary                letra vermelha das falas de Deus na Bíblia
  //   outline                 borda e filete
  //   outlineVariant          divisor (o outline a 40%, ver abaixo)
  //   onSurface               corpo do texto
  //   onSurfaceVariant        apoio: legenda, rótulo, texto secundário
  final base = escuro
      ? const ColorScheme.dark(
          primary: TabernaculoCores.dourado,
          onPrimary: TabernaculoCores.fundo,
          secondary: TabernaculoCores.douradoClaro,
          onSecondary: TabernaculoCores.fundo,
          surface: TabernaculoCores.fundo,
          onSurface: TabernaculoCores.bege,
          surfaceContainer: TabernaculoCores.superficie,
          surfaceContainerHighest: TabernaculoCores.superficieAlta,
          onSurfaceVariant: TabernaculoCores.begeSuave,
          outline: TabernaculoCores.douradoEscuro,
          tertiary: TabernaculoCores.carmimClaro,
          error: Color(0xFFE57373),
        )
      : const ColorScheme.light(
          primary: TabernaculoCores.bronze,
          onPrimary: TabernaculoCores.pergaminhoAlto,
          secondary: TabernaculoCores.bronzeEscuro,
          onSecondary: TabernaculoCores.pergaminhoAlto,
          surface: TabernaculoCores.pergaminho,
          onSurface: TabernaculoCores.tinta,
          surfaceContainer: TabernaculoCores.pergaminhoAlto,
          surfaceContainerHighest: TabernaculoCores.pergaminhoFundo,
          onSurfaceVariant: TabernaculoCores.tintaSuave,
          outline: TabernaculoCores.bronzeSuave,
          tertiary: TabernaculoCores.carmim,
          error: Color(0xFF9B2C2C),
        );
  // Sem outlineVariant o Material 3 cai no onSurface: Divider, VerticalDivider
  // e a linha sob a TabBar saíam na cor cheia do texto, contra a Regra do Fio.
  final esquema = base.copyWith(
    outlineVariant: base.outline.withValues(alpha: 0.4),
  );

  // Cinzel e Montserrat são fontes variáveis, e o campo `weight` do pubspec não
  // move o eixo `wght` de uma delas: ele só rotula o arquivo. Sem `fontVariations`
  // o peso final fica por conta do casamento e da síntese de fonte do motor, que
  // variam por plataforma. `fontWeight` continua declarado porque é o que o
  // Flutter usa para escolher a família; `fontVariations` é o que pesa a letra.
  //
  // Regra da Escala (DESIGN.md): a escala do usuário multiplica inteira só
  // bodyLarge/bodyMedium. Títulos, rótulos e o resto do texto escalam só 30%
  // do solicitado (teto 1,3×) para não estourar AppBar/Nav em 2×.
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
    // Padrão do Flutter no desktop web é denso e sem área extra: botões e
    // chips ficavam abaixo dos 48 dp.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    brightness: brilho,
    colorScheme: esquema,
    scaffoldBackgroundColor: esquema.surface,
    canvasColor: esquema.surface,
    dividerColor: esquema.outlineVariant,
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
      // Sem isto o labelSmall caía na tipografia padrão do Material (Roboto),
      // uma terceira família contra a Regra das Duas Vozes.
      labelSmall: corpo(
        11,
        peso: FontWeight.w600,
        cor: esquema.onSurfaceVariant,
      ),
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
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => corpo(
          11,
          peso: FontWeight.w600,
          cor: estados.contains(WidgetState.selected)
              ? esquema.secondary
              : esquema.onSurfaceVariant,
        ),
      ),
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
      unselectedLabelTextStyle: corpo(
        12,
        peso: FontWeight.w600,
        cor: esquema.onSurfaceVariant,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: esquema.secondary,
      unselectedLabelColor: esquema.onSurfaceVariant,
      indicatorColor: esquema.primary,
      labelStyle: corpo(14, peso: FontWeight.w600),
      unselectedLabelStyle: corpo(14, peso: FontWeight.w600),
    ),
    // Regra do Chapado: nenhum botão ganha sombra, nem no hover (o padrão do
    // Material 3 eleva o FilledButton). Cantos de 12px, não a pílula padrão.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: _cantosDeBotao,
        textStyle: corpo(14, peso: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: esquema.secondary,
            shape: _cantosDeBotao,
            textStyle: corpo(14, peso: FontWeight.w600),
          ).copyWith(
            // Desabilitado, o fio apaga junto com a letra: senão o botão parecia
            // ativo e só a letra a 38% dizia o contrário.
            side: WidgetStateProperty.resolveWith(
              (estados) => BorderSide(
                color: estados.contains(WidgetState.disabled)
                    ? esquema.onSurface.withValues(alpha: 0.12)
                    : traco.withValues(alpha: 0.5),
              ),
            ),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: esquema.secondary,
        shape: _cantosDeBotao,
        textStyle: corpo(14, peso: FontWeight.w600),
      ),
    ),
    // Superfícies flutuantes sem sombra se separam da página pelo tom mais alto
    // e pelo fio do metal cheio (presença, na Regra do Fio): com o fundo do
    // cartão e o fio a 35%, o menu sumia contra a página no tema claro.
    popupMenuTheme: PopupMenuThemeData(
      color: esquema.surfaceContainerHighest,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: traco),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: esquema.surfaceContainerHighest,
      // O chip escolhido usa o metal cheio com a letra do contrário por cima,
      // igual nas duas paletas. Antes o escuro pintava o fundo de douradoEscuro
      // e deixava a letra bege: 3,7:1, abaixo do mínimo para texto, e o rótulo
      // do mês ou da leitura selecionada era justamente o mais difícil de ler
      // da régua inteira. Com o metal cheio dá 6,8:1 no escuro e 6,0:1 no claro.
      selectedColor: esquema.primary,
      showCheckmark: false,
      labelStyle: corpo(13),
      secondaryLabelStyle: corpo(13, cor: esquema.onPrimary),
      side: BorderSide(color: traco.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: ListTileThemeData(
      textColor: esquema.onSurface,
      iconColor: esquema.onSurfaceVariant,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainer,
      hintStyle: corpo(15, cor: esquema.onSurfaceVariant),
      // O traço do tema (outline) fica abaixo dos 3:1 que a borda de um campo
      // pede; o campo usa a cor de apoio do texto.
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.onSurfaceVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.onSurfaceVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.primary),
      ),
      // Sem estes o Material usava, no hover do campo com erro, uma cor que o
      // esquema não define e que sumia contra o fundo.
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.error, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: esquema.surfaceContainer),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: esquema.surfaceContainer,
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: esquema.surfaceContainerHighest,
      contentTextStyle: corpo(14),
      // Sem isto a ação ("Desfazer") caía no inversePrimary, que sem valor no
      // esquema vira onPrimary: couro sobre couro, 1,3:1.
      actionTextColor: esquema.secondary,
      elevation: 0,
      // Sem sombra, o fio do metal cheio separa o aviso da página.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: traco),
      ),
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

const _cantosDeBotao = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
);

/// Regra do Peso Variável (DESIGN.md): Cinzel e Montserrat são variáveis, e
/// trocar só o `fontWeight` de um estilo do tema deixa o eixo `wght` no peso
/// antigo, então a letra não engrossa. Use isto em vez de
/// `copyWith(fontWeight:)`.
extension PesoVariavel on TextStyle {
  TextStyle comPeso(FontWeight peso) => copyWith(
    fontWeight: peso,
    fontVariations: [FontVariation('wght', peso.value.toDouble())],
  );
}
