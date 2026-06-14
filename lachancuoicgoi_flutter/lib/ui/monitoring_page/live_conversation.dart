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
  List<String> _lines = [];
  // The transcript prefix that has already been folded into _lines. When the
  // new transcript starts with this prefix we only need to split the suffix —
  // O(new text) instead of re-splitting the whole cumulative transcript on
  // every update (which was O(n²) over the lifetime of a long call).
  String _processedTranscript = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _processTranscript(widget.transcript);
  }

  @override
  void didUpdateWidget(LiveConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transcript != oldWidget.transcript) {
      _processTranscript(widget.transcript);

      // Auto scroll to bottom when new content is appended
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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

  void _processTranscript(String newTranscript) {
    // Fast path: if the new transcript extends the previously processed one
    // (the common case — transcript only grows), fold in just the new suffix.
    // This avoids re-splitting + re-regex-ing the whole transcript on every
    // incremental update (was O(n²) for long calls).
    if (_processedTranscript.isNotEmpty &&
        newTranscript.startsWith(_processedTranscript)) {
      final suffix = newTranscript.substring(_processedTranscript.length);
      final newChunks = _splitIntoChunks(suffix);
      if (newChunks.isNotEmpty) {
        setState(() {
          _lines.addAll(newChunks);
          _processedTranscript = newTranscript;
        });
      }
      return;
    }

    // Slow path: transcript changed in a non-append way (e.g. partial result
    // replaced). Reprocess from scratch.
    final allLines = _splitIntoChunks(newTranscript);
    setState(() {
      _lines = allLines;
      _processedTranscript = newTranscript;
    });
  }

  /// Splits an arbitrary chunk of transcript text into display lines:
  /// newline-separated, with very long lines additionally broken on
  /// sentence-ending punctuation. Empty lines are dropped.
  static List<String> _splitIntoChunks(String text) {
    final rawLines = text.split('\n');
    return rawLines
        .expand((line) {
          if (line.length > 200) {
            return line
                .replaceAll('+', ' ')
                .replaceAllMapped(
                  RegExp(r'([.!?]+)\s+'),
                  (m) => '${m[1]}\n',
                )
                .split('\n');
          }
          return [line.replaceAll('+', ' ')];
        })
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_lines.isEmpty) {
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
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        itemCount: _lines.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Text(
            _lines[index],
            style: const TextStyle(height: 1.4),
          );
        },
      ),
    );
  }
}

