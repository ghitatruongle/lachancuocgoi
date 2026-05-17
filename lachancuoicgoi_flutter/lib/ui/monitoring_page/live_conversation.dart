import 'package:flutter/material.dart';

class LiveConversation extends StatefulWidget {
  const LiveConversation({
    super.key,
    required this.transcript,
    this.isSimulation = false,
  });

  final String transcript;
  final bool isSimulation;

  @override
  State<LiveConversation> createState() => _LiveConversationState();
}

class _LiveConversationState extends State<LiveConversation> {
  String _cachedTranscript = '';
  String _cleanTranscript = '';

  @override
  void initState() {
    super.initState();
    _cachedTranscript = widget.transcript;
    _cleanTranscript = _cachedTranscript.replaceAll('+', ' ');
  }

  @override
  void didUpdateWidget(LiveConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transcript != oldWidget.transcript) {
      _cachedTranscript = widget.transcript;
      _cleanTranscript = _cachedTranscript.replaceAll('+', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_cleanTranscript.isEmpty) {
      return Center(
        child: Text(
          widget.isSimulation ? 'Đang chờ kịch bản...' : 'Đang lắng nghe...',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    return Text(
      _cleanTranscript,
      style: const TextStyle(height: 1.4),
    );
  }
}
