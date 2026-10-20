import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class MonitoringStatusBadge extends StatelessWidget {
  const MonitoringStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class MonitoringSttFallbackBanner extends StatelessWidget {
  const MonitoringSttFallbackBanner({
    super.key,
    required this.reason,
    required this.onDismiss,
  });

  final String? reason;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return MonitoringStatusBanner(
      icon: Icons.mic_none,
      background: cs.tertiaryContainer,
      foreground: cs.onTertiaryContainer,
      message: reason != null && reason!.isNotEmpty
          ? l10n.monitoringSttFallbackWithReason(reason!)
          : l10n.monitoringSttFallbackOffline,
      onDismiss: onDismiss,
    );
  }
}

class MonitoringStatusBanner extends StatelessWidget {
  const MonitoringStatusBanner({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.message,
    required this.onDismiss,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        liveRegion: true,
        label: message,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 12, color: foreground),
                  ),
                ),
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
