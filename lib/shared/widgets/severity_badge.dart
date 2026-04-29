import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SeverityBadge extends StatelessWidget {
  final String severity;
  final bool large;
  const SeverityBadge({super.key, required this.severity, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(severity);
    final icon = severity == 'red'
        ? Icons.emergency_rounded
        : severity == 'yellow'
            ? Icons.warning_rounded
            : Icons.check_circle_rounded;

    if (large) {
      return Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 8),
          Text(
            severity.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
        ],
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
