import 'package:flutter/material.dart';

class MatchStatusLabel extends StatelessWidget {
  const MatchStatusLabel({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final normalized = status?.toLowerCase();
    final label = normalized == 'playing' || normalized == 'jugando'
        ? 'Jugando'
        : normalized == 'finished' || normalized == 'finalizado'
            ? 'Finalizado'
            : 'Por iniciar';
    final color = label == 'Jugando'
        ? Colors.orange.shade700
        : label == 'Finalizado'
            ? Colors.blueGrey
            : Colors.green.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
