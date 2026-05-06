import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../theme/app_theme.dart';
import 'history_item_card.dart';

// ─── Controller ────────────────────────────────────────────────────────
class _HistoryState {
  const _HistoryState({
    this.items = const [],
    this.searchQuery = '',
  });
  final List<CallHistory> items;
  final String searchQuery;

  List<CallHistory> get filtered {
    if (searchQuery.isEmpty) return items;
    final q = searchQuery.toLowerCase();
    return items.where((i) {
      return i.summary.toLowerCase().contains(q) ||
          i.riskLevel.toLowerCase().contains(q) ||
          i.dateTime.toLowerCase().contains(q) ||
          i.transcript.toLowerCase().contains(q) ||
          (i.analysisType?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final _historyProvider =
    AsyncNotifierProvider<_HistoryController, _HistoryState>(
        _HistoryController.new);

class _HistoryController extends AsyncNotifier<_HistoryState> {
  @override
  Future<_HistoryState> build() async {
    final db = ref.watch(appDatabaseProvider);
    final items = await db.getAll();
    return _HistoryState(items: items);
  }

  Future<void> refresh() async {
    final db = ref.read(appDatabaseProvider);
    final items = await db.getAll();
    state = AsyncData(
        _HistoryState(items: items, searchQuery: state.value?.searchQuery ?? ''));
  }

  void updateSearch(String query) {
    final current = state.value ?? const _HistoryState();
    state = AsyncData(_HistoryState(items: current.items, searchQuery: query));
  }

  Future<void> deleteItem(int id) async {
    await ref.read(appDatabaseProvider).deleteById(id);
    await refresh();
  }

  Future<void> deleteAll() async {
    await ref.read(appDatabaseProvider).deleteAll();
    await refresh();
  }
}

// ─── Page ──────────────────────────────────────────────────────────────
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final asyncState = ref.watch(_historyProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Lịch sử giám sát'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Cài đặt',
            onPressed: () {},
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (historyState) {
          final items = historyState.filtered;
          final query = historyState.searchQuery;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Column(
              children: [
                // ── Search bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo nội dung, mức độ, ngày tháng...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(_historyProvider.notifier)
                                    .updateSearch('');
                                _focusNode.unfocus();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: cs.primary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (v) =>
                        ref.read(_historyProvider.notifier).updateSearch(v),
                    onSubmitted: (_) => _focusNode.unfocus(),
                  ),
                ),

                // ── Header row ──
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lịch sử cuộc gọi', style: tt.titleMedium),
                      if (items.isNotEmpty)
                        TextButton(
                          onPressed: () => _showDeleteAllDialog(context),
                          child: const Text('Xóa tất cả',
                              style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── List / Empty ──
                Expanded(
                  child: items.isEmpty
                      ? _EmptyState(
                          message: query.isEmpty
                              ? 'Lịch sử trống.'
                              : 'Không tìm thấy kết quả.',
                          secondary: query.isEmpty
                              ? 'Dữ liệu cuộc gọi chỉ được lưu trên thiết bị này để bạn xem lại trực tiếp.'
                              : 'Không tìm thấy kết quả nào khớp với "$query".',
                        )
                      : ListView.separated(
                          itemCount: items.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == items.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  '*Lưu ý: Để đảm bảo quyền riêng tư và tối ưu bộ nhớ, file ghi âm sẽ không được lưu trong lịch sử; chỉ lưu văn bản cuộc gọi trên thiết bị này.',
                                  style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            final item = items[index];
                            return Dismissible(
                              key: ValueKey(item.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) =>
                                  _showDeleteItemDialog(context, item),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(Icons.delete,
                                    color: cs.onErrorContainer),
                              ),
                              child: HistoryItemCard(
                                item: item,
                                onTap: () =>
                                    context.push('/result/${item.id}'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn muốn xóa tất cả dữ liệu cuộc gọi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () {
              ref.read(_historyProvider.notifier).deleteAll();
              Navigator.pop(context);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteItemDialog(
      BuildContext context, CallHistory item) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text('Xác nhận xóa lịch sử cuộc gọi này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Quay lại'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(_historyProvider.notifier).deleteItem(item.id);
                  Navigator.pop(context, true);
                },
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.secondary});
  final String message;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: tt.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              secondary,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
