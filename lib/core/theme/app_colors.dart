import 'package:flutter/material.dart';

// Estos colores se copiaron directamente de las variables CSS del
// mockup HTML consolidado (cancha-todas-las-vistas.html), donde cada
// tema (`.phone.light` / `.phone.dark`) define su propia paleta con
// `--brand`, `--surface`, `--border`, etc. Aquí las traducimos a
// `Color` de Flutter, en formato 0xAARRGGBB (AA = opacidad).

/// Paleta de colores de marca de Cancha, para tema claro y oscuro.
///
/// Se usan en `AppTheme` para armar el `ThemeData` de Flutter; el resto
/// del código no debería usar colores "sueltos" (ej. `Color(0xFF...)`
/// escrito directamente en un widget), sino siempre referirse a estas
/// constantes o al `Theme.of(context)`.
class AppColors {
  AppColors._();

  // Verde institucional de la Liga. El tono cambia levemente entre
  // temas porque el verde puro (#0D8932) se ve "apagado" sobre fondo
  // oscuro; #4AA765 es una versión más clara pensada para contrastar.
  static const Color brandLight = Color(0xFF0D8932);
  static const Color brandDark = Color(0xFF4AA765);

  // --- Tema claro ---
  static const Color lightSurface = Color(0xFFE4E6DE); // tarjetas suaves del mockup
  static const Color lightBorder = Color(0xFFD2D5CB); // bordes sutiles
  static const Color lightText = Color(0xFF101310); // texto principal
  static const Color lightTextSecondary = Color(0xFF5B6259); // texto secundario
  static const Color lightTextMuted = Color(0xFF858C82); // texto apagado (hints)
  static const Color lightBackground = Color(0xFFF7F8F4);

  // "Brand soft" = el verde de marca pero muy transparente (12%), usado
  // como fondo detrás de chips/badges activos, para resaltar sin ser
  // un bloque de color sólido encima del contenido.
  static const Color lightBrandSoft = Color(0x1F0D8932);

  // --- Tema oscuro ---
  static const Color darkSurface = Color(0xFF1C201C);
  static const Color darkBorder = Color(0xFF2B302B);
  static const Color darkText = Color(0xFFE8ECE6);
  static const Color darkTextSecondary = Color(0xFF9AA39A);
  static const Color darkBackground = Color(0xFF151815);
  static const Color darkBrandSoft = Color(0x2E4AA765); // 18% opacidad

  // --- Estados / semántica (iguales en ambos temas, salvo el ámbar) ---
  static const Color amberLight = Color(0xFF9A7000); // advertencias (tema claro)
  static const Color amberDark = Color(0xFFD9A62E); // advertencias (tema oscuro)
  static const Color error = Color(0xFFD32F2F); // bloqueos duros (ej. RN-02)
}
