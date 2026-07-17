import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/system_logger.dart';

class SystemLogView extends StatefulWidget {
  const SystemLogView({super.key});

  @override
  State<SystemLogView> createState() => _SystemLogViewState();
}

class _SystemLogViewState extends State<SystemLogView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<LogEntry>? _logSubscription;
  LogCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _logSubscription = SystemLogger.instance.logStream.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom();
      });
    });

    // Auto-scroll on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  IconData _getCategoryIcon(LogCategory category) {
    return switch (category) {
      LogCategory.system => Icons.dns_outlined,
      LogCategory.recording => Icons.mic_none_outlined,
      LogCategory.stt => Icons.translate_outlined,
      LogCategory.analysis => Icons.psychology_outlined,
      LogCategory.model => Icons.memory_outlined,
      LogCategory.bridge => Icons.swap_horiz_outlined,
      LogCategory.permission => Icons.shield_outlined,
    };
  }

  Color _getCategoryColor(LogCategory category, ColorScheme cs) {
    return switch (category) {
      LogCategory.system => cs.primary,
      LogCategory.recording => cs.secondary,
      LogCategory.stt => Colors.teal,
      LogCategory.analysis => cs.error,
      LogCategory.model => Colors.purple,
      LogCategory.bridge => Colors.indigo,
      LogCategory.permission => Colors.amber,
    };
  }

  Color _getLevelTextColor(LogLevel level, ColorScheme cs) {
    return switch (level) {
      LogLevel.debug => cs.onSurfaceVariant,
      LogLevel.error => cs.error,
      LogLevel.warning => Colors.orange,
      LogLevel.info => cs.onSurface,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // Filter Toolbar (Does not rebuild on new log entries to prevent focus issues)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm log...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Category chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = null);
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    ...LogCategory.values.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(category.vietnameseName),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : null;
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Log entries list (Rebuilds reactively when a new log entry arrives)
        Expanded(
          child: ListenableBuilder(
            listenable: SystemLogger.instance,
            builder: (context, child) {
              var filteredLogs = SystemLogger.instance.logs;

              if (_selectedCategory != null) {
                filteredLogs = filteredLogs.where((log) => log.category == _selectedCategory).toList();
              }
              if (_searchQuery.isNotEmpty) {
                filteredLogs = filteredLogs.where((log) => log.message.toLowerCase().contains(_searchQuery)).toList();
              }

              return filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        'Không có nhật ký nào trùng khớp.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          final categoryColor = _getCategoryColor(log.category, cs);
                          final levelTextColor = _getLevelTextColor(log.level, cs);

                          return InkWell(
                            onLongPress: () {
                              Clipboard.setData(ClipboardData(text: '[${log.formattedTime}] [${log.category.name.toUpperCase()}] ${log.message}'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép nhật ký vào Clipboard'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timestamp
                                  Text(
                                    log.formattedTime,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Category badge/icon
                                  Icon(
                                    _getCategoryIcon(log.category),
                                    size: 14,
                                    color: categoryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  // Message
                                  Expanded(
                                    child: Text(
                                      log.message,
                                      style: tt.bodyMedium?.copyWith(
                                        color: levelTextColor,
                                        fontWeight: log.level != LogLevel.info ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
            },
          ),
        ),
      ],
    );
  }
}
