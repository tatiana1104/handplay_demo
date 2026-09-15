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
  static const Color lightSurface = Color(0xFFE4E6DE); // fondo de tarjetas
  static const Color lightBorder = Color(0xFFD3D5CC); // bordes sutiles
  static const Color lightText = Color(0xFF0B0B0B); // texto principal
  static const Color lightTextSecondary = Color(0xFF5C5F57); // texto secundario
  static const Color lightTextMuted = Color(0xFF8B8F86); // texto apagado (hints)
  static const Color lightBackground = Color(0xFFFFFFFF);

  // "Brand soft" = el verde de marca pero muy transparente (12%), usado
  // como fondo detrás de chips/badges activos, para resaltar sin ser
  // un bloque de color sólido encima del contenido.
  static const Color lightBrandSoft = Color(0x1F0D8932);

  // --- Tema oscuro ---
  static const Color darkSurface = Color(0xFF1C1F1C);
  static const Color darkBorder = Color(0xFF2A2D28);
  static const Color darkText = Color(0xFFEDEFEA);
  static const Color darkTextSecondary = Color(0xFF8B8F86);
  static const Color darkBackground = Color(0xFF161815);
  static const Color darkBrandSoft = Color(0x2E4AA765); // 18% opacidad

  // --- Estados / semántica (iguales en ambos temas, salvo el ámbar) ---
  static const Color amberLight = Color(0xFFB07D00); // advertencias (tema claro)
  static const Color amberDark = Color(0xFFE0AA33); // advertencias (tema oscuro)
  static const Color error = Color(0xFFD32F2F); // bloqueos duros (ej. RN-02)
  static const Color gold = Color(0xFFE0AA33); // estrella de "favorito" (RF-04)
}
