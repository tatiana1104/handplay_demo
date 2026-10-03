import 'package:flutter/material.dart';

/// Encabezado de sección reutilizable con acción opcional.
class SectionTitleAction extends StatelessWidget {
  const SectionTitleAction({
    required this.title,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!),
            ),
        ],
      );
}
