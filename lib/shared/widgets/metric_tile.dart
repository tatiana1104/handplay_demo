import 'package:flutter/material.dart';

/// Tarjeta compacta para un indicador numérico.
///
/// La etiqueta nunca se parte a mitad de palabra (una línea con elipsis)
/// y el valor se reduce con `FittedBox` si no cabe, para que funcione
/// en grillas de 3 o 4 columnas en pantallas angostas.
class MetricTile extends StatelessWidget {
  const MetricTile({required this.label, required this.value, this.accent, this.icon, super.key});

  final String label;
  final String value;
  final Color? accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (accent != null && icon == null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                ),
              if (icon != null) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(icon, size: 14, color: accent ?? colors.onSurfaceVariant)),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// Grilla responsive de [MetricTile]s: ajusta las columnas al ancho
/// disponible en lugar de forzar todas en una sola fila.
class MetricGrid extends StatelessWidget {
  const MetricGrid({required this.children, this.minTileWidth = 96, super.key});

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final columns = ((constraints.maxWidth + spacing) / (minTileWidth + spacing)).floor().clamp(2, 6);
          final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [for (final child in children) SizedBox(width: width, child: child)],
          );
        },
      );
}

/// Encabezado de ficha con avatar, título y líneas de detalle.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.title, required this.color, this.badge, this.subtitle, this.chips = const [], super.key});

  final String title;
  final Color color;
  final String? badge;
  final String? subtitle;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final initial = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: colors.outlineVariant, width: 2),
          ),
          child: Text(
            badge ?? initial,
            style: theme.textTheme.titleLarge?.copyWith(color: foreground, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chip in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: colors.primary.withValues(alpha: .15), borderRadius: BorderRadius.circular(999)),
                        child: Text(chip, style: theme.textTheme.labelMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.trailing, super.key});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) Text(trailing!, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Estado vacío amable dentro de una sección.
class EmptySection extends StatelessWidget {
  const EmptySection({required this.icon, required this.message, super.key});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
