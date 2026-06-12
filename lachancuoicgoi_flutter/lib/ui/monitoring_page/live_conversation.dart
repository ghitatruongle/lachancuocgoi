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
  final ScrollController _scrollController = ScrollController();

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

      // Auto scroll to bottom when new content is appended
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          _cleanTranscript,
          style: const TextStyle(height: 1.4),
        ),
      ),
    );
  }
}

