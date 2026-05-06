import 'package:flutter/material.dart';

/// Live conversation transcript display with keyword highlighting.
class LiveConversation extends StatelessWidget {
  const LiveConversation({
    super.key,
    required this.transcript,
    this.isSimulation = false,
  });

  final String transcript;
  final bool isSimulation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cleanTranscript = transcript.replaceAll('+', ' ');

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: cleanTranscript.isEmpty
          ? Center(
              child: Text(
                isSimulation
                    ? 'Đang chờ kịch bản...'
                    : 'Đang lắng nghe...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            )
          : ListView(
              reverse: true,
              children: [
                Text(cleanTranscript),
              ],
            ),
    );
  }
}
