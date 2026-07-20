# ADR-001: Riverpod State Management

## Status

Accepted

## Context

La Chan Cuoc Goi is a complex Flutter application requiring:
- Reactive state management across multiple pages (Home, Monitoring, History, Settings)
- Dependency injection for testability
- Consistent patterns for async operations (database, native bridge, AI analysis)
- Lifecycle management for services and streams

Early iterations considered:
- **Provider (legacy):** Limited reactive capabilities
- **BLoC:** Verbose boilerplate, event/state coupling
- **ChangeNotifier:** Manual listener management, no DI
- **GetX:** Heavy framework coupling, less testable

## Decision

Use **flutter_riverpod 3.0** for all state management and dependency injection.

### Architecture Patterns

1. **Providers** for dependency injection:
   ```dart
   final settingsControllerProvider =
       NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
   ```

2. **Notifiers** for mutable state with lifecycle hooks:
   ```dart
   class MonitoringController extends Notifier<MonitoringPageState> {
     @override
     MonitoringPageState build() { /* init */ }
     void updateState(MonitoringPageState newState) => state = newState;
   }
   ```

3. **FutureProviders** for async one-time operations:
   ```dart
   final appDatabaseFutureProvider = FutureProvider<AppDatabase>((ref) async {
     return AppDatabase.open();
   });
   ```

4. **Selector** for optimized rebuilds:
   ```dart
   ref.watch(permissionControllerProvider.select((s) => s.allGranted));
   ```

### Why Riverpod Over Alternatives

| Criterion | Riverpod | BLoC | ChangeNotifier | GetX |
|-----------|----------|------|----------------|------|
| Testability | ✅ Provider overrides | ✅ Mock events | ⚠️ Manual | ❌ Framework coupling |
| Type safety | ✅ Full | ✅ Full | ⚠️ Partial | ⚠️ Runtime |
| Async support | ✅ Native | ⚠️ Stream-based | ❌ Manual | ⚠️ Futures |
| DI integration | ✅ Built-in | ❌ Separate | ❌ Separate | ⚠️ Coupled |
| Learning curve | Medium | High | Low | Low |
| Community adoption | Growing | Established | Standard | Declining |

### Consequences

**Positive:**
- Consistent patterns across entire codebase
- Easy to test with `ProviderContainer.override()`
- Reactive updates automatic via `ConsumerWidget`/`ConsumerStatefulWidget`
- No manual stream subscription management
- Strong typing prevents runtime errors

**Negative:**
- Learning curve for developers unfamiliar with provider tree
- Debugging provider dependencies can be complex
- Requires understanding of `ref.onDispose()` for cleanup
- Riverpod 3.0 is relatively new (breaking changes possible)

**Mitigations:**
- Comprehensive tests demonstrate provider usage patterns
- CONTRIBUTING.md documents setup and testing workflows
- ADRs document architectural decisions for future reference

## References

- [flutter_riverpod documentation](https://riverpod.dev/)
- `lib/app/lachancuocgoi_app.dart` — Composition root
- `lib/services/permission_controller.dart` — Notifier pattern example
- `lib/data/app_database.dart` — FutureProvider pattern example
