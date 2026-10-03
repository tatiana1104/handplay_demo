import 'package:flutter/material.dart';

class UniformColors {
  static const Map<String, Color> named = {
    'verde': Color(0xFF4CAF50),
    'azul': Color(0xFF2196F3),
    'rojo': Color(0xFFF44336),
    'naranja': Color(0xFFFF9800),
    'amarillo': Color(0xFFFFC107),
    'blanco': Color(0xFFFFFFFF),
    'negro': Color(0xFF111111),
    'morado': Color(0xFF9C27B0),
    'gris': Color(0xFF9E9E9E),
    'celeste': Color(0xFF03A9F4),
    'turquesa': Color(0xFF009688),
  };

  static const Color defaultColor = Color(0xFF9E9E9E);

  static Color resolve(dynamic value, {Color fallback = defaultColor}) {
    if (value == null) return fallback;
    if (value is int) return Color(value);
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback;

      final normalized = trimmed.replaceFirst('#', '');
      if (normalized.length == 6 || normalized.length == 8) {
        final hex = int.tryParse(normalized, radix: 16);
        if (hex != null) {
          return Color(normalized.length == 6 ? 0xFF000000 | hex : hex);
        }
      }

      final key = trimmed.toLowerCase();
      return named[key] ?? fallback;
    }
    return fallback;
  }

  static Color contrast(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
