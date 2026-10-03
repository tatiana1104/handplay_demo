import 'package:flutter/material.dart';

/// Tarjeta reutilizable para resumenes, métricas o destacados.
class CompactActionCard extends StatelessWidget {
  const CompactActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onPressed,
    this.valueStyle,
    this.iconColor,
    this.iconBackgroundColor,
    this.showChevron = true,
    this.trailing,
    this.valueMaxLines = 2,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback? onPressed;
  final TextStyle? valueStyle;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final bool showChevron;
  final Widget? trailing;
  final int valueMaxLines;
  final int titleMaxLines;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final resolvedIconColor = iconColor ?? colors.primary;
    final resolvedIconBackground = iconBackgroundColor ?? colors.primary.withValues(alpha: .15);
    final hasData = value != 'Sin datos';
    final effectiveStyle = (valueStyle ?? theme.textTheme.bodyMedium)?.copyWith(
      fontWeight: FontWeight.w700,
      color: hasData ? colors.onSurface : colors.onSurfaceVariant,
      fontSize: 12,
    );

    final trailingWidget = trailing ??
        (showChevron
            ? Icon(
                Icons.chevron_right,
                size: 18,
                color: colors.onSurfaceVariant,
                semanticLabel: 'Ver detalle',
              )
            : null);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: resolvedIconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: resolvedIconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: valueMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: effectiveStyle,
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 6),
                trailingWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
