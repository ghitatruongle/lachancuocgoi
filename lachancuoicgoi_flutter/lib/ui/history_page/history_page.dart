import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';
import '../../data/call_history.dart';
import '../home_page/settings_dialog.dart';
import '../theme/app_theme.dart';
import 'history_item_card.dart';

// ─── Controller ────────────────────────────────────────────────────────
class _HistoryState {
  const _HistoryState({
    this.items = const [],
    this.searchQuery = '',
    this.hasMore = false,
    this.isLoadingMore = false,
  });
  final List<CallHistory> items;
  final String searchQuery;
  final bool hasMore;
  final bool isLoadingMore;

  _HistoryState copyWith({
    List<CallHistory>? items,
    String? searchQuery,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return _HistoryState(
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final _historyProvider =
    AsyncNotifierProvider<_HistoryController, _HistoryState>(
        _HistoryController.new);

class _HistoryController extends AsyncNotifier<_HistoryState> {
  /// Kích thước trang — chỉ load 20 bản ghi mỗi lần thay vì toàn bộ bảng
  /// (mỗi bản ghi chứa full transcript nên rất tốn RAM).
  static const int _pageSize = 20;

  StreamSubscription<void>? _dbSubscription;

  @override
  Future<_HistoryState> build() async {
    final db = await ref.watch(appDatabaseFutureProvider.future);
    _subscribeToDb(db);
    ref.onDispose(() {
      _dbSubscription?.cancel();
    });
    final initial = await db.getAllPaginated(limit: _pageSize, offset: 0);
    return _HistoryState(
      items: initial,
      searchQuery: '',
      hasMore: initial.length == _pageSize,
    );
  }

  void _subscribeToDb(AppDatabase db) {
    _dbSubscription?.cancel();
    _dbSubscription = db.changes.listen((_) async {
      if (_dbSubscription == null) return; // Guard against events after cancel
      final s = state.value;
      if (s == null || s.searchQuery.isNotEmpty) return;
      // Re-query đúng số item đang hiển thị để giữ vị trí cuộn,
      // thay vì load toàn bộ bảng vào RAM.
      final limit = s.items.length > _pageSize ? s.items.length : _pageSize;
      final items = await db.getAllPaginated(limit: limit, offset: 0);
      final current = state.value;
      if (current == null || current.searchQuery.isNotEmpty) return;
      state = AsyncData(current.copyWith(
        items: items,
        hasMore: items.length == limit,
      ));
    });
  }

  Future<void> refresh() async {
    final current = state.value;
    await _loadFirstPage(current?.searchQuery ?? '');
  }

  Future<void> updateSearch(String query) => _loadFirstPage(query);

  Future<void> _loadFirstPage(String query) async {
    final db = await ref.read(appDatabaseFutureProvider.future);
    if (query.isEmpty) {
      _subscribeToDb(db);
      final items = await db.getAllPaginated(limit: _pageSize, offset: 0);
      state = AsyncData(_HistoryState(
        items: items,
        searchQuery: '',
        hasMore: items.length == _pageSize,
      ));
      return;
    }
    _dbSubscription?.cancel();
    _dbSubscription = null;
    final results = await db.search(query, limit: _pageSize);
    state = AsyncData(_HistoryState(
      items: results,
      searchQuery: query,
      hasMore: results.length == _pageSize,
    ));
  }

  /// Lazy load trang kế tiếp khi người dùng cuộn gần cuối danh sách.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || s.isLoadingMore || !s.hasMore) return;
    state = AsyncData(s.copyWith(isLoadingMore: true));
    try {
      final db = await ref.read(appDatabaseFutureProvider.future);
      final next = s.searchQuery.isEmpty
          ? await db.getAllPaginated(
              limit: _pageSize, offset: s.items.length)
          : await db.search(s.searchQuery,
              limit: _pageSize, offset: s.items.length);
      state = AsyncData(s.copyWith(
        items: [...s.items, ...next],
        hasMore: next.length == _pageSize,
        isLoadingMore: false,
      ));
    } catch (_) {
      final cur = state.value;
      if (cur != null) {
        state = AsyncData(cur.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> deleteItem(int id) async {
    final db = await ref.read(appDatabaseFutureProvider.future);
    await db.deleteById(id);
    await refresh();
  }

  Future<void> deleteAll() async {
    final db = await ref.read(appDatabaseFutureProvider.future);
    await db.deleteAll();
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
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Debounce 300ms — tránh query DB theo từng ký tự gõ.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(_historyProvider.notifier).updateSearch(value);
    });
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
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (historyState) {
          final items = historyState.items;
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
                                _searchDebounce?.cancel();
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
                    onChanged: _onSearchChanged,
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

                // ── List / Empty (with pull-to-refresh) ──
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.read(_historyProvider.notifier).refresh(),
                    child: items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 240,
                                child: _EmptyState(
                                  message: query.isEmpty
                                      ? 'Lịch sử trống.'
                                      : 'Không tìm thấy kết quả.',
                                  secondary: query.isEmpty
                                      ? 'Dữ liệu cuộc gọi chỉ được lưu trên thiết bị này để bạn xem lại trực tiếp.'
                                      : 'Không tìm thấy kết quả nào khớp với "$query".',
                                ),
                              ),
                            ],
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              // Lazy load: cuộn gần cuối thì tải trang kế.
                              if (n.metrics.pixels >=
                                  n.metrics.maxScrollExtent - 200) {
                                ref
                                    .read(_historyProvider.notifier)
                                    .loadMore();
                              }
                              return false;
                            },
                            child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: items.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (index == items.length) {
                                return Column(
                                  children: [
                                    if (historyState.isLoadingMore)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      child: Text(
                                        '*Lưu ý: Để đảm bảo quyền riêng tư và tối ưu bộ nhớ, file ghi âm sẽ không được lưu trong lịch sử; chỉ lưu văn bản cuộc gọi trên thiết bị này.',
                                        style: tt.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
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
