import 'package:flutter/material.dart';

@immutable
class MutcoPalette {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color secondary;
  final Color tertiary;
  final Color separator;
  final Color divider;
  final Color accent;
  final Color accentSoft;
  final Color danger;
  final bool dark;

  const MutcoPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.secondary,
    required this.tertiary,
    required this.separator,
    required this.divider,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dark,
  });

  static const light = MutcoPalette(
    background: Color(0xffececeb),
    surface: Colors.white,
    surfaceAlt: Color(0xfff1f1f1),
    text: Color(0xff111111),
    secondary: Color(0xff6e6e73),
    tertiary: Color(0xffa0a0a5),
    separator: Color(0xffe5e5e7),
    divider: Color(0xffececee),
    accent: Color(0xff111111),
    accentSoft: Color(0xfff1f1f1),
    danger: Color(0xffd83032),
    dark: false,
  );

  static const night = MutcoPalette(
    background: Color(0xff101010),
    surface: Color(0xff1c1c1c),
    surfaceAlt: Color(0xff262626),
    text: Color(0xfff5f5f5),
    secondary: Color(0xffaaaaaa),
    tertiary: Color(0xff777777),
    separator: Color(0xff363636),
    divider: Color(0xff303030),
    accent: Color(0xfff5f5f5),
    accentSoft: Color(0xff262626),
    danger: Color(0xffff6961),
    dark: true,
  );

  static MutcoPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? night : light;
}

class MutcoTheme {
  static ThemeData create(MutcoPalette p) {
    final scheme =
        ColorScheme(
          brightness: p.dark ? Brightness.dark : Brightness.light,
          primary: p.text,
          onPrimary: p.dark ? const Color(0xff111111) : Colors.white,
          secondary: p.secondary,
          onSecondary: p.surface,
          error: p.danger,
          onError: Colors.white,
          surface: p.surface,
          onSurface: p.text,
        ).copyWith(
          primaryContainer: p.surfaceAlt,
          onPrimaryContainer: p.text,
          secondaryContainer: p.surfaceAlt,
          onSecondaryContainer: p.text,
          tertiary: p.secondary,
          onTertiary: p.surface,
          tertiaryContainer: p.surfaceAlt,
          onTertiaryContainer: p.text,
          surfaceContainerLowest: p.background,
          surfaceContainerLow: p.surface,
          surfaceContainer: p.surfaceAlt,
          surfaceContainerHigh: p.surfaceAlt,
          surfaceContainerHighest: p.surfaceAlt,
          outline: p.separator,
          outlineVariant: p.separator,
          inverseSurface: p.text,
          onInverseSurface: p.background,
          inversePrimary: p.background,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: p.dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      cardColor: p.surface,
      dividerColor: p.divider,
      canvasColor: p.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.secondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.separator),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.text,
          foregroundColor: p.dark ? const Color(0xff111111) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: p.separator),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.text,
        side: BorderSide(color: p.separator),
        labelStyle: TextStyle(color: p.text),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.text : p.secondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.surfaceAlt
              : p.separator,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceAlt,
        contentTextStyle: TextStyle(color: p.text),
      ),
    );
  }
}
