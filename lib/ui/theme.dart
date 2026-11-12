import 'package:flutter/material.dart';

/// Couleurs de l'interface, désignées par leur rôle. Les widgets n'utilisent que ces
/// rôles, jamais de couleur en dur : le thème clair et le thème sombre restent cohérents.
/// Palette reprise de sDash.
@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.active,
    required this.onActive,
    required this.success,
    required this.danger,
    required this.dangerSoft,
  });

  /// Fond de la fenêtre.
  final Color background;

  /// Tuiles et panneaux.
  final Color surface;

  /// Boutons neutres et zones en retrait à l'intérieur d'une tuile.
  final Color surfaceMuted;
  final Color border;

  final Color text;
  final Color textMuted;

  /// Texte non essentiel (contraste réduit).
  final Color textFaint;

  /// Actions principales et élément sélectionné.
  final Color accent;
  final Color onAccent;

  /// Fond des messages d'information.
  final Color accentSoft;

  /// Fond de la tuile d'un téléphone dont l'écran est affiché, et texte posé dessus.
  final Color active;
  final Color onActive;

  final Color success;
  final Color danger;

  /// Fond des messages d'erreur.
  final Color dangerSoft;

  static const light = AppColors(
    background: Color(0xFFF5F0E8),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFE8DD),
    border: Color(0xFFE3D9CB),
    text: Color(0xFF2A1D14),
    textMuted: Color(0xFF6B5A4C),
    textFaint: Color(0xFF94826F),
    accent: Color(0xFFC2571A),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFF8E3D0),
    active: Color(0xFFF6B55F),
    onActive: Color(0xFF2A1D14),
    success: Color(0xFF2F7D4F),
    danger: Color(0xFFB93A2B),
    dangerSoft: Color(0xFFF9E1DC),
  );

  static const dark = AppColors(
    background: Color(0xFF16100C),
    surface: Color(0xFF231A14),
    surfaceMuted: Color(0xFF30251D),
    border: Color(0xFF3D3027),
    text: Color(0xFFF7EEE3),
    textMuted: Color(0xFFBCA996),
    textFaint: Color(0xFF8E7C6B),
    accent: Color(0xFFF0A257),
    onAccent: Color(0xFF2A1708),
    accentSoft: Color(0xFF45301F),
    active: Color(0xFFF0A257),
    onActive: Color(0xFF2A1708),
    success: Color(0xFF86C99A),
    danger: Color(0xFFF08C7D),
    dangerSoft: Color(0xFF45231D),
  );

  static AppColors of(Brightness brightness) => brightness == Brightness.dark ? dark : light;
}

/// Styles de texte (police Outfit embarquée), dimensionnés pour une fenêtre étroite
/// lue de près.
@immutable
class AppText {
  AppText._(AppColors c)
    : pageTitle = _style(24, FontWeight.w600, c.text, height: 1.15, spacing: -0.3),
      sectionTitle = _style(17, FontWeight.w600, c.text, height: 1.2),
      itemTitle = _style(16, FontWeight.w600, c.text, height: 1.25),
      body = _style(15, FontWeight.w400, c.text, height: 1.4),
      secondary = _style(14, FontWeight.w400, c.textMuted, height: 1.35),
      caption = _style(12.5, FontWeight.w500, c.textMuted, height: 1.25),
      button = _style(15, FontWeight.w600, c.text, height: 1.2),
      key = _style(12.5, FontWeight.w600, c.text, height: 1.1);

  /// Titre de page.
  final TextStyle pageTitle;

  /// Titre de section.
  final TextStyle sectionTitle;

  /// Nom d'un téléphone ou d'un réglage.
  final TextStyle itemTitle;
  final TextStyle body;

  /// Ligne d'état ou d'explication sous un titre.
  final TextStyle secondary;
  final TextStyle caption;
  final TextStyle button;

  /// Nom d'une touche du clavier.
  final TextStyle key;

  static final light = AppText._(AppColors.light);
  static final dark = AppText._(AppColors.dark);

  static AppText of(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  static TextStyle _style(double size, FontWeight weight, Color color, {required double height, double spacing = 0}) =>
      TextStyle(
        fontFamily: 'Outfit',
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color,
      );
}

/// Accès aux couleurs et aux styles de texte du thème courant.
extension AppThemeContext on BuildContext {
  AppColors get colors => AppColors.of(Theme.of(this).brightness);

  AppText get text => AppText.of(Theme.of(this).brightness);
}

/// Dimensions communes.
abstract final class Dim {
  static const tileRadius = 16.0;
  static const buttonRadius = 12.0;

  /// Marge autour du contenu d'une page.
  static const pagePadding = 16.0;

  /// Espace entre deux tuiles.
  static const gap = 10.0;

  /// Espace entre deux sections.
  static const sectionGap = 22.0;

  /// Largeur maximale du contenu quand la fenêtre est agrandie.
  static const contentWidth = 560.0;
}

ThemeData buildTheme(Brightness brightness) {
  final c = AppColors.of(brightness);
  final t = AppText.of(brightness);
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Dim.buttonRadius),
    borderSide: BorderSide(color: c.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Outfit',
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.surface,
      surface: c.surface,
      onSurface: c.text,
    ),
    scaffoldBackgroundColor: c.background,
    canvasColor: c.surface,
    dividerColor: c.border,
    splashColor: c.text.withValues(alpha: 0.07),
    highlightColor: c.text.withValues(alpha: 0.04),
    hoverColor: c.text.withValues(alpha: 0.04),
    textTheme: TextTheme(
      titleLarge: t.sectionTitle,
      titleMedium: t.itemTitle,
      bodyLarge: t.body,
      bodyMedium: t.body,
      bodySmall: t.caption,
      labelLarge: t.button,
    ),
    iconTheme: IconThemeData(color: c.textMuted, size: 22),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.3),
      selectionHandleColor: c.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceMuted.withValues(alpha: 0.5),
      labelStyle: t.secondary,
      floatingLabelStyle: t.secondary.copyWith(color: c.accent),
      hintStyle: t.body.copyWith(color: c.textFaint),
      helperStyle: t.caption,
      helperMaxLines: 2,
      errorMaxLines: 2,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.accent, width: 2)),
      errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger)),
      focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.danger, width: 2)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(8)),
      textStyle: t.caption.copyWith(color: c.background),
      waitDuration: const Duration(milliseconds: 500),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.textFaint.withValues(alpha: 0.5)),
      radius: const Radius.circular(8),
    ),
  );
}
