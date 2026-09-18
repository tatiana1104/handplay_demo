import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

// Flutter arma la apariencia de toda la app a partir de un solo objeto
// `ThemeData`. En vez de poner colores y fuentes "sueltos" en cada
// pantalla, este archivo define UNA vez el tema claro y UNA vez el
// oscuro; luego cada widget solo pide `Theme.of(context)` y hereda
// esos valores automáticamente (por ejemplo, todos los botones
// `ElevatedButton` salen verdes sin tener que decirlo en cada uno).

/// Define los `ThemeData` claro y oscuro de Cancha.
///
/// Tipografías de marca (mockup HTML): Manrope para títulos, Inter
/// para texto de cuerpo. Se usan vía el paquete `google_fonts`, que
/// descarga/empaqueta la fuente automáticamente (no hace falta agregar
/// archivos .ttf a mano en `pubspec.yaml`).
class AppTheme {
  AppTheme._();

  /// Tema para cuando el celular está en modo claro.
  static ThemeData get light => _base(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        secondaryText: AppColors.lightTextSecondary,
        border: AppColors.lightBorder,
        brand: AppColors.brandLight,
      );

  /// Tema para cuando el celular está en modo oscuro.
  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        secondaryText: AppColors.darkTextSecondary,
        border: AppColors.darkBorder,
        brand: AppColors.brandDark,
      );

  /// Construye el `ThemeData` real a partir de los colores que le pasan
  /// `light` u `dark`. Se centraliza acá para no duplicar toda esta
  /// configuración dos veces (una por tema).
  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color secondaryText,
    required Color border,
    required Color brand,
  }) {
    // Texto de cuerpo en Inter, pero los títulos (titleLarge/Medium/
    // Small — usados por AppBar, Card, etc.) se sobrescriben a Manrope
    // para que se vea igual que en el mockup HTML.
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w500),
      titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.manrope(fontWeight: FontWeight.w500),
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,

      // `ColorScheme.fromSeed` genera automáticamente una paleta
      // completa (primary, secondary, error, etc.) a partir de un solo
      // color "semilla" (nuestro verde de marca). Después sobrescribimos
      // `primary` y `surface` para que coincidan exactamente con el
      // mockup en vez de dejar que Flutter los calcule solo.
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand,
        brightness: brightness,
        primary: brand,
        surface: surface,
      ),

      // `.apply(bodyColor: ..., displayColor: ...)` fuerza que TODO el
      // texto use `onSurface` como color por defecto, sin tener que
      // poner `style: TextStyle(color: ...)` en cada Text() de la app.
      textTheme: textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),

      // Barra superior (AppBar): sin sombra (elevation: 0) y mismo
      // color que el fondo, para que se vea "integrada" como en los
      // mockups (no como una barra separada).
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
      ),

      // Tarjetas (Card): esquinas redondeadas de 12px, sin sombra, con
      // el color "surface" de fondo — igual que las `.card` del mockup.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
      ),

      // Campos de formulario (TextField/TextFormField): fondo relleno
      // con el color "surface" y borde sutil, para que todos los
      // inputs de la app (login, inscripción de equipo, etc.) se vean
      // consistentes sin repetir esta configuración en cada pantalla.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelStyle: TextStyle(color: secondaryText),
        hintStyle: TextStyle(color: secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
      ),

      // Botones principales y secundarios comparten radios y jerarquía visual.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: brand.withValues(alpha: 0.65)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: brand.withValues(alpha: .45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      // Botones principales (ElevatedButton): fondo verde de marca.
      // El color del TEXTO cambia según el tema porque verde oscuro
      // (`brandDark`, tema oscuro) necesita texto oscuro encima para
      // tener buen contraste, mientras que el verde más fuerte del
      // tema claro (`brandLight`) se ve bien con texto blanco.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: brightness == Brightness.dark
              ? const Color(0xFF0F1210)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brightness == Brightness.dark ? AppColors.darkBrandSoft : AppColors.lightBrandSoft,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(color: onSurface, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      useMaterial3: true,
    );
  }
}
