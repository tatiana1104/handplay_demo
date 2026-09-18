import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

String matchStatusLabel(String? status) {
  return switch (status?.trim().toLowerCase()) {
    'live' || 'en vivo' || 'playing' || 'jugando' || 'en curso' || 'en_curso' => 'En curso',
    'postponed' || 'aplazado' || 'rescheduled' => 'Aplazado',
    'finished' || 'finalizado' || 'completed' => 'Finalizado',
    _ => 'Programado',
  };
}

Color matchStatusColor(BuildContext context, String? status) {
  final colors = Theme.of(context).colorScheme;
  return switch (matchStatusLabel(status)) {
    'En curso' => AppColors.brandDark,
    'Aplazado' => Theme.of(context).brightness == Brightness.dark ? AppColors.amberDark : AppColors.amberLight,
    'Finalizado' => colors.onSurfaceVariant,
    _ => Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
  };
}

class MatchStatusLabel extends StatelessWidget {
  const MatchStatusLabel({super.key, required this.status});

  final String? status;

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
