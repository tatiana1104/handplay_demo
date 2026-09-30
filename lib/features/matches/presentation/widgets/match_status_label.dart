import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// ES: Traduce los estados del partido a etiquetas visibles en español.
/// EN: Maps stored match statuses to user-facing Spanish labels.
String matchStatusLabel(String? status) {
  return switch (status?.trim().toLowerCase()) {
    'live' || 'en vivo' || 'playing' || 'jugando' || 'en curso' || 'en_curso' => 'En curso',
    'tiempo_muerto' || 'tiempo muerto' || 'timeout' => 'Tiempo muerto',
    'postponed' || 'aplazado' || 'rescheduled' => 'Aplazado',
    'finished' || 'finalizado' || 'completed' => 'Finalizado',
    _ => 'Programado',
  };
}

/// ES: Devuelve el color semántico correspondiente al estado del partido.
/// EN: Returns the semantic color associated with a match status.
Color matchStatusColor(BuildContext context, String? status) {
  final colors = Theme.of(context).colorScheme;
  return switch (matchStatusLabel(status)) {
    'En curso' => Theme.of(context).brightness == Brightness.dark ? AppColors.brandDark : AppColors.brandLight,
    'Tiempo muerto' => colors.tertiary,
    'Aplazado' => colors.error,
    'Finalizado' => colors.onSurfaceVariant,
    _ => Theme.of(context).brightness == Brightness.dark ? AppColors.amberDark : AppColors.amberLight,
  };
}

/// ES: Insignia que muestra el estado normalizado de un partido.
/// EN: Badge that displays a normalized match status.
class MatchStatusLabel extends StatelessWidget {
  /// ES: Crea la insignia para el estado recibido.
  /// EN: Creates the badge for the supplied status.
  const MatchStatusLabel({super.key, required this.status});

  final String? status;

  /// ES: Construye la etiqueta con el texto y color del estado.
  /// EN: Builds the label with the status text and color.
  @override
  Widget build(BuildContext context) {
    final label = matchStatusLabel(status);
    final color = matchStatusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
